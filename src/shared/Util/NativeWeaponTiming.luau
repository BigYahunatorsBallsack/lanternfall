--!strict
-- Native integer-frame cooldowns shared by WeaponStats and read-only OfferText previews.
local Rules = require(script.Parent.Parent.Config.Combat).originalWeapons
local Timing = {}
function Timing.factor(attackSpeed: number): number
	local speed = attackSpeed / 100
	return if speed < 0 then 1 + math.abs(speed) else 1 / (1 + speed)
end
function Timing.apply(stats: { [string]: number }, attackSpeed: number, minimum: number)
	if not stats.nativeTiming then
		return
	end
	local factor = Timing.factor(attackSpeed)
	local function seconds(frames: number): number
		-- WeaponService.apply_attack_speed_mod_to_cooldown: the base is raised to the minimum first, then truncated
		local base = math.max(Rules.sourceMinimumFrames, frames)
		return math.max(Rules.sourceMinimumFrames, math.floor(base * factor)) / Rules.sourceFrameRate
	end
	stats.cooldown = math.max(minimum, seconds(stats.nativeCooldownFrames))
	if stats.attackLockSeconds then
		stats.cooldown = math.max(stats.cooldown, stats.attackLockSeconds)
	end
	if stats.nativeReloadFrames then
		stats.reloadSeconds = math.max(stats.cooldown, minimum, seconds(stats.nativeReloadFrames))
	end
end
return Timing
