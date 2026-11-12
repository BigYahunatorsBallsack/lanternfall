--!strict
-- Native Lootworm neutral/material targets and one-hit tree attacks; PetActors owns movement and ExperienceService owns gold.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local C = require(Shared.Config.Pets)
local Enemy = require(script.Parent.Parent.EnemySim)
local XP = require(script.Parent.Parent.ExperienceService)
local Weapons = require(script.Parent.Parent.WeaponService)
local Random = require(script.Parent.Parent.RandomService)
local Rules = require(script.Parent.PetRules)
local Worm = {}
local scale = Config.Stats.range.studsPerPoint
function Worm.init(o: any, sheet: { [string]: number })
	o.lootStats = Rules.compute(o.pet.weapon, sheet, o.beastMaster)
	o.lootDamage = o.lootStats.damage
	o.lootFrames, o.lootShooting = o.lootStats.cooldown * C.frameRate, false
	o.lootTrees, o.lootCloseTrees = {}, {}
	o.lootBonusMaterials = 0
end
function Worm.clear(o: any)
	XP.releasePetMaterials(o.id)
end
function Worm.goal(o: any, members: { any }?): Vector3?
	local ids, trees, spawned = {}, {}, false
	Enemy.collectIds(ids)
	for _, id in ids do
		if Enemy.getKind(id) == "Tree" and Enemy.isAlive(id) then
			trees[id] = true
			spawned = spawned or not o.lootTrees[id]
		end
	end
	o.lootTrees = trees
	local revision = XP.getMaterialRevision()
	if spawned or o.lootRevision ~= revision then
		o.lootTarget = nil
	end
	o.lootRevision = revision
	local target = o.lootTarget
	local position = if target and target.tree
		then (if Enemy.isAlive(target.id) then Enemy.getPosition(target.id) else nil)
		elseif target then XP.getMaterialPosition(target.id)
		else nil
	if position then
		return position
	end
	local claimedTrees, claimedMaterials = {}, {}
	for _, other in members or {} do
		local chosen = other.lootTarget
		if other ~= o and other.pet.lootworm and chosen then
			local claimed = if chosen.tree then claimedTrees else claimedMaterials
			claimed[chosen.id] = true
		end
	end
	local nearest, fallbackDistance = math.huge, math.huge
	local fallbackId, fallbackPosition
	o.lootTarget = nil
	for id in trees do
		local at = Enemy.getPosition(id)
		local distance = (at - o.position).Magnitude
		if claimedTrees[id] then
			if distance < fallbackDistance then
				fallbackDistance, fallbackId, fallbackPosition = distance, id, at
			end
		elseif distance < nearest then
			nearest, position, o.lootTarget = distance, at, { tree = true, id = id }
		end
	end
	if not position and fallbackId then
		position, o.lootTarget = fallbackPosition, { tree = true, id = fallbackId }
	end
	if not position then
		local id = XP.nearestMaterial(o.position, claimedMaterials)
		if id then
			o.lootTarget = { tree = false, id = id }
			position = XP.getMaterialPosition(id)
		end
	end
	return position
end
local function hit(o: any, sheet: { [string]: number })
	local ids, pet, stats = {}, o.pet, o.lootStats
	local center = o.position + Vector3.new(pet.hitOffsetXPoints * scale, 0, pet.hitOffsetZPoints * scale)
	Enemy.queryRadius(center, pet.hitRadiusPoints * scale, ids)
	for _, id in ids do
		local kind = Enemy.getKind(id)
		if not kind then
			continue
		end
		local critical = stats.critChance ~= 0 and Random.number("Combat", o.owner) <= stats.critChance
		local boss = Config.Enemies.bosses[kind] ~= nil or Config.Enemies.champions[kind] ~= nil
		local at = Enemy.getPosition(id)
		local killed = Weapons.structureHit(
			o.owner,
			id,
			Rules.hitDamage(o.lootDamage, 1, if critical then stats.critDamage else 1, boss, sheet.eliteDamage or 0),
			nil,
			critical,
			false
		)
		if not killed and at and stats.knockback ~= 0 and (at - o.position).Magnitude > 0 then
			local direction = (at - o.position).Unit * stats.knockback
			Enemy.knock(id, direction.X, direction.Z)
		end
		-- Original Lootworm disables deals_damage on its first contact and has no pet life-steal callback.
		break
	end
end
function Worm.step(o: any, sheet: { [string]: number }, dt: number)
	o.lootBonusMaterials += XP.stepPetMaterials(o.owner, o.id, o.position, dt)
	local pet, ids, closed = o.pet, {}, {}
	local center = o.position + Vector3.new(pet.treeOffsetXPoints * scale, 0, pet.treeOffsetZPoints * scale)
	Enemy.queryRadius(center, pet.treeRadiusPoints * scale, ids)
	local count = 0
	for _, id in ids do
		if Enemy.getKind(id) == "Tree" and Enemy.isAlive(id) then
			closed[id], count = true, count + 1
			if not o.lootCloseTrees[id] then
				o.lootDamage = math.max(o.lootDamage, math.floor(Enemy.getMaxHealth(id) / pet.treeDamageRatio))
			end
		end
	end
	o.lootCloseTrees = closed
	if not o.lootShooting then
		o.lootFrames = math.max(0, o.lootFrames - 1)
	end
	if o.lootFrames == 0 and not o.lootShooting and count > 0 then
		o.lootShooting = true
		hit(o, sheet)
	elseif o.lootShooting then
		o.lootShooting = false
		o.lootFrames = o.lootStats.cooldown * C.frameRate
	end
end
return Worm
