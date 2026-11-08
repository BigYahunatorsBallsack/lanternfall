--!strict
-- Native weapon/character unlocks from persistent wins/challenge flags; PlayerDataService owns writes, selection reads masks.
local Shared = script.Parent.Parent
local Access = require(Shared.Config.CharacterWeaponAccess)
local Characters = require(Shared.Config.CharacterCatalog)
local Unlocks = require(Shared.Config.CharacterUnlocks)
local CharacterAccess = {}
export type Record = {
	achievements: { [string]: boolean },
	characterStats: { [string]: { wins: number } },
	classes: { string }?, -- preserves explicit saved grants, including the trusted owner debug command
}

function CharacterAccess.challengeKey(id: string): string
	return `Brotato:{id}`
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
	return challenge ~= nil and data.achievements[CharacterAccess.challengeKey(challenge.challengeId)] == true
end

function CharacterAccess.characterMask(data: Record?): { [string]: boolean }
	local result = {}
	for id in Characters do
		result[id] = CharacterAccess.characterUnlocked(data, id)
	end
	return result
end

return CharacterAccess
