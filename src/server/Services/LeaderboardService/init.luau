--!strict
-- Weekly leaderboards (Paket 18, DESIGN.md section 11): after each recorded run the server writes the player's score
-- per board (best wave, most kills) for the run's danger level into this week's OrderedDataStore, but only when it
-- beats the player's best of the week (kept in the profile, ProfileTemplate.Data.weekly). The lobby asks for a board
-- (remote RequestLeaderboard) and gets the top entries or the player's friends (remote Leaderboard). Reads are cached
-- per server for Config.Leaderboards.cacheSeconds. Without real saving (tests, Studio without API access) the scores
-- live in this server only (Scores.memory). Hooks into PlayerDataService.onRunRecorded.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local LeaderboardRules = require(Shared.Util.LeaderboardRules)
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)

local PlayerDataService = require(script.Parent.PlayerDataService)
local Scores = require(script.Scores)

local LOG_PREFIX = "[Lanternfall] "

local Leaderboards = Config.Leaderboards

local LeaderboardService = {}

local clock: () -> number = os.time
local custom: Scores.Backend? = nil
local memory = Scores.memory()
local real: Scores.Backend? = nil

type Cached = { at: number, entries: { { userId: number, score: number } }, failed: boolean }
local topCache: { [string]: Cached } = {}
local scoreCache: { [string]: { at: number, score: number } } = {} -- store name .. ":" .. userId
local friendCache: { [number]: { at: number, ids: { number } } } = {}
local names: { [number]: string } = {}

-- Real OrderedDataStores only while the profiles save for real; otherwise this server's memory.
local function backend(): (Scores.Backend, boolean)
	if custom then
		return custom, true
	elseif PlayerDataService.getSaveMode() == "DataStore" then
		if not real then
			real = Scores.dataStore()
		end
		return real :: Scores.Backend, true
	end
	return memory, false
end

local function bestOf(data: any, week: number): { [string]: number }
	if data.weekly.week ~= week then
		data.weekly = { week = week, best = {} }
	end
	return data.weekly.best
end

local function write(storeName: string, userId: number, score: number)
	local store = backend()
	for attempt = 1, 1 + Leaderboards.writeRetries do
		local ok, err = pcall(store.submit, storeName, tostring(userId), score)
		if ok then
			topCache[storeName] = nil
			scoreCache[`{storeName}:{userId}`] = nil
			return
		elseif attempt > Leaderboards.writeRetries then
			warn(`{LOG_PREFIX}Leaderboard score not saved ({storeName}): {err}`)
		else
			task.wait(attempt * 2)
		end
	end
end

local function onRunRecorded(player: Player, data: any, run: any)
	if run.firstNight then
		return -- Paket 19: the First Night is easier and shorter, it does not go on the boards
	elseif run.debug then
		return -- Paket 23: an admin changed the run with debug commands
	end
	local week = LeaderboardRules.week(clock())
	local best = bestOf(data, week)
	for _, board in Leaderboards.boards do
		local score = LeaderboardRules.score(board.key, run.wave, run.kills)
		local key = LeaderboardRules.bestKey(board.key, run.danger)
		if score > 0 and score > (best[key] or 0) then
			best[key] = score
			task.spawn(write, LeaderboardRules.storeName(board.key, run.danger, week), player.UserId, score)
		end
	end
end

-- Display names of user ids (players in the server first, then Roblox in one batch).
local function resolveNames(ids: { number })
	local missing = {}
	for _, userId in ids do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			names[userId] = player.DisplayName
		elseif not names[userId] then
			table.insert(missing, userId)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return game:GetService("UserService"):GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and type(infos) == "table" then
		for _, entry in infos do
			names[entry.Id] = entry.DisplayName
		end
	end
end

local function nameOf(userId: number): string
	return names[userId] or `Player {userId}`
end

local function globalEntries(storeName: string): ({ { userId: number, score: number } }, boolean)
	local cached = topCache[storeName]
	if cached and os.clock() - cached.at < Leaderboards.cacheSeconds then
		return cached.entries, cached.failed
	end
	local store = backend()
	local ok, result = pcall(store.top, storeName, Leaderboards.topSize)
	local entries = {}
	if ok then
		for _, row in result do
			local userId = tonumber(row.key)
			if userId then
				table.insert(entries, { userId = userId, score = row.score })
			end
		end
	else
		warn(`{LOG_PREFIX}Leaderboard not readable ({storeName}): {result}`)
		entries = if cached then cached.entries else {}
	end
	topCache[storeName] = { at = os.clock(), entries = entries, failed = not ok }
	return entries, not ok
end

local function friendIds(player: Player): { number }
	local cached = friendCache[player.UserId]
	if cached and os.clock() - cached.at < Leaderboards.cacheSeconds * 10 then
		return cached.ids
	end
	local ids = {}
	local ok = pcall(function()
		local pages = Players:GetFriendsAsync(player.UserId)
		while #ids < Leaderboards.friendsMax do
			for _, friend in pages:GetCurrentPage() do
				if #ids < Leaderboards.friendsMax then
					table.insert(ids, friend.Id)
				end
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if ok or not cached then
		friendCache[player.UserId] = { at = os.clock(), ids = ids }
	end
	return if ok or not cached then ids else cached.ids
end

local function friendEntries(player: Player, storeName: string): ({ { userId: number, score: number } }, boolean)
	local store = backend()
	local ids = friendIds(player)
	table.insert(ids, 1, player.UserId)
	local entries = {}
	local failed = false
	for _, userId in ids do
		local cacheKey = `{storeName}:{userId}`
		local cached = scoreCache[cacheKey]
		local score: number? = nil
		if cached and os.clock() - cached.at < Leaderboards.cacheSeconds then
			score = cached.score
		elseif store.canRead() then
			local ok, result = pcall(store.get, storeName, tostring(userId))
			if ok then
				score = result or 0
				scoreCache[cacheKey] = { at = os.clock(), score = score :: number }
			else
				failed = true
			end
		else
			failed = true -- read budget used up; the rest comes with the next request
		end
		if score and score > 0 then
			table.insert(entries, { userId = userId, score = score })
		end
	end
	table.sort(entries, function(a, b)
		return if a.score == b.score then a.userId < b.userId else a.score > b.score
	end)
	return entries, failed
end

-- Builds the page a player asked for (yields: DataStore and friends).
function LeaderboardService.page(player: Player, board: string, danger: number, scope: string): Types.LeaderboardPage
	local at = clock()
	local week = LeaderboardRules.week(at)
	local storeName = LeaderboardRules.storeName(board, danger, week)
	local raw, failed
	if scope == "Friends" then
		raw, failed = friendEntries(player, storeName)
	else
		raw, failed = globalEntries(storeName)
	end
	local ids = {}
	for _, row in raw do
		table.insert(ids, row.userId)
	end
	resolveNames(ids)
	local entries = {}
	for index, row in raw do
		table.insert(entries, { rank = index, userId = row.userId, name = nameOf(row.userId), score = row.score })
	end
	local data = PlayerDataService.get(player)
	local mine = 0
	if data and data.weekly.week == week then
		mine = data.weekly.best[LeaderboardRules.bestKey(board, danger)] or 0
	end
	local _, saved = backend()
	return {
		board = board,
		danger = danger,
		scope = scope,
		entries = entries,
		mine = mine,
		saved = saved,
		failed = failed,
		resetsIn = LeaderboardRules.secondsToNextWeek(at),
		sentAt = workspace:GetServerTimeNow(),
	}
end

function LeaderboardService.init()
	PlayerDataService.onRunRecorded(onRunRecorded)
	Net.onServer("RequestLeaderboard", function(player: Player, board: string, danger: number, scope: string)
		task.spawn(function()
			local page = LeaderboardService.page(player, board, danger, scope)
			if player.Parent == Players then
				Net.fireClient("Leaderboard", player, page)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		friendCache[player.UserId] = nil
	end)
end

-- Tests: scores in this backend instead of choosing one.
function LeaderboardService.useBackend(backendToUse: Scores.Backend)
	custom = backendToUse
end

-- Tests: the unix time source (os.time by default).
function LeaderboardService.useClock(customClock: () -> number)
	clock = customClock
end

return LeaderboardService
