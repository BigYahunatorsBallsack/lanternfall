--!strict
-- Native integer-frame cooldowns shared by WeaponStats and read-only OfferText previews.
local Rules = require(script.Parent.Parent.Config.Combat).originalWeapons
local Timing = {}
function Timing.apply(stats: { [string]: number }, attackSpeed: number, minimum: number)
	if not stats.nativeTiming then
		return
	end
	local speed = attackSpeed / 100
	local factor = if speed < 0 then 1 + math.abs(speed) else 1 / (1 + speed)
	local function seconds(frames: number): number
		return math.max(Rules.sourceMinimumFrames, math.floor(frames * factor)) / Rules.sourceFrameRate
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
