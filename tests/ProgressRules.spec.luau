-- Unit tests for progress and unlocks (Paket 13): achievement progress, locks, danger per character, the Embers of a
-- run (Util/ProgressRules), the v2 -> v3 migration and what a run pays (PlayerDataService/ProfileRecords), and that
-- the shop and crates never pick locked weapons or items (ShopService/ShopRules).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = game:GetService("ServerScriptService").Server.Services
local Config = require(ReplicatedStorage.Shared.Config)
local ProgressRules = require(ReplicatedStorage.Shared.Util.ProgressRules)
local Migrations = require(Services.PlayerDataService.Migrations)
local ProfileRecords = require(Services.PlayerDataService.ProfileRecords)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)
local ShopRules = require(Services.ShopService.ShopRules)

local function record(stats, characterStats)
	local data = ProfileTemplate.new()
	for key, value in stats or {} do
		data.stats[key] = value
	end
	data.characterStats = characterStats or {}
	return data
end

local function run(overrides)
	local entry = {
		won = false,
		wave = 7,
		danger = 0,
		classId = "BladeWarden",
		kills = 120,
		bossKills = 0,
		seconds = 300,
		champions = 0,
		revives = 0,
		players = 1,
	}
	for key, value in overrides or {} do
		entry[key] = value
	end
	return entry
end

local function seeded(seed)
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

describe("progress rules", function()
	it("counts achievement progress up to the goal", function()
		local deep = ProgressRules.get("DeepNight")
		local current, goal = ProgressRules.progress(deep, record({ bestWave = 6 }))
		expect(current).toBe(6)
		expect(goal).toBe(10)
		current = ProgressRules.progress(deep, record({ bestWave = 14 }))
		expect(current).toBe(10)
		local danger = ProgressRules.get("Danger1")
		expect((ProgressRules.progress(danger, record({ bestDanger = -1 })))).toBe(0)
		local win = ProgressRules.get("WinNightWatch")
		expect(ProgressRules.isComplete(win, record())).toBe(false)
		expect(ProgressRules.isComplete(win, record({}, { NightWatch = { wins = 1, bestDanger = 0 } }))).toBe(true)
		expect(ProgressRules.text(win)).toBe("Win a run with Night Watch")
	end)

	it("lists newly done achievements once", function()
		local data = record({ runs = 1, bestWave = 10 })
		local ids = ProgressRules.newlyDone(data, {})
		expect(table.find(ids, "FirstNight") ~= nil).toBe(true)
		expect(table.find(ids, "DeepNight") ~= nil).toBe(true)
		expect(#ProgressRules.newlyDone(data, { FirstNight = true, DeepNight = true })).toBe(0)
	end)

	it("locks what an achievement unlocks until it is done or bought", function()
		expect(ProgressRules.isUnlocked("characters", "BladeWarden", {})).toBe(true)
		expect(ProgressRules.isUnlocked("characters", "ManyHands", {})).toBe(false)
		expect(ProgressRules.isUnlocked("characters", "ManyHands", { DeepNight = true })).toBe(true)
		expect(ProgressRules.isUnlocked("characters", "ManyHands", {}, { "ManyHands" })).toBe(true)
		expect(ProgressRules.requirement("characters", "ManyHands")).toBe("Reach wave 10")
		local items = ProgressRules.lockedSet("items", {})
		expect(items.LanternCodex).toBe(true)
		expect(items.Vitality).toBe(nil)
		expect(ProgressRules.lockedSet("items", { Dawn = true }).LanternCodex).toBe(nil)
		expect(ProgressRules.lockedSet("weapons", {}).DuskSabre).toBe(true)
	end)

	it("opens danger levels per character, one above the highest won", function()
		expect(ProgressRules.maxDanger(record(), "BladeWarden")).toBe(0)
		local data = record({}, { BladeWarden = { wins = 1, bestDanger = 2 } })
		expect(ProgressRules.maxDanger(data, "BladeWarden")).toBe(3)
		expect(ProgressRules.maxDanger(data, "SparkMage")).toBe(0)
		data.characterStats.BladeWarden.bestDanger = 5
		expect(ProgressRules.maxDanger(data, "BladeWarden")).toBe(5)
	end)

	it("pays Embers per minute, champion and boss with danger and party bonus", function()
		local total, lines =
			ProgressRules.runEmbers({ seconds = 359, champions = 0, bosses = 0, danger = 0, players = 1 })
		expect(total).toBe(50)
		expect(#lines).toBe(1)
		total = ProgressRules.runEmbers({ seconds = 600, champions = 2, bosses = 1, danger = 0, players = 1 })
		expect(total).toBe(100 + 30 + 150)
		total, lines = ProgressRules.runEmbers({ seconds = 600, champions = 0, bosses = 0, danger = 2, players = 2 })
		-- 100, danger 2 = +20 %, party +10 % of 120
		expect(total).toBe(132)
		expect(lines[2].label).toBe("Danger 2")
		expect(lines[3].label).toBe("Party bonus")
	end)
end)

describe("saved progress", function()
	it("upgrades v2 data to v3", function()
		local data = ProfileTemplate.new()
		data.schemaVersion = 2
		data.achievements = nil
		data.stats.championKills = nil
		data.stats.revives = nil
		data.stats.embersEarned = nil
		expect(Migrations.run(data, ProfileTemplate.SCHEMA_VERSION)).toBe(2)
		expect(data.schemaVersion).toBe(3)
		expect(data.stats.championKills).toBe(0)
		expect(data.stats.revives).toBe(0)
		expect(type(data.achievements)).toBe("table")
	end)

	it("pays a run's Embers and completes its achievements once", function()
		local data = ProfileTemplate.new()
		local rewards = ProfileRecords.applyRun(data, run({ seconds = 600, wave = 10 }))
		expect(rewards.lines[1].amount).toBe(100)
		expect(table.find(rewards.achievements, "FirstNight") ~= nil).toBe(true)
		expect(table.find(rewards.achievements, "DeepNight") ~= nil).toBe(true)
		expect(table.find(rewards.unlocked, "Many Hands") ~= nil).toBe(true)
		expect(rewards.embers).toBe(100 + 50 + 100)
		expect(data.embers).toBe(250)
		expect(data.stats.embersEarned).toBe(250)
		expect(rewards.totalEmbers).toBe(250)
		local again = ProfileRecords.applyRun(data, run({ seconds = 60 }))
		expect(#again.achievements).toBe(0)
		expect(again.embers).toBe(10)
	end)

	it("counts champions and revives and wins per character", function()
		local data = ProfileTemplate.new()
		local rewards = ProfileRecords.applyRun(
			data,
			run({ won = true, classId = "NightWatch", champions = 5, revives = 5, danger = 1, wave = 20 })
		)
		expect(data.stats.championKills).toBe(5)
		expect(data.stats.revives).toBe(5)
		for _, id in { "Dawn", "ChampionHunter", "Rescuer", "WinNightWatch", "Danger1" } do
			expect(table.find(rewards.achievements, id) ~= nil).toBe(true)
		end
		local info = ProfileRecords.info(data, "Memory")
		expect(info.characterDanger.NightWatch).toBe(2)
		expect(info.characterDanger.BladeWarden).toBe(0)
		expect(info.achievements.Dawn).toBe(true)
		expect(info.progress.ChampionHunter).toBe(5)
	end)
end)

describe("locked weapons and items", function()
	it("never offers them in the shop", function()
		local unavailable = ProgressRules.lockedSet("weapons", {})
		for itemId in ProgressRules.lockedSet("items", {}) do
			unavailable[itemId] = true
		end
		local weapons = {}
		for weaponId in Config.Shop.weaponPrices do
			table.insert(weapons, weaponId)
		end
		table.sort(weapons)
		local random = seeded(7)
		local counter = 0
		for wave = 1, 20 do
			for _ = 1, 15 do
				local offers = ShopRules.roll({
					wave = wave,
					luck = 200,
					weapons = weapons,
					ownedWeapons = {},
					maxWeapons = 6,
					maxTier = 4,
					ownedItems = {},
					unavailable = unavailable,
					nextId = function()
						counter += 1
						return tostring(counter)
					end,
					random = random,
				})
				for _, offer in offers do
					expect(unavailable[offer.itemId]).toBe(nil)
				end
			end
		end
	end)

	it("never puts a locked item in a crate", function()
		local unavailable = ProgressRules.lockedSet("items", {})
		local random = seeded(11)
		for _ = 1, 200 do
			local itemId = ShopRules.chestItem(20, 500, {}, random, unavailable)
			expect(itemId ~= nil).toBe(true)
			expect(unavailable[itemId]).toBe(nil)
		end
	end)
end)
