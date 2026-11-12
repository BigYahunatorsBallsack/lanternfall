--!strict
-- Native weapon/character unlocks from persistent wins/challenge flags; PlayerDataService owns writes, selection reads masks.
local Shared = script.Parent.Parent
local Access = require(Shared.Config.CharacterWeaponAccess)
local Characters = require(Shared.Config.CharacterCatalog)
local Unlocks = require(Shared.Config.CharacterUnlocks)
local PetAccess = require(Shared.Config.PetAccess)
local Zones = require(Shared.Config.NativeZones)
local Nightmare = require(Shared.Config.Nightmare)
local CharacterAccess = {}
export type Record = {
	achievements: { [string]: boolean },
	characterStats: { [string]: { wins: number } },
	classes: { string }?, -- preserves explicit saved grants, including the trusted owner debug command
	stats: { bestDanger: number }?,
	nativeZoneBest: { [string]: { [string]: number } }?,
}

function CharacterAccess.challengeKey(id: string): string
	return `Brotato:{id}`
end
function CharacterAccess.petUnlocked(data: Record?, id: string): boolean
	local rule = PetAccess.items[id]
	if not rule then
		return false
	end
	if rule.free then
		return true
	end
	return data ~= nil
		and rule.challengeId ~= nil
		and data.achievements[CharacterAccess.challengeKey(rule.challengeId)] == true
end
function CharacterAccess.petsComplete(data: Record?): boolean
	for id in PetAccess.items do
		if not CharacterAccess.petUnlocked(data, id) then
			return false
		end
	end
	return true
end

function CharacterAccess.weaponUnlocked(data: Record?, weaponId: string): boolean
	local rule = Access[weaponId]
	if not rule then
		return false
	end
	if rule.free then
		return true
	end
	if not data then
		return false
	end
	if rule.challengeId and data.achievements[CharacterAccess.challengeKey(rule.challengeId)] then
		return true
	end
	local character = rule.winWith and data.characterStats[rule.winWith]
	return character ~= nil and character.wins > 0
end

function CharacterAccess.weaponMask(data: Record?): { [string]: boolean }
	local result = {}
	for id in Access do
		result[id] = CharacterAccess.weaponUnlocked(data, id)
	end
	return result
end

function CharacterAccess.characterUnlocked(data: Record?, classId: string): boolean
	local class = Characters[classId]
	if not class then
		return false
	end
	if class.free then
		return true
	end
	if not data then
		return false
	end
	if data.classes and table.find(data.classes, classId) then
		return true
	end
	local challenge = Unlocks[classId]
	if not challenge then
		return false
	end
	if data.achievements[CharacterAccess.challengeKey(challenge.challengeId)] == true then
		return true
	end
	if challenge.kind == "PetChallenges" then
		return CharacterAccess.petsComplete(data)
	end
	if challenge.kind == "WinNativeDanger" then
		for characterId, zones in data.nativeZoneBest or {} do
			if not Characters[characterId] or type(zones) ~= "table" then
				continue
			end
			for zoneId, danger in zones do
				if
					Zones.byId[zoneId]
					and type(danger) == "number"
					and danger >= challenge.danger
					and danger <= Nightmare.level
					and danger == math.floor(danger)
				then
					return true
				end
			end
		end
		return false
	end
	return challenge.kind == "WinDanger" and data.stats ~= nil and data.stats.bestDanger >= challenge.danger
end

function CharacterAccess.characterMask(data: Record?): { [string]: boolean }
	local result = {}
	for id in Characters do
		result[id] = CharacterAccess.characterUnlocked(data, id)
	end
	return result
end

return CharacterAccess
