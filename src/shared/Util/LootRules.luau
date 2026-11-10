--!strict
-- Loot formulas from Config.Loot as pure functions (DESIGN.md section 3, since B6): the orb drop chance by wave, how
-- much a new orb takes from the bag, whether a kill drops a fruit or a crate, how many trees a wave brings and the
-- Shards for selling a crate's item. Used by ExperienceService, LootService, SpawnDirector and UpgradeService; tested
-- in tests/LootRules.spec.luau.

local Config = script.Parent.Parent.Config
local Enemies = require(Config.Enemies)
local Loot = require(Config.Loot)

local LootRules = {}

-- Chance that a normal enemy killed in `wave` drops its orb.
function LootRules.orbChance(wave: number): number
	local rule = Loot.orbDrop
	if wave <= rule.fullUntilWave then
		return 1
	end
	return math.max(rule.minChance, 1 - rule.lossPerWave * wave)
end

-- Whether a killed enemy of this kind drops its orb; `roll` is a random number 0 <= x < 1. `share` (B11, default 1)
-- multiplies the chance (horde waves drop fewer).
function LootRules.dropsOrb(kind: Enemies.Enemy, wave: number, roll: number, share: number?): boolean
	if kind.elite or (kind.loot and kind.loot.alwaysOrbs) then
		return true
	end
	return roll < LootRules.orbChance(wave) * (share or 1)
end

-- How much of the bag a new orb worth `value` takes along (at most what is in the bag).
function LootRules.bagPull(bag: number, value: number): number
	if bag <= 0 or value <= 0 then
		return 0
	end
	return math.min(bag, value * Loot.bag.pullPerValue)
end

-- What a killed enemy of this kind drops besides its orb: "Fruit", "Crate" or nil (Brotato ItemService.
-- get_consumable_to_drop and main.spawn_consumables). `luck` is the team's Luck (summed over the players like
-- Brotato), `crates` the crates dropped this wave, `roll` and `crateRoll` random numbers 0 <= x < 1, `crateBonus` the
-- team's Crate chance percent, `endlessFactor` the endless factor of the wave (0 in the first 20 waves). Elites drop
-- chests instead.
function LootRules.consumable(
	kind: Enemies.Enemy,
	luck: number,
	crates: number,
	roll: number,
	crateRoll: number,
	crateBonus: number?,
	endlessFactor: number?
): string?
	if kind.elite then
		return nil
	end
	local loot = kind.loot
	local endless = endlessFactor or 0
	local factor = 1 + luck / 100
	local always = loot ~= nil and loot.crate == true -- Brotato always_drop_consumables (Looters)
	local chance = if loot and loot.consumableChance then loot.consumableChance else Loot.consumables.chance
	chance = math.min(1, chance * factor)
	if endless > 0 then
		chance /= 1 + endless
	end
	if not always and not (roll < chance) then
		return nil
	end
	local share = if loot and loot.crateShare then loot.crateShare else Loot.consumables.crateShare
	local crateChance = share * factor / (1 + math.max(0, crates))
	crateChance += crateChance * (crateBonus or 0) / 100
	if always and share >= 1 and endless <= 0 then
		crateChance = 1 -- guaranteed loot encounters are exempt from Luck, including -100 Luck
	end
	return if crateRoll < crateChance then "Crate" else "Fruit"
end

-- Shovel kills roll independently of Luck, except neutral trees and guaranteed consumable drops.
function LootRules.dugCrate(kind: Enemies.Enemy, chance: number, crates: number, roll: number): boolean
	return chance > 0 and kind.id ~= "Tree" and not (kind.loot and kind.loot.crate) and roll <= chance / (1 + crates)
end

-- Shards for recycling a crate item, including the Sell Value stat, rounded down.
function LootRules.sellPrice(price: number, share: number, sellValue: number): number
	return math.floor(price * math.max(0, share + sellValue / 100) + 1e-9)
end

return LootRules
