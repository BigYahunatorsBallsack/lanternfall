--!strict
-- Pure native character XP/card rules and round-robin material shares; called by ExperienceService and its specs.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local StatIds = require(game:GetService("ReplicatedStorage").Shared.Config.CharacterMechanics).statIds

export type ProgressionRules = {
	xpNeededMultiplier: number,
	cardsAllowed: boolean,
	cardAmountMultiplier: number,
	slotUpgradeLimit: number,
	bannedStats: { [string]: boolean },
}

local CharacterRules = {}

-- Percent threshold modifiers add before forming a factor; the resulting XP requirement remains fractional.
-- Baby's weapon-slot choice is separate from Droid's no_level_upgrades queue flag.
function CharacterRules.forClass(classId: string?): ProgressionRules
	local class = if classId then Config.Classes[classId] else nil
	local native = class and class.native
	local thresholdModifier = 0
	local noLevelUpgrades = 0
	local cardModifier, slotLimit = 0, 0
	for _, effect in if native then native.sourceEffects else {} do
		if effect.effectType ~= "res://items/global/effect.gd" or effect.customKey ~= "" then
			continue
		end
		if effect.sourceKey == "next_level_xp_needed" and effect.storageMethod == 0 then
			thresholdModifier += effect.amount
		elseif effect.sourceKey == "no_level_upgrades" and effect.storageMethod == 2 then
			noLevelUpgrades = effect.amount
		elseif effect.sourceKey == "level_upgrades_modifications" and effect.storageMethod == 0 then
			cardModifier += effect.amount
		elseif effect.sourceKey == "weapon_slot_upgrades" and effect.storageMethod == 0 then
			slotLimit += effect.amount
		end
	end
	local banned: { [string]: boolean } = {}
	for _, originalId in (native and native.bannedUpgrades) or {} do
		local id = StatIds[originalId:gsub("^upgrade_", "stat_")]
		assert(id, `Unknown native banned upgrade {originalId}`)
		banned[id] = true
	end
	return {
		xpNeededMultiplier = 1 + thresholdModifier / 100,
		cardsAllowed = noLevelUpgrades == 0,
		cardAmountMultiplier = 1 + cardModifier / 100,
		slotUpgradeLimit = slotLimit,
		bannedStats = banned,
	}
end

-- Native sharing consumes one material while the remaining value is positive, so a positive fraction consumes
-- one final turn. Quotient/remainder produces the same shares in O(participantCount), independent of the amount.
-- nextIndex is a saved one-based rotation cursor; wrap it if the participant list has become shorter.
function CharacterRules.distributeMaterials(
	value: number,
	participantCount: number,
	nextIndex: number?
): ({ number }, number)
	assert(value == value and math.abs(value) < math.huge, "Material value must be finite")
	assert(
		participantCount >= 1 and participantCount <= 4 and participantCount % 1 == 0,
		"Participant count must be an integer from one to four"
	)
	local cursor = nextIndex or 1
	assert(cursor >= 1 and cursor < math.huge and cursor % 1 == 0, "Material cursor must be a positive integer")
	cursor = (cursor - 1) % participantCount + 1
	local turns = math.max(0, math.ceil(value))
	local wholeRounds = math.floor(turns / participantCount)
	local remainder = turns % participantCount
	local shares = table.create(participantCount, wholeRounds)
	for offset = 0, remainder - 1 do
		local index = (cursor - 1 + offset) % participantCount + 1
		shares[index] += 1
	end
	return shares, (cursor - 1 + remainder) % participantCount + 1
end

return CharacterRules
