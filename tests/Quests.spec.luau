-- End-to-end test of Paket 18: the login streak and daily quests (lobby window, swap, finished runs pay quests and show
-- them on the results), the weekly leaderboards (scores after a run, only better ones, global and friends board in the
-- lobby window) and badges (awarded once when earned). The mock's os.time starts at 2027-01-01 (tests/helpers/
-- RobloxMock), BadgeService and UserService are simulated, leaderboard scores live in memory.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Server.Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local LeaderboardRules = require(ReplicatedStorage.Shared.Util.LeaderboardRules)
local QuestRules = require(ReplicatedStorage.Shared.Util.QuestRules)
local BadgeService = require(Services.BadgeService)
local LeaderboardService = require(Services.LeaderboardService)
local PlayerDataService = require(Services.PlayerDataService)
local QuestService = require(Services.QuestService)
local Scores = require(Services.LeaderboardService.Scores)

local Streak = Config.Quests.streak
local BADGES = { Welcome = 901, FirstNight = 902, Kingslayer = 903, TenThousand = 904, LanternSaint = 905 }

local scores = Scores.memory()
LeaderboardService.useBackend(scores)
BadgeService.useIds(BADGES)
BadgeService.allowStudio(true)

runScript(ServerScriptService.Server, "init.server.luau")

local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.step()
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local LeaderboardController = require(Client.Controllers.LeaderboardController)
local QuestController = require(Client.Controllers.QuestController)

local function hasToast(prefix: string): boolean
	for _, object in world.gui("Notify"):GetDescendants() do
		if object.ClassName == "TextLabel" and string.sub(object.Text, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function record(values)
	local base = {
		won = false,
		wave = 5,
		danger = 0,
		classId = "BladeWarden",
		kills = 100,
		bossKills = 0,
		seconds = 120,
		champions = 0,
		revives = 0,
		players = 1,
	}
	for key, value in values do
		base[key] = value
	end
	return base
end

local function today(): number
	return QuestRules.day(os.time())
end

describe("login streak and daily quests", function()
	it("pays login streak day 1 and sends three quests", function()
		local data = PlayerDataService.get(me)
		expect(data.streak.count).toBe(1)
		expect(data.streak.lastLogin).toBe(today())
		expect(data.embers).toBe(Streak.days[1].embers)
		expect(data.stats.embersEarned).toBe(Streak.days[1].embers)
		local state = QuestController.get()
		expect(#state.quests).toBe(Config.Quests.daily)
		expect(state.swapsLeft).toBe(Config.Quests.swapsPerDay)
		expect(state.streakDay).toBe(1)
		expect(data.quests.day).toBe(tostring(today()))
		expect(world.gui("Lobby", "OpenQuests").Text).toBe(`QUESTS 0/{Config.Quests.daily}`)
		-- the same quests the rules give this player today
		local expected = QuestRules.roll(1, today(), { "BladeWarden", "DuelMaestro", "NightWatch", "SparkMage" })
		for index, quest in state.quests do
			expect(quest.id).toBe(expected[index].id)
		end
	end)

	it("shows the quests window with the streak and swaps a quest once", function()
		world.click(world.gui("Lobby", "OpenQuests"))
		expect(world.gui("Lobby", "Quests").Visible).toBe(true)
		local first = QuestController.get().quests[1]
		local text = world.gui("Lobby", "Quest_1"):FindFirstChild("Text").Text
		expect(string.find(text, first.text, 1, true) ~= nil).toBe(true)
		expect(string.find(text, `0/{first.goal} · +{first.embers} Embers`, 1, true) ~= nil).toBe(true)
		expect(world.gui("Lobby", "Day_1").BackgroundColor3).toBe(require(Client.UI.Theme).accent)
		expect(world.gui("Lobby", "Day_7").Text).toBe("DAY 7\nSeventh Vigil")
		expect(string.find(world.gui("Lobby", "QuestReset").Text, "New quests in ", 1, true) ~= nil).toBe(true)

		local old = QuestController.get().quests[2].id
		world.click(world.gui("Lobby", "Quest_2"):FindFirstChild("Swap"))
		world.advance(0.3)
		local state = QuestController.get()
		expect(state.quests[2].id ~= old).toBe(true)
		expect(state.swapsLeft).toBe(0)
		expect(world.gui("Lobby", "Quest_1"):FindFirstChild("Swap")).toBe(nil)
		world.fireServerAs(me, "SwapQuest", 1)
		world.advance(0.3)
		expect(hasToast(Config.Quests.texts.swapUsed)).toBe(true)
		expect(QuestController.get().quests[1].id).toBe(first.id)
		-- other lobby windows close it
		world.click(world.gui("Lobby", "OpenStore"))
		expect(world.gui("Lobby", "Quests").Visible).toBe(false)
		expect(world.gui("Lobby", "Store").Visible).toBe(true)
		world.click(world.gui("Lobby", "OpenQuests"))
		expect(world.gui("Lobby", "Store").Visible).toBe(false)
		world.click(world.gui("Lobby", "CloseQuests"))
	end)

	it("counts a finished run, pays done quests and lists them in the rewards", function()
		local data = PlayerDataService.get(me)
		data.quests.list = {
			{ id = "Kills", goal = 800, embers = 50, progress = 0, done = false },
			{ id = "Runs", goal = 3, embers = 60, progress = 2, done = false },
			{ id = "Wave", goal = 16, embers = 100, progress = 0, done = false },
		}
		local before = data.embers
		local ok, sent = PlayerDataService.recordRun(me, record({ wave = 13, danger = 2, kills = 900, seconds = 610 }))
		world.advance(0.3)
		expect(ok).toBe(true)
		expect(data.quests.list[1].done).toBe(true)
		expect(data.quests.list[2].done).toBe(true)
		expect(data.quests.list[3].done).toBe(false)
		expect(data.quests.list[3].progress).toBe(13)
		local runEmbers = 10 * Config.Economy.embers.perMinuteSurvived
		runEmbers += math.floor(runEmbers * Config.Progress.embers.perDangerLevel * 2)
		local achievements = 50 + 100 -- First Night, Deep Into the Night
		expect(data.embers).toBe(before + runEmbers + achievements + 110)
		expect(sent.embers).toBe(runEmbers + achievements + 110)
		expect(sent.totalEmbers).toBe(data.embers)
		local labels = {}
		for _, line in sent.lines do
			labels[line.label] = line.amount
		end
		expect(labels["Quest: Kill 800 enemies"]).toBe(50)
		expect(labels["Quest: Finish 3 runs"]).toBe(60)
		expect(hasToast("Quest done: Finish 3 runs +60 Embers")).toBe(true)
		expect(world.gui("Lobby", "OpenQuests").Text).toBe("QUESTS 2/3")
		expect(QuestController.get().quests[3].progress).toBe(13)
	end)

	it("starts a new day with new quests and the next streak day", function()
		local data = PlayerDataService.get(me)
		local before = data.embers
		world.fireServerAs(me, "DebugCommand", "NextDay")
		world.advance(0.3)
		local day = today() + 1
		expect(data.quests.day).toBe(tostring(day))
		expect(data.quests.swaps).toBe(0)
		expect(data.streak.count).toBe(2)
		expect(data.streak.lastLogin).toBe(day)
		expect(data.embers).toBe(before + Streak.days[2].embers)
		local state = QuestController.get()
		expect(state.streakDay).toBe(2)
		expect(state.swapsLeft).toBe(Config.Quests.swapsPerDay)
		for _, quest in state.quests do
			expect(quest.done).toBe(false)
		end
		-- the peer got its streak day too
		expect(PlayerDataService.get(peer).streak.count).toBe(2)
	end)

	it("goes back two days after a missed day and gives the lantern on day 7", function()
		local data = PlayerDataService.get(me)
		data.streak = { lastLogin = data.streak.lastLogin - 2, count = 5 } -- day 5 was paid three days ago
		QuestService.nextDay()
		expect(data.streak.count).toBe(6 - Streak.missedPenalty)
		data.streak = { lastLogin = data.streak.lastLogin, count = 6 }
		QuestService.nextDay()
		world.advance(0.3)
		local lantern = Streak.days[7].cosmetic
		expect(data.streak.count).toBe(7)
		expect(table.find(data.cosmetics.owned, lantern) ~= nil).toBe(true)
		expect(hasToast("Login streak day 7: Seventh Vigil")).toBe(true)
		-- the Ember shop lets the player wear it
		world.fireServerAs(me, "EquipCosmetic", "Lantern", lantern)
		world.advance(0.3)
		expect(data.cosmetics.equipped.Lantern).toBe(lantern)
		expect(me.Character:FindFirstChild("LanternfallCosmetics"):GetAttribute("Lantern")).toBe(lantern)
		-- a week later day 7 pays Embers instead
		data.streak = { lastLogin = data.streak.lastLogin, count = 6 }
		local before = data.embers
		QuestService.nextDay()
		expect(data.embers).toBe(before + Streak.days[7].embers)
	end)
end)

describe("leaderboards", function()
	local week = LeaderboardRules.week(os.time())

	it("keeps the run's scores as this week's best", function()
		local data = PlayerDataService.get(me)
		expect(data.weekly.week).toBe(week)
		local wave = LeaderboardRules.score("Wave", 13, 900)
		expect(data.weekly.best.Wave_D2).toBe(wave)
		expect(data.weekly.best.Kills_D2).toBe(900)
		expect(scores.get(LeaderboardRules.storeName("Wave", 2, week), "1")).toBe(wave)
		-- a worse run changes nothing, a better kill count only the kills board
		PlayerDataService.recordRun(me, record({ wave = 9, danger = 2, kills = 1200 }))
		world.advance(0.3)
		expect(data.weekly.best.Wave_D2).toBe(wave)
		expect(data.weekly.best.Kills_D2).toBe(1200)
		expect(scores.get(LeaderboardRules.storeName("Kills", 2, week), "1")).toBe(1200)
	end)

	it("shows the global board with names and the player's best", function()
		PlayerDataService.recordRun(peer, record({ wave = 15, danger = 2, kills = 400 }))
		scores.submit(LeaderboardRules.storeName("Wave", 2, week), "77", LeaderboardRules.score("Wave", 20, 5000))
		world.advance(0.3)
		world.click(world.gui("Lobby", "OpenLeaderboards"))
		expect(world.gui("Lobby", "Leaderboards").Visible).toBe(true)
		world.click(world.gui("Lobby", "Danger_2"))
		world.advance(0.3)
		local page = LeaderboardController.get()
		expect(page.board).toBe("Wave")
		expect(page.danger).toBe(2)
		expect(page.saved).toBe(true)
		expect(#page.entries).toBe(3)
		expect(page.entries[1].name).toBe("User 77") -- not in the server: name from UserService
		expect(page.entries[2].name).toBe("Peer")
		expect(page.entries[3].name).toBe("Owner")
		expect(world.gui("Lobby", "Rank_3").Text).toBe("3.  Owner  ·  Wave 13 · 900 kills")
		expect(world.gui("Lobby", "Rank_3").TextColor3).toBe(require(Client.UI.Theme).accent)
		local info = world.gui("Lobby", "LeaderboardInfo").Text
		expect(string.find(info, "Your best this week: Wave 13 · 900 kills", 1, true) ~= nil).toBe(true)
		expect(string.find(info, "New week in ", 1, true) ~= nil).toBe(true)
		-- the kills board of another danger level is empty
		world.click(world.gui("Lobby", "Board_Kills"))
		world.click(world.gui("Lobby", "Danger_4"))
		world.advance(0.3)
		expect(#LeaderboardController.get().entries).toBe(0)
	end)

	it("shows the friends board with the player and friends who have a score", function()
		world.friends[1] = { 2, 3 }
		world.click(world.gui("Lobby", "Danger_2"))
		world.click(world.gui("Lobby", "Scope_Friends"))
		world.advance(0.3)
		local page = LeaderboardController.get()
		expect(page.scope).toBe("Friends")
		expect(page.board).toBe("Kills")
		expect(#page.entries).toBe(2)
		expect(page.entries[1].name).toBe("Owner")
		expect(page.entries[1].score).toBe(1200)
		expect(page.entries[2].name).toBe("Peer")
		world.click(world.gui("Lobby", "CloseLeaderboards"))
		expect(world.gui("Lobby", "Leaderboards").Visible).toBe(false)
	end)
end)

describe("badges", function()
	it("awards each earned badge once and remembers it", function()
		local data = PlayerDataService.get(me)
		expect(world.badges[`1:{BADGES.Welcome}`]).toBe(true)
		expect(world.badges[`1:{BADGES.FirstNight}`]).toBe(true)
		expect(data.badges.Welcome).toBe(true)
		expect(data.badges.FirstNight).toBe(true)
		expect(world.badges[`1:{BADGES.Kingslayer}`]).toBe(nil)
		expect(data.badges.Kingslayer).toBe(nil)
		PlayerDataService.recordRun(me, record({ bossKills = 1 }))
		world.advance(0.3)
		expect(world.badges[`1:{BADGES.Kingslayer}`]).toBe(true)
		expect(data.badges.Kingslayer).toBe(true)
	end)

	it("tries again later when Roblox fails", function()
		local data = PlayerDataService.get(peer)
		data.badges.FirstNight = nil
		world.badges[`2:{BADGES.FirstNight}`] = nil
		world.badgeError = "HTTP 500"
		PlayerDataService.refresh(peer)
		world.advance(Config.Badges.attempts * 3)
		expect(data.badges.FirstNight).toBe(nil)
		world.badgeError = nil
		PlayerDataService.refresh(peer)
		world.advance(0.3)
		expect(data.badges.FirstNight).toBe(true)
	end)

	it("finished without any runtime error", function()
		if #world.errors > 0 then
			error(table.concat(world.errors, "\n\n"))
		end
	end)
end)
