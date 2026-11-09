--!strict
-- Stable common ranged modifiers; WeaponStats, offer previews and structure projectiles share these rules.
local Config = require(script.Parent.Parent.Config.Combat)
local Ranged = {}
function Ranged.apply(stats: { [string]: number }, sheet: { [string]: number })
	if stats.nativeAccuracy == nil then
		return
	end
	stats.nativeAccuracy += (sheet.accuracy or 0) / 100
	local projectiles = sheet.projectiles or 0
	if stats.count and stats.count > 0 then
		stats.count += projectiles
	end
	stats.nativeSpread = (stats.nativeSpread or 0) + projectiles * Config.originalWeapons.spreadPerProjectile
end
return Ranged
