--!strict
-- Text formatting shared by server logs and client UI (RunDirector, HUD, lobby, results, shop).

local Format = {}

-- 754.3 -> "12:34"; negative values show as "00:00".
function Format.time(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", total // 60, total % 60)
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI" }

-- Weapon tier as a Roman numeral: 3 -> "III" (Brotato's tiers I-IV, since B3).
function Format.tier(tier: number): string
	return ROMAN[tier] or tostring(tier)
end

return Format
