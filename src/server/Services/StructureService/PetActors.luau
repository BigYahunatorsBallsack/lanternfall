--!strict
-- Authoritative Ratzilla bodies and one-frame melee windows; StructureService owns deployments and snapshots.
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
	local family = claimed[o.pet.targetFamily]
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

function Actors.add(o: any)
	local def = Config.Structures.kinds[o.kind]
	if not def.petKind then
		return
	end
	local pet = C.kinds[def.petKind]
	bodies = bodies or createWorld()
	o.pet = pet
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
	o.cooldownFrames = pet.weapon.cooldownFrames
	o.attacking = false
	claimed[pet.targetFamily] = claimed[pet.targetFamily] or {}
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

local function beastMaster(player: Player): boolean
	local class = Config.Classes[Run.getParticipantClassId(player)]
	for _, rule in (class and class.native and class.native.remainingRules) or {} do
		if rule.sourceKey == "beast_master_effect" and rule.amount > 0 then
			return true
		end
	end
	return false
end

local function attack(o: any, sheet: { [string]: number })
	local pet = o.pet
	local stats = Rules.compute(pet.weapon, sheet, beastMaster(o.owner))
	local ids = {}
	local center = o.position + Vector3.new(pet.hitOffsetXPoints * scale, 0, pet.hitOffsetZPoints * scale)
	Enemy.queryRadius(center, pet.hitRadiusPoints * scale, ids)
	for _, id in ids do
		local critical = Random.number("Combat", o.owner) < stats.critChance
		local at = Enemy.getPosition(id)
		local killed = Weapons.structureHit(
			o.owner,
			id,
			math.round(stats.damage * (if critical then stats.critDamage else 1)),
			nil,
			critical
		)
		if not killed and at and (at - o.position).Magnitude > 0 and stats.knockback ~= 0 then
			local direction = (at - o.position).Unit * stats.knockback
			Enemy.knock(id, direction.X, direction.Z)
		end
		if Random.number("Combat", o.owner) < stats.lifeSteal then
			Combat.lifeSteal(o.owner)
		end
	end
	return stats.cooldown * C.frameRate
end

function Actors.step(dt: number, sheetOf: (Player) -> any): boolean
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
	for _ = 1, frames do
		for _, o in members do
			if not o.target or not Enemy.isAlive(o.target) then
				release(o)
				chooseTarget(o)
			end
			local target = o.target and Enemy.getPosition(o.target)
			local goal = if target then target + o.bodyOffset else nil
			bodies:setGoal(o.bodyId, if goal then goal.X else nil, if goal then goal.Z else nil)
			bodies:setSpeedFactor(o.bodyId, math.max(1, 1 + (sheetOf(o.owner).speed or 0) / 100))
		end
		bodies:step(1 / C.frameRate, {}, {}, 0)
		for _, o in members do
			local x, z = bodies:getPosition(o.bodyId)
			local at = Vector3.new(x, o.position.Y, z) - o.bodyOffset
			moved = moved or (at - o.position).Magnitude > 0
			o.position = at
			-- The original hitbox stays enabled for one physics frame, then closes and starts a fresh cooldown.
			if o.attacking then
				o.attacking = false
				o.cooldownFrames = Rules.compute(o.pet.weapon, sheetOf(o.owner)).cooldown * C.frameRate
			else
				o.cooldownFrames = math.max(0, o.cooldownFrames - 1)
				if o.cooldownFrames == 0 then
					attack(o, sheetOf(o.owner))
					o.attacking = true
				end
			end
		end
	end
	return moved
end
return Actors
