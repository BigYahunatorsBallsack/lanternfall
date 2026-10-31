--!strict
-- Text formatting shared by server logs and client UI (RunDirector, HUD, lobby, results, shop).

local Format = {}

-- 754.3 -> "12:34"; negative values show as "00:00".
function Format.time(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", total // 60, total % 60)
end

-- Paket 18: a long wait in its two largest units: 90061 -> "1d 1h", 18720 -> "5h 12m", 59 -> "0m".
function Format.duration(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local days, hours, minutes = total // 86400, total % 86400 // 3600, total % 3600 // 60
	if days > 0 then
		return `{days}d {hours}h`
	elseif hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m`
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI" }

-- Weapon tier as a Roman numeral: 3 -> "III" (Brotato's tiers I-IV, since B3).
function Format.tier(tier: number): string
	return ROMAN[tier] or tostring(tier)
end

return Format
