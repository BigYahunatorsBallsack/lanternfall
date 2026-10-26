--!strict
-- Text formatting shared by server logs and client UI (RunDirector, HUD, lobby, results).

local Format = {}

-- 754.3 -> "12:34"; negative values show as "00:00".
function Format.time(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", total // 60, total % 60)
end

return Format
