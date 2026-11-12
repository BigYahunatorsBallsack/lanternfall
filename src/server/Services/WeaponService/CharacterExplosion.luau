--!strict
-- Native character explosion calculation; WeaponService supplies validated source definitions and current stats.
local Shared = game:GetService("ReplicatedStorage").Shared
local Definitions = require(Shared.Config.CharacterExplosions)
local Stats = require(Shared.Config.Stats)
local Combat = require(Shared.Config.Combat)
local PlayerConfig = require(Shared.Config.Player)
local StatMath = require(Shared.Util.StatMath)
local NativeDamage = require(Shared.Util.NativeWeaponDamage)
export type Computed = {
	damage: number,
	critChance: number,
	critDamage: number,
	radius: number,
	offsetZ: number,
	elemental: boolean,
}
local Explosion = {}

function Explosion.compute(definition: Definitions.Definition, sheet: { [string]: number }): Computed
	local damage = definition.damage
	local scaling = NativeDamage.scaling(definition.scaling, sheet)
	for stat, multiplier in scaling do
		damage += (sheet[stat] or 0) * multiplier
	end
	-- Native init_base_stats truncates flat scaling, then rounds the sum of Damage and Explosion Damage bonuses.
	damage = math.floor(math.max(1, damage))
	damage = math.max(1, math.round(damage * (1 + ((sheet.damage or 0) + (sheet.explosionDamage or 0)) / 100)))
	local scale =
		math.max(Definitions.minimumAreaScale, (definition.areaScale or 1) * (1 + (sheet.explosionSize or 0) / 100))
	return {
		elemental = scaling.elementalDamage ~= nil,
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

-- Original item explosions truncate flat scaling, then round additive Damage and Explosion Damage bonuses.
function Explosion.computeItemEffect(
	base: number,
	scaling: { [string]: number }?,
	size: number,
	sheet: { [string]: number }
): Computed
	local flat = base
	local modified = NativeDamage.scaling(scaling or {}, sheet)
	for stat, share in modified do
		flat += share * (sheet[stat] or 0)
	end
	return {
		elemental = modified.elementalDamage ~= nil,
		damage = NativeDamage.total(flat, NativeDamage.factor(sheet, true), { nativeTiming = 1 }),
		critChance = StatMath.critChance(PlayerConfig.critChance, sheet.critChance or 0),
		critDamage = PlayerConfig.critMultiplier,
		radius = Combat.explosion.baseRadius * size * math.max(0, 1 + (sheet.explosionSize or 0) / 100),
		offsetZ = 0,
	}
end

-- Native innate burn keeps its own duration/scaling; global burns add only their unscaled base damage.
function Explosion.burnDamage(
	definition: Definitions.Definition,
	sheet: { [string]: number },
	globalBase: number
): number?
	local burn = definition.burn
	if not burn then
		return nil
	end
	local damage = burn.damage + globalBase
	for stat, multiplier in burn.scaling do
		damage += (sheet[stat] or 0) * multiplier
	end
	return math.max(1, math.round(math.floor(math.max(1, damage)) * math.max(0, 1 + (sheet.damage or 0) / 100)))
end

return Explosion
