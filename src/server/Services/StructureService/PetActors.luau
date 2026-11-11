--!strict
-- Authoritative native melee pets, body movement and Bonk Dog jumps; StructureService owns deployments and snapshots.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local C = require(Shared.Config.Pets)
local World = require(script.Parent.Parent.EnemySim.World)
local Enemy = require(script.Parent.Parent.EnemySim)
local Map = require(script.Parent.Parent.MapService)
local Run = require(script.Parent.Parent.RunDirector)
local Random = require(script.Parent.Parent.RandomService)
local Weapons = require(script.Parent.Parent.WeaponService)
local Combat = require(script.Parent.Parent.CombatService)
local Rules = require(script.Parent.PetRules)
local Bot = require(script.Parent.PetBot)
local Actors = {}
local bodies: any = nil
local members: { any } = {}
local claimed: { [string]: { [number]: number } } = {}
local stepRemainder = 0
local scale = Config.Stats.range.studsPerPoint

local function createWorld()
	local bounds, sim = Map.getArenaBounds(), Config.Simulation
	return World.new({
		cellSize = sim.spatialHashCellSize,
		maxEnemies = Config.Structures.maxActive,
		playerRadius = 0,
		contactMargin = 0,
		separationStiffness = sim.separationStiffness,
		separationPasses = sim.separationPasses,
		obstacleSteerMargin = sim.obstacleSteerMargin,
		keepDistanceTolerance = 0,
		minX = bounds.center.X - bounds.halfX,
		maxX = bounds.center.X + bounds.halfX,
		minZ = bounds.center.Z - bounds.halfZ,
		maxZ = bounds.center.Z + bounds.halfZ,
		obstacles = Map.getObstacles(),
		goalsWithoutTargets = true,
		collideTargets = false,
		seed = Random.getSeed(),
	})
end

local function release(o: any)
	local family = if o.pet.targetFamily then claimed[o.pet.targetFamily] else nil
	if o.target and family and family[o.target] == o.id then
		family[o.target] = nil
	end
	o.target = nil
end

function Actors.clear()
	bodies = nil
	table.clear(members)
	table.clear(claimed)
	stepRemainder = 0
end

function Actors.remove(o: any)
	if not o.bodyId then
		return
	end
	release(o)
	bodies:remove(o.bodyId)
	for index, member in members do
		if member == o then
			table.remove(members, index)
			break
		end
	end
	o.bodyId = nil
end

local function beastMaster(player: Player): boolean
	local class = Config.Classes[Run.getParticipantClassId(player)]
	for _, rule in (class and class.native and class.native.remainingRules) or {} do
		if rule.sourceKey == "beast_master_effect" and rule.amount > 0 then
			return true
		end
	end
	return false
end

function Actors.add(o: any)
	local def = Config.Structures.kinds[o.kind]
	if not def.petKind then
		return
	end
	local pet = C.kinds[def.petKind]
	bodies = bodies or createWorld()
	o.pet = pet
	o.beastMaster = beastMaster(o.owner)
	o.bodyOffset = Vector3.new(pet.bodyOffsetXPoints * scale, 0, pet.bodyOffsetZPoints * scale)
	local center = o.position + o.bodyOffset
	o.bodyId = bodies:spawn({
		id = o.kind,
		typeId = 0,
		speed = Rules.speed(pet, {}),
		radius = pet.bodyRadiusPoints * scale,
		hp = 1,
		contactDamage = 0,
		mass = 1,
	}, center.X, center.Z, 1, 0)
	assert(o.bodyId, "Pet body budget must match StructureService's deployment budget")
	o.cooldownFrames = Rules.compute(pet.weapon, Weapons.getStructureStats(o.owner), o.beastMaster).cooldown
		* C.frameRate
	o.mineFrames = pet.mineIntervalFrames
	o.attacking = false
	if pet.explosion then
		o.jumpCooldownFrames = pet.explosion.cooldownFrames
			* (pet.jumpInitialMinimumShare + (1 - pet.jumpInitialMinimumShare) * Random.number("Combat", o.owner))
	end
	if pet.targetFamily then
		claimed[pet.targetFamily] = claimed[pet.targetFamily] or {}
	end
	table.insert(members, o)
end

local function chooseTarget(o: any)
	local family, pet = claimed[o.pet.targetFamily], o.pet
	local ids = {}
	Enemy.collectIds(ids)
	local function eligible(id)
		local kind, boss = Enemy.getKind(id)
		return kind ~= "Tree" and (if boss then not pet.excludeBosses else family[id] == nil)
	end
	local best, distance = nil, math.huge
	local nearby = {}
	Enemy.queryRadius(o.position, pet.targetRadiusPoints * scale, nearby)
	for _, id in nearby do
		local at = Enemy.getPosition(id)
		local d = (at - o.position).Magnitude
		if eligible(id) and d < distance then
			best, distance = id, d
		end
	end
	if not best then
		-- Original ClosestEnemyTargetBehavior falls back to the first eligible global enemy.
		for _, id in ids do
			if eligible(id) then
				best = id
				break
			end
		end
	end
	o.target = best
	if best then
		family[best] = o.id
	end
end

local function attack(o: any, sheet: { [string]: number }, exploding: boolean?)
	local pet = o.pet
	local weapon = if exploding then pet.explosion else pet.weapon
	local stats = Rules.compute(weapon, sheet, o.beastMaster)
	local elemental = Rules.scaling(weapon.scaling, o.beastMaster).elementalDamage ~= nil
	local ids = {}
	local center = if exploding
		then o.position
		else o.position + Vector3.new(pet.hitOffsetXPoints * scale, 0, pet.hitOffsetZPoints * scale)
	local radius = if exploding
		then pet.explosionRadiusPoints * scale * math.max(
			Config.Combat.explosion.minimumSizeFactor,
			pet.explosionScale * (1 + (sheet.explosionSize or 0) / 100)
		)
		else pet.hitRadiusPoints * scale
	Enemy.queryRadius(center, radius, ids)
	local kills = 0
	for _, id in ids do
		local critical = stats.critChance ~= 0 and Random.number("Combat", o.owner) <= stats.critChance
		local at = Enemy.getPosition(id)
		local kind = Enemy.getKind(id)
		local boss = Config.Enemies.bosses[kind] ~= nil or Config.Enemies.champions[kind] ~= nil
		local killed = Weapons.structureHit(
			o.owner,
			id,
			Rules.hitDamage(stats.damage, 1, if critical then stats.critDamage else 1, boss, sheet.eliteDamage or 0),
			if exploding then "Explosion" else nil,
			critical,
			elemental
		)
		if killed then
			kills += 1
		end
		if not exploding and not killed and at and (at - o.position).Magnitude > 0 and stats.knockback ~= 0 then
			local direction = (at - o.position).Unit * stats.knockback
			Enemy.knock(id, direction.X, direction.Z)
		end
		if not exploding and Random.number("Combat", o.owner) < stats.lifeSteal then
			Combat.lifeSteal(o.owner)
		end
	end
	if exploding then
		Weapons.reportExplosion(o.owner, kills)
	end
end

local function tryJump(o: any): boolean
	if not o.pet.explosion or o.jump or o.attacking or o.jumpCooldownFrames > 0 then
		return false
	end
	local ids = {}
	Enemy.collectIds(ids)
	local best, maximumHp = nil, -math.huge
	local enemyCount = 0
	for _, id in ids do
		local kind = Enemy.getKind(id)
		if kind ~= "Tree" then
			enemyCount += 1
		end
		local at = Enemy.getPosition(id)
		if kind ~= "Tree" and (at - o.position).Magnitude ^ 2 > o.pet.jumpMinimumSquaredPoints * scale ^ 2 then
			local hp = Enemy.getMaxHealth(id)
			if hp > maximumHp then
				best, maximumHp = at, hp
			end
		end
	end
	if best then
		o.jump = { from = o.position, to = best, frame = 0 }
	elseif enemyCount > 0 then
		o.jumpCooldownFrames = o.pet.explosion.cooldownFrames * o.pet.jumpRetryShare
	end
	return enemyCount > 0
end

function Actors.step(
	dt: number,
	sheetOf: (Player) -> any,
	spawnStructure: (Player, string, any?, Vector3?) -> ()
): boolean
	if not bodies then
		return false
	end
	local bounds = Map.getArenaBounds()
	bodies:setBounds(
		bounds.center.X - bounds.halfX,
		bounds.center.X + bounds.halfX,
		bounds.center.Z - bounds.halfZ,
		bounds.center.Z + bounds.halfZ
	)
	bodies.params.obstacles = Map.getObstacles()
	stepRemainder += dt * C.frameRate
	local frames = math.floor(stepRemainder)
	stepRemainder -= frames
	local moved = false
	local requests = {}
	for _ = 1, frames do
		if not bodies then
			break
		end -- A credited pet kill may have synchronously ended the run.
		for _, o in members do
			local target
			if o.pet.followOwner then
				target = Bot.goal(o)
			else
				if not o.target or not Enemy.isAlive(o.target) then
					release(o)
					chooseTarget(o)
				end
				target = o.target and Enemy.getPosition(o.target)
			end
			local goal = if target and not o.jump then target + o.bodyOffset else nil
			bodies:setGoal(o.bodyId, if goal then goal.X else nil, if goal then goal.Z else nil)
			bodies:setSpeedFactor(o.bodyId, math.max(1, 1 + (sheetOf(o.owner).speed or 0) / 100))
		end
		bodies:step(1 / C.frameRate, {}, {}, 0)
		for _, o in members do
			local previous, landed = o.position, false
			local x, z = bodies:getPosition(o.bodyId)
			local at = Vector3.new(x, o.position.Y, z) - o.bodyOffset
			if o.pet.followOwner then
				moved = moved or (at - previous).Magnitude > 0
				o.position = at
				local request = Bot.step(o, sheetOf(o.owner))
				if request then
					table.insert(requests, request)
				end
				continue
			end
			if o.jump then
				o.jump.frame += 1
				local t = o.jump.frame / (o.pet.jumpSeconds * C.frameRate)
				at = o.jump.from + (o.jump.to - o.jump.from) * Rules.jumpShare(t)
				local body = at + o.bodyOffset
				bodies:teleport(o.bodyId, body.X, body.Z)
				if t >= 1 then
					landed = true
					o.position = at
					o.jump = nil
					o.jumpCooldownFrames = o.pet.explosion.cooldownFrames
					attack(o, sheetOf(o.owner), true)
					release(o)
					chooseTarget(o)
				end
			end
			moved = moved or (at - previous).Magnitude > 0
			o.position = at
			if landed then
				o.cooldownFrames = math.max(0, o.cooldownFrames - 1)
				continue
			end
			-- The original hitbox stays enabled for one physics frame, then closes and starts a fresh cooldown.
			if o.attacking then
				o.attacking = false
				o.cooldownFrames = Rules.compute(o.pet.weapon, sheetOf(o.owner)).cooldown * C.frameRate
			else
				o.cooldownFrames = math.max(0, o.cooldownFrames - 1)
				if o.pet.explosion then
					o.jumpCooldownFrames = math.max(0, o.jumpCooldownFrames - 1)
				end
				local jumped = tryJump(o)
				if not jumped and not o.jump and o.cooldownFrames == 0 then
					attack(o, sheetOf(o.owner))
					o.attacking = true
				end
			end
		end
	end
	for _, request in requests do
		if bodies then
			spawnStructure(request.owner, request.kind, request.definition, request.at)
		end
	end
	return moved
end
return Actors
