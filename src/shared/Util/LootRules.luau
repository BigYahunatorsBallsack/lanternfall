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

-- What a killed enemy of this kind drops besides its orb: "Fruit", "Crate" or nil. `luck` is the team's Luck,
-- `crates` the crates dropped this wave, `roll` and `crateRoll` random numbers 0 <= x < 1. Elites drop chests instead.
function LootRules.consumable(
	kind: Enemies.Enemy,
	luck: number,
	crates: number,
	roll: number,
	crateRoll: number
): string?
	if kind.elite then
		return nil
	end
	local loot = kind.loot
	local factor = math.max(0, 1 + luck / 100)
	local chance = if loot and loot.consumableChance then loot.consumableChance else Loot.consumables.chance
	if not (roll < chance * factor) then
		return nil
	end
	if loot and loot.crate then
		return "Crate"
	end
	local share = if loot and loot.crateShare then loot.crateShare else Loot.consumables.crateShare
	return if crateRoll < share * factor / (1 + math.max(0, crates)) then "Crate" else "Fruit"
end

-- Trees a wave brings: perWave plus the team's Trees stat; a fractional rest is a chance (`roll` 0 <= x < 1).
function LootRules.treesForWave(treesStat: number, roll: number): number
	local total = math.max(0, Loot.trees.perWave + treesStat)
	local whole = math.floor(total)
	return whole + (if roll < total - whole then 1 else 0)
end

-- Fighting seconds into a wave at which its trees appear: evenly over the first spawnShare of `length` seconds.
function LootRules.treeTimes(count: number, length: number): { number }
	local times = {}
	local span = length * Loot.trees.spawnShare
	for index = 1, count do
		table.insert(times, span * (index - 0.5) / count)
	end
	return times
end

-- How many Looter rolls are due at `seconds` into wave `wave` since the last check at `previous` seconds: at
-- firstSeconds and every everySeconds after that, from fromWave.
function LootRules.looterRollsDue(wave: number, previous: number, seconds: number): number
	local rule = Loot.looter
	if wave < rule.fromWave or seconds < rule.firstSeconds then
		return 0
	end
	local function passed(at: number): number
		if at < rule.firstSeconds then
			return 0
		end
		return math.floor((at - rule.firstSeconds) / rule.everySeconds) + 1
	end
	return math.max(0, passed(seconds) - passed(previous))
end

-- Shards for selling a crate's item worth `price` Shards in the shop: `share` (Config.Shop.sellShare) plus
-- `sellValue` percent (the Sell Value stat), rounded down.
function LootRules.sellPrice(price: number, share: number, sellValue: number): number
	return math.floor(price * math.max(0, share + sellValue / 100) + 1e-9)
end

return LootRules
