--!strict
-- Native character explosion calculation; WeaponService supplies validated source definitions and current stats.
local Shared = game:GetService("ReplicatedStorage").Shared
local Definitions = require(Shared.Config.CharacterExplosions)
local Stats = require(Shared.Config.Stats)
export type Computed = {
	damage: number,
	critChance: number,
	critDamage: number,
	radius: number,
	offsetZ: number,
}
local Explosion = {}

function Explosion.compute(definition: Definitions.Definition, sheet: { [string]: number }): Computed
	local damage = definition.damage
	for stat, multiplier in definition.scaling do
		damage += (sheet[stat] or 0) * multiplier
	end
	-- Native init_base_stats truncates flat scaling, then rounds the sum of Damage and Explosion Damage bonuses.
	damage = math.floor(math.max(1, damage))
	damage = math.max(1, math.round(damage * (1 + ((sheet.damage or 0) + (sheet.explosionDamage or 0)) / 100)))
	local scale =
		math.max(Definitions.minimumAreaScale, (definition.areaScale or 1) * (1 + (sheet.explosionSize or 0) / 100))
	return {
		damage = damage,
		critChance = math.clamp(definition.critChance + (sheet.critChance or 0) / 100, 0, 1),
		critDamage = definition.critDamage
			+ (if definition.baseCritDamageOnly then 0 else (sheet.critDamage or 0) / 100),
		radius = definition.radiusPoints * Stats.range.studsPerPoint * scale,
		offsetZ = definition.offsetZPoints * Stats.range.studsPerPoint * scale,
	}
end

function Explosion.hitDamage(stats: Computed, critical: boolean, eliteDamage: number): number
	local damage = if critical then math.round(stats.damage * stats.critDamage) else stats.damage
	return math.max(1, math.round(damage * math.max(0, 1 + eliteDamage / 100)))
end

return Explosion
