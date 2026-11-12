--!strict
-- Original pet weapon arithmetic and movement speed; used by StructureService pet attacks and focused source tests.
local Shared = game:GetService("ReplicatedStorage").Shared
local Stats = require(Shared.Config.Stats)
local Rules = {}

-- Boss.take_damage applies its positive bonus to integer hitbox damage before Unit.take_damage rolls the critical.
function Rules.hitDamage(
	base: number,
	share: number?,
	criticalMultiplier: number,
	boss: boolean,
	bossBonus: number
): number
	local amount = math.max(1, math.floor(base * (share or 1)))
	if boss and bossBonus > 0 then
		amount = math.floor(amount * (1 + bossBonus / 100))
	end
	return math.max(1, math.round(amount * criticalMultiplier))
end

local Native = require(Shared.Util.NativePetStats)
Rules.scaling = Native.scaling
Rules.weaponScaling = Native.weaponScaling
Rules.burnDamage = Native.burnDamage
Rules.compute = Native.compute

function Rules.speed(def: any, sheet: { [string]: number }): number
	return def.speedPoints * Stats.range.studsPerPoint * math.max(1, 1 + (sheet.speed or 0) / 100)
end
-- Bonk Dog requests Godot 3.5 TRANS_EXPO/EASE_IN_OUT, including that engine's small endpoint correction.
-- Mathematical reference: github.com/godotengine/godot/blob/3.5/scene/animation/easing_equations.h (expo::in_out).
function Rules.jumpShare(t: number): number
	if t <= 0 then
		return 0
	end
	if t >= 1 then
		return 1
	end
	return if t < 0.5 then 0.5 * 2 ^ (10 * (2 * t - 1)) - 0.0005 else 0.50025 * (2 - 2 ^ (-10 * (2 * t - 1)))
end
return Rules
