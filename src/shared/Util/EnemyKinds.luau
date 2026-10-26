--!strict
-- Every enemy kind the simulation and the renderer know: the types from Config.Enemies plus one Gloom Elite variant
-- of each (DESIGN.md section 7) with the elite multipliers applied (HP, speed, contact and projectile damage, radius,
-- mass), the elite XP and typeId + elite.typeIdOffset. Minute and difficulty multipliers come on top at spawn time
-- (EnemySim.spawn). Used by EnemySim, SpawnDirector and EnemyRenderer/Models.

local Enemies = require(script.Parent.Parent.Config.Enemies)

local Elite = Enemies.elite

local EnemyKinds = {}

local normal: { [string]: Enemies.Enemy } = {}
local elites: { [string]: Enemies.Enemy } = {}
local byTypeId: { [number]: Enemies.Enemy } = {}

for id, base in Enemies.types do
	local elite: Enemies.Enemy = table.clone(base)
	elite.typeId = base.typeId + Elite.typeIdOffset
	elite.displayName = `Gloom {base.displayName}`
	elite.hp = base.hp * Elite.hpMultiplier
	elite.contactDamage = base.contactDamage * Elite.damageMultiplier
	elite.speed = base.speed * Elite.speedMultiplier
	elite.radius = base.radius * Elite.sizeMultiplier
	elite.mass = base.mass * Elite.massMultiplier
	elite.xp = Elite.xp
	elite.elite = true
	local ranged = base.ranged
	if ranged then
		local eliteRanged = table.clone(ranged)
		eliteRanged.projectileDamage = ranged.projectileDamage * Elite.damageMultiplier
		elite.ranged = table.freeze(eliteRanged)
	end
	normal[id] = base
	elites[id] = table.freeze(elite)
	byTypeId[base.typeId] = base
	byTypeId[elite.typeId] = elites[id]
end

-- The kind for an enemy id from Config.Enemies.types, its elite variant if `elite`. nil for unknown ids.
function EnemyKinds.get(enemyId: string, elite: boolean?): Enemies.Enemy?
	return if elite then elites[enemyId] else normal[enemyId]
end

-- The kind behind a snapshot typeId (normal or elite), nil for unknown ids.
function EnemyKinds.byTypeId(typeId: number): Enemies.Enemy?
	return byTypeId[typeId]
end

return EnemyKinds
