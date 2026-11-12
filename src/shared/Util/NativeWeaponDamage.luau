--!strict
-- Native conditional base damage shared by weapon computation and shop previews; numeric rules come from weapon Config.
local ModifierFields = require(script.Parent.Parent.Config.WeaponModifiers).scalingFields
local Damage = {}
-- Original weapon_scaling_stats adds coefficients after any pet-specific expansion, without changing source tables.
function Damage.scaling(base: { [string]: number }, sheet: { [string]: number }): { [string]: number }
	local result = base
	for stat, field in ModifierFields do
		local amount = sheet[field] or 0
		if amount ~= 0 then
			if result == base then
				result = table.clone(base)
			end
			result[stat] = (result[stat] or 0) + amount / 100
		end
	end
	return result
end
-- Exploding weapon effects add their bonus to Damage before the native minimum and rounding.
function Damage.factor(sheet: { [string]: number }, exploding: boolean): number
	return math.max(0, 1 + ((sheet.damage or 0) + (if exploding then sheet.explosionDamage or 0 else 0)) / 100)
end
function Damage.base(base: number, stats: { [string]: number }, sheet: { [string]: number }): number
	if stats.baseDamageKnockbackThreshold and (sheet.knockback or 0) >= stats.baseDamageKnockbackThreshold then
		return math.round(base * stats.baseDamageKnockbackMultiplier)
	end
	return base
end
-- Stable init_base_stats truncates scaled flat damage before applying rounded Damage percent.
function Damage.total(flat: number, factor: number, stats: { [string]: number }): number
	if stats.nativeTiming or stats.nativeExplosive then
		return math.max(1, math.round(math.floor(math.max(1, flat)) * factor))
	end
	return math.max(1, flat * factor)
end
return Damage
