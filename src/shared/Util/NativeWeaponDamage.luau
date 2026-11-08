--!strict
-- Native conditional base damage shared by weapon computation and shop previews; numeric rules come from weapon Config.
local Damage = {}
function Damage.base(base: number, stats: { [string]: number }, sheet: { [string]: number }): number
	if stats.baseDamageKnockbackThreshold and (sheet.knockback or 0) >= stats.baseDamageKnockbackThreshold then
		return math.round(base * stats.baseDamageKnockbackMultiplier)
	end
	return base
end
-- Stable init_base_stats truncates scaled flat damage before applying rounded Damage percent.
function Damage.total(flat: number, factor: number, stats: { [string]: number }): number
	if stats.nativeTiming then
		return math.max(1, math.round(math.floor(math.max(1, flat)) * factor))
	end
	return math.max(1, flat * factor)
end
return Damage
