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
		local share = Types.Shadeling.loot.crateShare
		expect(LootRules.consumable(Types.Shadeling, 0, 0, chance + 0.001, 0)).toBe(nil)
		expect(LootRules.consumable(Types.Shadeling, 0, 0, chance - 0.001, 0.99)).toBe("Fruit")
		expect(LootRules.consumable(Types.Shadeling, 0, 0, chance - 0.001, share - 0.001)).toBe("Crate")
		expect(LootRules.consumable(Types.Shadeling, 100, 0, chance * 2 - 0.001, 0.99)).toBe("Fruit") -- Luck doubles it
		expect(LootRules.consumable(Types.Shadeling, -100, 0, 0, 0)).toBe(nil) -- -100 Luck: nothing
		-- the second crate of a wave comes half as often
		expect(LootRules.consumable(Types.Shadeling, 0, 1, 0, share / 2 - 0.001)).toBe("Crate")
		expect(LootRules.consumable(Types.Shadeling, 0, 1, 0, share / 2 + 0.001)).toBe("Fruit")
		-- bigger enemies drop more often, elites never (they leave chests)
		expect(LootRules.consumable(Types.Brute, 0, 0, chance + 0.001, 0.99)).toBe("Fruit")
		expect(LootRules.consumable(EnemyKinds.get("Brute", true) :: any, 0, 0, 0, 0)).toBe(nil)
	end)

	it("gives a crate for every Looter and a fruit or crate for every Tree", function()
		expect(LootRules.consumable(Types.Looter, -100, 5, 0.99, 0.99)).toBe("Crate")
		expect(LootRules.consumable(Types.Looter, 0, 5, 0.99, 0.99)).toBe("Crate")
		expect(LootRules.consumable(Types.Tree, 0, 0, 0.99, 0.19)).toBe("Crate")
		expect(LootRules.consumable(Types.Tree, 0, 0, 0.99, 0.21)).toBe("Fruit")
		expect(LootRules.consumable(Types.Tree, 0, 1, 0.99, 0.11)).toBe("Fruit") -- 20 % / 2 after a crate
	end)

	it("keeps main's crate bonus and endless-consumable rules active after integration", function()
		-- A guaranteed tree consumable falls to 50% at endless factor one.
		expect(LootRules.consumable(Types.Tree, 0, 0, 0.75, 0, 0, 1)).toBe(nil)
		-- Trees have a 20% crate share; +100% crate chance changes a .3 roll from Fruit to Crate.
		expect(LootRules.consumable(Types.Tree, 0, 0, 0, 0.3, 0, 0)).toBe("Fruit")
		expect(LootRules.consumable(Types.Tree, 0, 0, 0, 0.3, 100, 0)).toBe("Crate")
	end)

	it("sells a crate's item for a quarter of its price plus Sell Value", function()
		expect(LootRules.sellPrice(40, 0.25, 0)).toBe(10)
		expect(LootRules.sellPrice(41, 0.25, 0)).toBe(10)
		expect(LootRules.sellPrice(40, 0.25, 60)).toBe(34)
		expect(LootRules.sellPrice(40, 0.25, -50)).toBe(0)
	end)
end)
