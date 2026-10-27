--!strict
-- Every enemy kind the simulation and the renderer know: the types from Config.Enemies plus Gloom Elite variants of
-- each (DESIGN.md section 7) with the elite multipliers applied (HP, speed, contact and projectile damage, radius,
-- mass), the elite XP and typeId + elite.typeIdOffset: one plain elite and one per affix (Swift, Armored, ...), all
-- with the same typeId; the affix travels in the snapshot flags (Net/Snapshot). Minute and difficulty multipliers
-- come on top at spawn time (EnemySim.spawn). Used by EnemySim, SpawnDirector and EnemyRenderer/Models.

local Enemies = require(script.Parent.Parent.Config.Enemies)

local Elite = Enemies.elite

local EnemyKinds = {}

local normal: { [string]: Enemies.Enemy } = {}
local elites: { [string]: { [number]: Enemies.Enemy } } = {} -- by enemy id, then affix index (0 = none)
local byTypeId: { [number]: Enemies.Enemy } = {}

local function withAffix(elite: Enemies.Enemy, index: number): Enemies.Enemy
	local affix = Elite.affixes[index]
	local kind: Enemies.Enemy = table.clone(elite)
	kind.affix = index
	kind.displayName = `{affix.displayName} {elite.displayName}`
	kind.speed = elite.speed * (affix.speedMultiplier or 1)
	kind.damageTaken = affix.damageTaken
	kind.summon = affix.summon
	return table.freeze(kind)
end

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
	table.freeze(elite)
	local variants = { [0] = elite }
	for index in Elite.affixes do
		variants[index] = withAffix(elite, index)
	end
	normal[id] = base
	elites[id] = variants
	byTypeId[base.typeId] = base
	byTypeId[elite.typeId] = elite
end

-- The kind for an enemy id from Config.Enemies.types; with `elite` its elite variant, with `affix` (index into
-- Config.Enemies.elite.affixes) the elite with that affix. nil for unknown ids and affixes.
function EnemyKinds.get(enemyId: string, elite: boolean?, affix: number?): Enemies.Enemy?
	if not elite then
		return normal[enemyId]
	end
	local variants = elites[enemyId]
	return variants and variants[affix or 0]
end

-- The kind behind a snapshot typeId (normal or plain elite), nil for unknown ids.
function EnemyKinds.byTypeId(typeId: number): Enemies.Enemy?
	return byTypeId[typeId]
end

-- The look (model) of a kind: its `look` or its own id.
function EnemyKinds.lookOf(kind: Enemies.Enemy): string
	return kind.look or kind.id
end

return EnemyKinds
