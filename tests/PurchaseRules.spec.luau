-- Unit tests for Robux purchases (Paket 16): which ids an experience uses, pass and product lookups, remembered
-- PurchaseIds, what a product grants, the Ember Boost's end, Ember bonuses and their results lines
-- (Util/PurchaseRules, Util/ProgressRules.runEmbers, PlayerDataService/ProfileRecords).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = game:GetService("ServerScriptService").Server.Services
local Config = require(ReplicatedStorage.Shared.Config)
local ProgressRules = require(ReplicatedStorage.Shared.Util.ProgressRules)
local PurchaseRules = require(ReplicatedStorage.Shared.Util.PurchaseRules)
local ProfileRecords = require(Services.PlayerDataService.ProfileRecords)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)

local Economy = Config.Economy

local function ids(name, gameId, revive)
	return {
		name = name,
		gameId = gameId,
		passes = { VIP = 11, DoubleEmbers = 12 },
		products = { Revive = revive, Rerolls = 21, Embers1 = 22, Embers2 = 0, Embers3 = 0, ServerBoost = 23 },
	}
end

describe("PurchaseRules ids", function()
	it("picks the experience by gameId, else the one with gameId 0", function()
		local test = ids("Test", 0, 20)
		local live = ids("Live", 777, 30)
		expect(PurchaseRules.resolve(777, { test, live })).toBe(live)
		expect(PurchaseRules.resolve(555, { test, live })).toBe(test)
		expect(PurchaseRules.resolve(0, { test, live })).toBe(test)
		expect(PurchaseRules.resolve(nil, { live })).toBe(nil)
	end)

	it("knows every key, its id and what an id is", function()
		local keys = PurchaseRules.keys()
		expect(#keys).toBe(#Config.Store.passes + #Config.Store.products)
		expect(keys[1]).toBe("VIP")
		local test = ids("Test", 0, 20)
		expect(PurchaseRules.idOf(test, "Revive")).toBe(20)
		expect(PurchaseRules.idOf(test, "VIP")).toBe(11)
		expect(PurchaseRules.isSetUp(test, "Embers2")).toBe(false)
		expect(PurchaseRules.isSetUp(nil, "VIP")).toBe(false)
		expect(PurchaseRules.productKey(test, 23)).toBe("ServerBoost")
		expect(PurchaseRules.productKey(test, 0)).toBe(nil)
		expect(PurchaseRules.productKey(test, 11)).toBe(nil) -- a pass id is no product
		expect(PurchaseRules.passKey(test, 12)).toBe("DoubleEmbers")
		expect(PurchaseRules.passKey(test, 99)).toBe(nil)
	end)

	it("ships with ids that are not set up yet", function()
		local shipped = PurchaseRules.resolve(0, Config.Store.experiences)
		expect(shipped ~= nil).toBe(true)
		for _, key in PurchaseRules.keys() do
			expect(PurchaseRules.idOf(shipped, key) >= 0).toBe(true)
		end
	end)
end)

describe("PurchaseRules receipts and grants", function()
	it("remembers a PurchaseId once and drops the oldest beyond the memory", function()
		local receipts = {}
		expect(PurchaseRules.remember(receipts, "a", 3)).toBe(true)
		expect(PurchaseRules.remember(receipts, "a", 3)).toBe(false)
		PurchaseRules.remember(receipts, "b", 3)
		PurchaseRules.remember(receipts, "c", 3)
		PurchaseRules.remember(receipts, "d", 3)
		expect(#receipts).toBe(3)
		expect(PurchaseRules.knows(receipts, "a")).toBe(false)
		expect(PurchaseRules.knows(receipts, "d")).toBe(true)
	end)

	it("puts Embers and tokens into the saved data", function()
		local data = ProfileTemplate.new()
		PurchaseRules.grant(data, { embers = 1000 })
		PurchaseRules.grant(data, { revives = 1 })
		PurchaseRules.grant(data, { rerolls = 3 })
		expect(data.embers).toBe(1000)
		expect(data.stats.embersBought).toBe(1000)
		expect(data.stats.embersEarned).toBe(0) -- bought Embers are not earned ones (achievements)
		expect(data.tokens.revives).toBe(1)
		expect(data.tokens.rerolls).toBe(3)
		expect(data.stats.purchases).toBe(3)
	end)

	it("makes a running boost longer and starts a new one now", function()
		expect(PurchaseRules.extendBoost(0, 1000, 1800)).toBe(2800)
		expect(PurchaseRules.extendBoost(2000, 1000, 1800)).toBe(3800)
		expect(PurchaseRules.extendBoost(500, 1000, 1800)).toBe(2800)
	end)

	it("counts the VIP reroll and the tokens as bonus rerolls", function()
		expect(PurchaseRules.bonusRerolls(1, { revives = 0, rerolls = 3 })).toBe(4)
		expect(PurchaseRules.bonusRerolls(0, { revives = 2, rerolls = 0 })).toBe(0)
	end)
end)

describe("PurchaseRules Ember bonuses", function()
	it("lists the bonuses of passes and the boost", function()
		local none = PurchaseRules.emberBonuses({}, false)
		expect(#none).toBe(0)
		local all = PurchaseRules.emberBonuses({ VIP = true, DoubleEmbers = true }, true)
		expect(#all).toBe(3)
		expect(all[1].label).toBe("Double Embers")
		expect(all[1].share).toBe(Economy.bonuses.doubleEmbersMultiplier - 1)
		expect(all[2].share).toBe(Economy.bonuses.vip)
		expect(all[3].share).toBe(Economy.serverBoost.bonus)
	end)

	it("adds them as results lines, each from the Embers before them", function()
		local run = { seconds = 600, champions = 0, bosses = 0, danger = 0, players = 1 }
		local base = ProgressRules.runEmbers(run)
		expect(base).toBe(100)
		run.bonuses = PurchaseRules.emberBonuses({ VIP = true, DoubleEmbers = true }, true)
		local total, lines = ProgressRules.runEmbers(run)
		expect(total).toBe(100 + 100 + 10 + 50)
		expect(lines[#lines - 2].label).toBe("Double Embers (+100%)")
		expect(lines[#lines - 1].label).toBe("VIP (+10%)")
		expect(lines[#lines].label).toBe("Ember Boost (+50%)")
		expect(lines[#lines].amount).toBe(50)
	end)

	it("pays the bonuses into the saved data with the run", function()
		local data = ProfileTemplate.new()
		local rewards = ProfileRecords.applyRun(data, {
			won = false,
			wave = 5,
			danger = 0,
			classId = "SparkMage",
			kills = 10,
			bossKills = 0,
			seconds = 300,
			bonuses = PurchaseRules.emberBonuses({ DoubleEmbers = true }, false),
		})
		expect(rewards.lines[#rewards.lines].label).toBe("Double Embers (+100%)")
		expect(data.embers >= 100).toBe(true) -- 50 for 5 min, doubled, plus achievement Embers
		expect(data.stats.embersEarned).toBe(data.embers)
	end)
end)
