--!strict
-- Daily quests and the login streak (Paket 18, DESIGN.md section 11). On the first login of each UTC day (and when a
-- new day starts while the player is in the server) the player gets new quests (Util/QuestRules.roll) and the next
-- login streak day pays its reward (Embers, or the day-7 cosmetic). Every recorded run counts towards the quests; a
-- quest pays its Embers once when it is done (a line in the run's rewards and a Notify). One quest per day can be
-- swapped (remote SwapQuest). Sends QuestState to its player. Hooks into PlayerDataService (Loaded, onRunRecorded) and
-- RunDirector.SyncRequested; AdminService's "NextDay" moves this server's clock a day ahead (nextDay).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local EmberShopRules = require(Shared.Util.EmberShopRules)
local Net = require(Shared.Net)
local QuestRules = require(Shared.Util.QuestRules)
local Types = require(Shared.Net.Types)

local AnalyticsService = require(script.Parent.AnalyticsService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RunDirector = require(script.Parent.RunDirector)

local LOG_PREFIX = "[Lanternfall] "

local Quests = Config.Quests
local Texts = Config.Quests.texts

local QuestService = {}

local clock: () -> number = os.time
local dayOffset = 0 -- debug "NextDay": days this server is ahead

local function now(): number
	return clock() + dayOffset * 86400
end

local function notify(player: Player, text: string)
	Net.fireClient("Notify", player, text)
end

-- The characters the player can play, sorted (quests "with {class}" pick one).
local function classesOf(player: Player): { string }
	local list = {}
	for classId, class in Config.Classes do
		if class.available and PlayerDataService.ownsClass(player, classId) then
			table.insert(list, classId)
		end
	end
	table.sort(list)
	return list
end

local function addEmbers(data: any, amount: number)
	data.embers += amount
	data.stats.embersEarned += amount
end

local function stateOf(data: any): Types.QuestState
	local quests = {}
	for _, quest in data.quests.list do
		table.insert(quests, {
			id = quest.id,
			text = QuestRules.text(quest),
			goal = quest.goal,
			progress = quest.progress,
			embers = quest.embers,
			done = quest.done,
		})
	end
	local at = now()
	return {
		quests = quests,
		swapsLeft = math.max(0, Quests.swapsPerDay - data.quests.swaps),
		streakDay = data.streak.count,
		resetsIn = QuestRules.secondsToNextDay(at),
		sentAt = workspace:GetServerTimeNow(),
	}
end

local function send(player: Player)
	local data = PlayerDataService.get(player)
	if data then
		Net.fireClient("QuestState", player, stateOf(data))
	end
end

-- Pays the login streak day of `today` if it is not paid yet. Returns whether it paid.
local function payStreak(player: Player, data: any, today: number): boolean
	local streakDay = QuestRules.streakDay(data.streak, today)
	if not streakDay then
		return false
	end
	data.streak = { lastLogin = today, count = streakDay }
	local embers, cosmetic = QuestRules.streakReward(streakDay, data.cosmetics.owned)
	local reward
	if cosmetic then
		table.insert(data.cosmetics.owned, cosmetic)
		local entry = EmberShopRules.cosmetic(cosmetic)
		reward = if entry then `{entry.name} ({string.lower(entry.slot)}, wear it in the Ember shop)` else cosmetic
	else
		addEmbers(data, embers)
		AnalyticsService.embersEarned(player, "LoginStreak", embers, `Day{streakDay}`)
		reward = `+{embers} Embers`
	end
	print(`{LOG_PREFIX}{player.Name} login streak day {streakDay}: {reward}`)
	notify(player, `{Texts.streakDay}{streakDay}: {reward}`)
	return true
end

-- Starts the new day for the player if it has not started yet: new quests and the login streak. Returns whether
-- anything changed (does not send).
local function rollover(player: Player, data: any): boolean
	local today = QuestRules.day(now())
	local changed = false
	if data.quests.day ~= tostring(today) then
		data.quests =
			{ day = tostring(today), list = QuestRules.roll(player.UserId, today, classesOf(player)), swaps = 0 }
		changed = true
	end
	if payStreak(player, data, today) then
		changed = true
	end
	return changed
end

-- Checks the day for a loaded player and sends what changed (lobby record for streak Embers, quests).
local function check(player: Player, force: boolean?)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	if rollover(player, data) then
		PlayerDataService.refresh(player)
		send(player)
	elseif force then
		send(player)
	end
end

local function onRunRecorded(player: Player, data: any, run: any, rewards: Types.RunRewards)
	rollover(player, data)
	local finished = QuestRules.applyRun(data.quests.list, {
		kills = run.kills,
		seconds = run.seconds,
		revives = run.revives or 0,
		champions = run.champions or 0,
		wave = run.wave,
		won = run.won,
		players = run.players or 1,
		classId = run.classId,
	})
	for _, quest in finished do
		local text = QuestRules.text(quest)
		addEmbers(data, quest.embers)
		AnalyticsService.embersEarned(player, "Quest", quest.embers, quest.id)
		rewards.embers += quest.embers
		table.insert(rewards.lines, { label = `Quest: {text}`, amount = quest.embers })
		notify(player, `{Texts.questDone}{text} +{quest.embers} Embers`)
	end
	send(player)
end

local function swap(player: Player, index: number)
	local data = PlayerDataService.get(player)
	if not data then
		notify(player, Texts.notLoaded)
		return
	end
	rollover(player, data)
	local quest = data.quests.list[index]
	if not quest then
		return
	elseif quest.done then
		notify(player, Texts.swapDone)
		return
	elseif data.quests.swaps >= Quests.swapsPerDay then
		notify(player, Texts.swapUsed)
		return
	end
	local today = QuestRules.day(now())
	if QuestRules.swap(data.quests.list, index, player.UserId, today, data.quests.swaps + 1, classesOf(player)) then
		data.quests.swaps += 1
	end
	send(player)
end

function QuestService.init()
	PlayerDataService.Loaded:Connect(function(player)
		check(player, true)
	end)
	PlayerDataService.onRunRecorded(onRunRecorded)
	RunDirector.SyncRequested:Connect(send)
	Net.onServer("SwapQuest", swap)
	for _, player in Players:GetPlayers() do -- loaded before this service connected
		check(player, true)
	end
end

-- A new UTC day can start while players are in the server.
function QuestService.start()
	while true do
		task.wait(Quests.checkSeconds)
		for _, player in Players:GetPlayers() do
			check(player)
		end
	end
end

-- Debug button: this server acts one more day ahead (new quests and the next streak day for everyone in it).
function QuestService.nextDay()
	dayOffset += 1
	for _, player in Players:GetPlayers() do
		check(player)
	end
end

-- The player's quest state as sent to the client (tests); nil if not loaded.
function QuestService.getState(player: Player): Types.QuestState?
	local data = PlayerDataService.get(player)
	return if data then stateOf(data) else nil
end

-- Tests: the unix time source (os.time by default).
function QuestService.useClock(custom: () -> number)
	clock = custom
end

return QuestService
