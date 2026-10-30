-- Unit tests for the loot formulas (Util/LootRules, B6) against Brotato's numbers in DESIGN.md section 3.

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local EnemyKinds = require(Shared.Util.EnemyKinds)
local LootRules = require(Shared.Util.LootRules)

local Types = Config.Enemies.types

describe("LootRules", function()
	it("drops every orb up to wave 4, then 1.5 % less per wave like Brotato", function()
		expect(LootRules.orbChance(1)).toBe(1)
		expect(LootRules.orbChance(4)).toBe(1)
		expect(LootRules.orbChance(5)).toBeNear(0.925)
		expect(LootRules.orbChance(10)).toBeNear(0.85)
		expect(LootRules.orbChance(20)).toBeNear(0.7)
		expect(LootRules.orbChance(60)).toBeNear(Config.Loot.orbDrop.minChance)
	end)

	it("always drops the orbs of elites, Looters and Trees", function()
		expect(LootRules.dropsOrb(Types.Shadeling, 20, 0.69)).toBe(true)
		expect(LootRules.dropsOrb(Types.Shadeling, 20, 0.71)).toBe(false)
		expect(LootRules.dropsOrb(EnemyKinds.get("Shadeling", true) :: any, 20, 0.99)).toBe(true)
		expect(LootRules.dropsOrb(Types.Looter, 20, 0.99)).toBe(true)
		expect(LootRules.dropsOrb(Types.Tree, 20, 0.99)).toBe(true)
	end)

	it("lets a new orb take its own value again from the bag", function()
		expect(LootRules.bagPull(0, 4)).toBe(0)
		expect(LootRules.bagPull(10, 4)).toBe(4)
		expect(LootRules.bagPull(3, 4)).toBe(3)
		expect(LootRules.bagPull(10, 0)).toBe(0)
	end)

	it("rolls fruits and crates with Luck, fewer crates the more fell this wave", function()
		local chance = Config.Loot.consumables.chance
		local share = Config.Loot.consumables.crateShare
		expect(LootRules.consumable(Types.Shadeling, 0, 0, chance + 0.001, 0)).toBe(nil)
		expect(LootRules.consumable(Types.Shadeling, 0, 0, chance - 0.001, 0.99)).toBe("Fruit")
		expect(LootRules.consumable(Types.Shadeling, 0, 0, chance - 0.001, share - 0.01)).toBe("Crate")
		expect(LootRules.consumable(Types.Shadeling, 100, 0, chance * 2 - 0.001, 0.99)).toBe("Fruit") -- Luck doubles it
		expect(LootRules.consumable(Types.Shadeling, -100, 0, 0, 0)).toBe(nil) -- -100 Luck: nothing
		-- the second crate of a wave comes half as often
		expect(LootRules.consumable(Types.Shadeling, 0, 1, 0, share / 2 - 0.01)).toBe("Crate")
		expect(LootRules.consumable(Types.Shadeling, 0, 1, 0, share / 2 + 0.01)).toBe("Fruit")
		-- bigger enemies drop more often, elites never (they leave chests)
		expect(LootRules.consumable(Types.Brute, 0, 0, chance + 0.001, 0.99)).toBe("Fruit")
		expect(LootRules.consumable(EnemyKinds.get("Brute", true) :: any, 0, 0, 0, 0)).toBe(nil)
	end)

	it("gives a crate for every Looter and a fruit or crate for every Tree", function()
		expect(LootRules.consumable(Types.Looter, 0, 5, 0.99, 0.99)).toBe("Crate")
		expect(LootRules.consumable(Types.Tree, 0, 0, 0.99, 0.19)).toBe("Crate")
		expect(LootRules.consumable(Types.Tree, 0, 0, 0.99, 0.21)).toBe("Fruit")
		expect(LootRules.consumable(Types.Tree, 0, 1, 0.99, 0.11)).toBe("Fruit") -- 20 % / 2 after a crate
	end)

	it("plans the trees of a wave", function()
		local base = Config.Loot.trees.perWave
		expect(LootRules.treesForWave(0, 0.5)).toBe(base)
		expect(LootRules.treesForWave(2, 0.5)).toBe(base + 2)
		expect(LootRules.treesForWave(0.5, 0.4)).toBe(base + 1)
		expect(LootRules.treesForWave(0.5, 0.6)).toBe(base)
		expect(LootRules.treesForWave(-5, 0)).toBe(0)
		local times = LootRules.treeTimes(2, 40)
		expect(#times).toBe(2)
		expect(times[1]).toBeNear(40 * Config.Loot.trees.spawnShare / 4)
		expect(times[2]).toBeNear(40 * Config.Loot.trees.spawnShare * 3 / 4)
	end)

	it("rolls for Looters at 25 s into a wave and every 15 s after, from wave 3", function()
		local rule = Config.Loot.looter
		expect(LootRules.looterRollsDue(rule.fromWave - 1, 0, 60)).toBe(0)
		expect(LootRules.looterRollsDue(rule.fromWave, 0, rule.firstSeconds - 0.1)).toBe(0)
		expect(LootRules.looterRollsDue(rule.fromWave, rule.firstSeconds - 0.1, rule.firstSeconds)).toBe(1)
		expect(LootRules.looterRollsDue(rule.fromWave, rule.firstSeconds, rule.firstSeconds + 1)).toBe(0)
		expect(LootRules.looterRollsDue(10, 0, 60)).toBe(3) -- 25, 40, 55
		expect(LootRules.looterRollsDue(10, 40, 56)).toBe(1)
	end)

	it("sells a crate's item for a quarter of its price plus Sell Value", function()
		expect(LootRules.sellPrice(40, 0.25, 0)).toBe(10)
		expect(LootRules.sellPrice(41, 0.25, 0)).toBe(10)
		expect(LootRules.sellPrice(40, 0.25, 60)).toBe(34)
		expect(LootRules.sellPrice(40, 0.25, -50)).toBe(0)
	end)
end)
