-- Unit tests for level-up cards (UpgradeService/UpgradePool: DESIGN.md section 9), passive bonuses and the card
-- texts (Util/UpgradeText).

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local UpgradeText = require(Shared.Util.UpgradeText)
local UpgradePool = require(game:GetService("ServerScriptService").Server.Services.UpgradeService.UpgradePool)

local WEAPONS = { "OrbitBlades", "Shockwave", "SparkBolt" }
local PASSIVES = { "Armor", "Focus", "Haste", "Magnet", "Might", "Vitality" }

local function sequence(values)
	local index = 0
	return function()
		index = index % #values + 1
		return values[index]
	end
end

local function params(overrides)
	local p = {
		weapons = WEAPONS,
		passives = PASSIVES,
		ownedWeapons = { SparkBolt = 1 },
		ownedPassives = {},
		maxWeapons = 4,
		maxPassives = 4,
		maxLevel = 5,
		cardCount = 3,
		ownedWeight = 2,
		rewards = { "Heal", "Embers" },
		random = sequence({ 0.1, 0.5, 0.9, 0.3, 0.7 }),
	}
	for key, value in overrides or {} do
		p[key] = value
	end
	return p
end

local function ids(cards)
	local list = {}
	for _, card in cards do
		table.insert(list, card.id)
	end
	return table.concat(list, ",")
end

describe("UpgradePool", function()
	it("deals three different cards", function()
		for seed = 1, 20 do
			math.randomseed(seed)
			local cards = UpgradePool.roll(params({ random = math.random }))
			expect(#cards).toBe(3)
			local seen = {}
			for _, card in cards do
				expect(seen[card.id]).toBe(nil)
				seen[card.id] = true
				expect(card.kind ~= "Reward").toBe(true)
			end
		end
	end)

	it("offers owned items as upgrades to the next level and new ones at level 1", function()
		local cards = UpgradePool.roll(params({
			weapons = { "SparkBolt" },
			passives = { "Might" },
			ownedWeapons = { SparkBolt = 2 },
			cardCount = 2,
		}))
		local byId = {}
		for _, card in cards do
			byId[card.id] = card
		end
		expect(byId["Weapon:SparkBolt"].level).toBe(3)
		expect(byId["Weapon:SparkBolt"].isNew).toBe(false)
		expect(byId["Passive:Might"].level).toBe(1)
		expect(byId["Passive:Might"].isNew).toBe(true)
	end)

	it("makes owned items about twice as likely", function()
		-- one owned weapon (weight 2) against one new passive (weight 1), one card per roll
		math.randomseed(7)
		local owned = 0
		local rolls = 3000
		for _ = 1, rolls do
			local cards = UpgradePool.roll(params({
				weapons = { "SparkBolt" },
				passives = { "Might" },
				cardCount = 1,
				random = math.random,
			}))
			if cards[1].id == "Weapon:SparkBolt" then
				owned += 1
			end
		end
		expect(owned / rolls).toBeNear(2 / 3, 0.04)
	end)

	it("only offers upgrades once the slots are full", function()
		local cards = UpgradePool.roll(params({
			ownedWeapons = { SparkBolt = 1, OrbitBlades = 1 },
			ownedPassives = { Might = 1, Armor = 1 },
			maxWeapons = 2,
			maxPassives = 2,
		}))
		expect(#cards).toBe(3)
		for _, card in cards do
			expect(card.isNew).toBe(false)
		end
	end)

	it("fills up with rewards when almost everything is maxed", function()
		local cards = UpgradePool.roll(params({
			ownedWeapons = { SparkBolt = 5, OrbitBlades = 4 },
			ownedPassives = { Might = 5 },
			maxWeapons = 2,
			maxPassives = 1,
		}))
		expect(ids(cards)).toBe("Weapon:OrbitBlades,Reward:Heal,Reward:Embers")
		local maxed = UpgradePool.roll(params({
			ownedWeapons = { SparkBolt = 5 },
			maxWeapons = 1,
			maxPassives = 0,
		}))
		expect(ids(maxed)).toBe("Reward:Heal,Reward:Embers")
	end)

	it("deals other cards on a reroll while there are enough", function()
		local first = UpgradePool.roll(params())
		local avoid = {}
		for _, card in first do
			avoid[card.id] = true
		end
		local second = UpgradePool.roll(params({ avoid = avoid }))
		expect(#second).toBe(3)
		for _, card in second do
			expect(avoid[card.id]).toBe(nil)
		end
		-- with only three items left, the reroll deals the same three
		local few = params({ weapons = { "SparkBolt" }, passives = { "Might", "Armor" } })
		local again = UpgradePool.roll(few)
		local avoidAll = {}
		for _, card in again do
			avoidAll[card.id] = true
		end
		few.avoid = avoidAll
		expect(#UpgradePool.roll(few)).toBe(3)
	end)

	it("sums passive bonuses by stat", function()
		local bonuses = UpgradePool.passiveBonuses({ Might = 2, Armor = 3, Focus = 1, Vitality = 1 })
		expect(bonuses.damage).toBeNear(0.2)
		expect(bonuses.armor).toBe(3)
		expect(bonuses.cooldown).toBeNear(-0.08)
		expect(bonuses.maxHp).toBeNear(0.15)
		expect(bonuses.moveSpeed).toBe(nil)
	end)
end)

describe("UpgradeText", function()
	local function card(kind, itemId, level, isNew)
		return { id = `{kind}:{itemId}`, kind = kind, itemId = itemId, level = level, isNew = isNew }
	end

	it("describes new and upgraded weapons", function()
		local title, detail, badge = UpgradeText.describe(card("Weapon", "SparkBolt", 1, true))
		expect(title).toBe("Spark Bolt")
		expect(detail).toBe(Config.Weapons.SparkBolt.description)
		expect(badge).toBe("NEW")
		_, detail, badge = UpgradeText.describe(card("Weapon", "SparkBolt", 2, false))
		expect(detail).toBe("+1 bolt")
		expect(badge).toBe("LV 2")
		_, detail = UpgradeText.describe(card("Weapon", "OrbitBlades", 4, false))
		expect(detail).toBe("+15% damage")
		_, detail = UpgradeText.describe(card("Weapon", "Shockwave", 3, false))
		expect(detail).toBe("+2 radius, -0.3s cooldown")
	end)

	it("describes passives and rewards", function()
		local title, detail, badge = UpgradeText.describe(card("Passive", "Magnet", 2, false))
		expect(title).toBe("Magnet")
		expect(detail).toBe("+30% pickup radius")
		expect(badge).toBe("LV 2")
		title, detail, badge = UpgradeText.describe(card("Reward", "Heal", 1, false))
		expect(title).toBe("Heal")
		expect(detail).toBe("Heal 30% of your HP")
		expect(badge).toBe("")
		_, detail = UpgradeText.describe(card("Reward", "Embers", 1, false))
		expect(detail).toBe("+25 Embers")
	end)
end)
