--!strict
-- Stable common ranged modifiers; WeaponStats, offer previews and structure projectiles share these rules.
local Config = require(script.Parent.Parent.Config.Combat)
local Original = require(script.Parent.Parent.Config.CharacterRangedData)
local Ranged = {}
function Ranged.apply(stats: { [string]: number }, sheet: { [string]: number }, id: string?, tier: number?)
	local family = id and Original[id]
	if family and (sheet.nativePackage == 1 or (sheet.projectiles or 0) ~= 0 or (sheet.accuracy or 0) ~= 0) then
		local original = family[math.clamp(tier or 1, 1, #family)]
		stats.nativeAccuracy = original.accuracy
		stats.nativeSpread = original.spread
		stats.count = original.count
	end
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
