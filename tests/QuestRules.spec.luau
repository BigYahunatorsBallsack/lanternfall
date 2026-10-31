-- Unit tests for the Paket 18 rules: daily quests and the login streak (Util/QuestRules), weekly leaderboards
-- (Util/LeaderboardRules), Format.duration, login-streak cosmetics in the Ember shop rules and the v5 -> v6 migration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local EmberShopRules = require(ReplicatedStorage.Shared.Util.EmberShopRules)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local LeaderboardRules = require(ReplicatedStorage.Shared.Util.LeaderboardRules)
local QuestRules = require(ReplicatedStorage.Shared.Util.QuestRules)
local Services = game:GetService("ServerScriptService").Server.Services
local Migrations = require(Services.PlayerDataService.Migrations)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)

local CLASSES = { "BladeWarden", "SparkMage" }
local DAY = 20454 -- 2026-01-01

local function run(values)
	local base = {
		kills = 0,
		seconds = 0,
		revives = 0,
		champions = 0,
		wave = 1,
		won = false,
		players = 1,
		classId = "BladeWarden",
	}
	for key, value in values or {} do
		base[key] = value
	end
	return base
end

local function quest(id, goal, classId)
	return { id = id, goal = goal, embers = 50, classId = classId, progress = 0, done = false }
end

describe("daily quests", function()
	it("counts UTC days and the time to the next one", function()
		expect(QuestRules.day(0)).toBe(0)
		expect(QuestRules.day(86399)).toBe(0)
		expect(QuestRules.day(86400)).toBe(1)
		expect(QuestRules.secondsToNextDay(DAY * 86400 + 3600)).toBe(82800)
	end)

	it("gives each player the same different quests for a day", function()
		local list = QuestRules.roll(42, DAY, CLASSES)
		expect(#list).toBe(Config.Quests.daily)
		local seen = {}
		for _, entry in list do
			expect(seen[entry.id]).toBe(nil)
			seen[entry.id] = true
			local template = QuestRules.template(entry.id)
			local tierFound = false
			for _, tier in template.tiers do
				tierFound = tierFound or (tier.goal == entry.goal and tier.embers == entry.embers)
			end
			expect(tierFound).toBe(true)
			expect(entry.progress).toBe(0)
			expect(entry.done).toBe(false)
			if template.withClass then
				expect(table.find(CLASSES, entry.classId) ~= nil).toBe(true)
			else
				expect(entry.classId).toBe(nil)
			end
		end
		local again = QuestRules.roll(42, DAY, CLASSES)
		for index, entry in list do
			expect(again[index].id).toBe(entry.id)
			expect(again[index].goal).toBe(entry.goal)
		end
	end)

	it("changes the quests with the day and the player", function()
		local function ids(list)
			local names = {}
			for _, entry in list do
				table.insert(names, `{entry.id}{entry.goal}{entry.classId or ""}`)
			end
			return table.concat(names, ",")
		end
		local first = ids(QuestRules.roll(42, DAY, CLASSES))
		local differentDays, differentPlayers = 0, 0
		for offset = 1, 10 do
			if ids(QuestRules.roll(42, DAY + offset, CLASSES)) ~= first then
				differentDays += 1
			end
			if ids(QuestRules.roll(42 + offset, DAY, CLASSES)) ~= first then
				differentPlayers += 1
			end
		end
		expect(differentDays >= 8).toBe(true)
		expect(differentPlayers >= 8).toBe(true)
	end)

	it("never picks a character quest without characters", function()
		for day = DAY, DAY + 30 do
			for _, entry in QuestRules.roll(7, day, {}) do
				expect(QuestRules.template(entry.id).withClass).toBe(nil)
			end
		end
	end)

	it("swaps a quest for one of another kind, never a done one", function()
		local list = QuestRules.roll(42, DAY, CLASSES)
		local before = {}
		for _, entry in list do
			before[entry.id] = true
		end
		local new = QuestRules.swap(list, 2, 42, DAY, 1, CLASSES)
		expect(new ~= nil).toBe(true)
		expect(list[2]).toBe(new)
		expect(before[new.id]).toBe(nil)
		list[1].done = true
		local doneId = list[1].id
		expect(QuestRules.swap(list, 1, 42, DAY, 2, CLASSES)).toBe(nil)
		expect(list[1].id).toBe(doneId)
		expect(QuestRules.swap(list, 9, 42, DAY, 2, CLASSES)).toBe(nil)
	end)

	it("adds finished runs and finishes quests", function()
		local list = {
			quest("Kills", 800),
			quest("Wave", 12),
			quest("Survive", 10, "SparkMage"),
			quest("Party", 2),
		}
		local finished = QuestRules.applyRun(list, run({ kills = 500, wave = 8, seconds = 400, players = 2 }))
		expect(#finished).toBe(0)
		expect(list[1].progress).toBe(500)
		expect(list[2].progress).toBe(8)
		expect(list[3].progress).toBe(0) -- played Blade Warden
		expect(list[4].progress).toBe(1)
		-- the wave quest takes the best run, not the sum; progress stops at the goal
		finished =
			QuestRules.applyRun(list, run({ kills = 900, wave = 9, seconds = 660, classId = "SparkMage", players = 2 }))
		expect(list[1].progress).toBe(800)
		expect(list[2].progress).toBe(9)
		expect(list[3].progress).toBe(10)
		expect(#finished).toBe(3)
		expect(list[1].done and list[3].done and list[4].done).toBe(true)
		expect(list[2].done).toBe(false)
		-- done quests do not count again
		expect(#QuestRules.applyRun(list, run({ kills = 900, wave = 12 }))).toBe(1)
		expect(list[1].progress).toBe(800)
	end)

	it("counts revives, champions, runs and wins", function()
		local values = QuestRules.runValues(run({ revives = 2, champions = 1, won = true, players = 1, seconds = 59 }))
		expect(values.revives).toBe(2)
		expect(values.champions).toBe(1)
		expect(values.runs).toBe(1)
		expect(values.wins).toBe(1)
		expect(values.partyRuns).toBe(0)
		expect(values.minutes).toBe(0)
	end)

	it("writes what to do", function()
		expect(QuestRules.text(quest("Kills", 800))).toBe("Kill 800 enemies")
		expect(QuestRules.text(quest("Survive", 10, "SparkMage"))).toBe("Survive 10 minutes with Spark Mage")
		expect(QuestRules.text(quest("Win", 1))).toBe("Win a run")
	end)
end)

describe("login streak", function()
	local DAYS = #Config.Quests.streak.days
	local PENALTY = Config.Quests.streak.missedPenalty

	it("starts at day 1 and pays once per day", function()
		expect(QuestRules.streakDay({ lastLogin = 0, count = 0 }, DAY)).toBe(1)
		expect(QuestRules.streakDay({ lastLogin = DAY, count = 3 }, DAY)).toBe(nil)
	end)

	it("goes up on consecutive days and starts over after the last day", function()
		expect(QuestRules.streakDay({ lastLogin = DAY - 1, count = 3 }, DAY)).toBe(4)
		expect(QuestRules.streakDay({ lastLogin = DAY - 1, count = DAYS }, DAY)).toBe(1)
	end)

	it("only goes back a few days after a missed day", function()
		expect(QuestRules.streakDay({ lastLogin = DAY - 2, count = 5 }, DAY)).toBe(6 - PENALTY)
		expect(QuestRules.streakDay({ lastLogin = DAY - 30, count = 5 }, DAY)).toBe(6 - PENALTY)
		expect(QuestRules.streakDay({ lastLogin = DAY - 2, count = 1 }, DAY)).toBe(1)
		expect(QuestRules.streakDay({ lastLogin = DAY - 2, count = DAYS }, DAY)).toBe(1)
	end)

	it("pays Embers, and the cosmetic on the last day until it is owned", function()
		expect(QuestRules.streakReward(1, {})).toBe(Config.Quests.streak.days[1].embers)
		local last = Config.Quests.streak.days[DAYS]
		local embers, cosmetic = QuestRules.streakReward(DAYS, {})
		expect(embers).toBe(0)
		expect(cosmetic).toBe(last.cosmetic)
		embers, cosmetic = QuestRules.streakReward(DAYS, { last.cosmetic })
		expect(embers).toBe(last.embers)
		expect(cosmetic).toBe(nil)
	end)

	it("keeps the streak cosmetic out of the Ember shop", function()
		local id = Config.Quests.streak.days[DAYS].cosmetic
		local entry = EmberShopRules.cosmetic(id)
		expect(entry.reward).toBe("Streak")
		expect(EmberShopRules.ownsCosmetic(id, {}, true)).toBe(false)
		expect(EmberShopRules.ownsCosmetic(id, { id }, false)).toBe(true)
		local wallet = { embers = 100000, achievements = {}, classes = {}, cosmetics = { owned = {}, equipped = {} } }
		local price, reason = EmberShopRules.buy("Cosmetic", id, wallet, false)
		expect(price).toBe(nil)
		expect(reason).toBe("rewardOnly")
		expect(EmberShopRules.canEquip(entry.slot, id, {}, false)).toBe(false)
		expect(EmberShopRules.canEquip(entry.slot, id, { id }, false)).toBe(true)
	end)
end)

describe("leaderboard rules", function()
	it("starts weeks on Monday 00:00 UTC", function()
		local monday = 1799020800 -- 2027-01-04 00:00 UTC, a Monday
		expect(LeaderboardRules.week(monday)).toBe(LeaderboardRules.week(monday - 1) + 1)
		expect(LeaderboardRules.week(monday + 7 * 86400 - 1)).toBe(LeaderboardRules.week(monday))
		expect(LeaderboardRules.secondsToNextWeek(monday)).toBe(7 * 86400)
		expect(LeaderboardRules.secondsToNextWeek(monday - 60)).toBe(60)
	end)

	it("sorts the wave board by wave, then kills", function()
		local better = LeaderboardRules.score("Wave", 12, 10)
		local worse = LeaderboardRules.score("Wave", 11, 99999)
		expect(better > worse).toBe(true)
		expect(LeaderboardRules.score("Wave", 12, 11) > better).toBe(true)
		local wave, kills = LeaderboardRules.read("Wave", better)
		expect(wave).toBe(12)
		expect(kills).toBe(10)
		expect(LeaderboardRules.text("Wave", better)).toBe("Wave 12 · 10 kills")
		expect(LeaderboardRules.score("Kills", 12, 3412)).toBe(3412)
		expect(LeaderboardRules.text("Kills", 3412)).toBe("3412 kills")
	end)

	it("names stores per board, danger level and week", function()
		expect(LeaderboardRules.storeName("Wave", 3, 2912)).toBe(`{Config.Leaderboards.storePrefix}Wave_D3_W2912`)
		expect(LeaderboardRules.bestKey("Kills", 0)).toBe("Kills_D0")
		expect(#LeaderboardRules.boardKeys()).toBe(#Config.Leaderboards.boards)
	end)

	it("writes long waits in two units", function()
		expect(Format.duration(90061)).toBe("1d 1h")
		expect(Format.duration(18720)).toBe("5h 12m")
		expect(Format.duration(59)).toBe("0m")
		expect(Format.duration(-5)).toBe("0m")
	end)
end)

describe("schema v6", function()
	it("adds badges and weekly bests and starts quests and the streak fresh", function()
		local data = ProfileTemplate.new()
		data.schemaVersion = 5
		data.badges = nil
		data.weekly = nil
		data.quests = { day = "", list = {} }
		data.streak = { lastLogin = 1700000000, count = 0 }
		expect(Migrations.run(data, ProfileTemplate.SCHEMA_VERSION)).toBe(5)
		expect(data.schemaVersion).toBe(6)
		expect(next(data.badges)).toBe(nil)
		expect(data.weekly.week).toBe(0)
		expect(data.quests.swaps).toBe(0)
		expect(data.streak.lastLogin).toBe(0)
	end)
end)
