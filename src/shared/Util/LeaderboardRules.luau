--!strict
-- Weekly leaderboard rules from Config.Leaderboards as pure functions (Paket 18): the week number (Monday 00:00 UTC),
-- seconds until the next week, store names, the score a finished run gets on each board and how to read a score back.
-- Shared by LeaderboardService and LeaderboardController. Tested in tests/QuestRules.spec.luau.

local Config = require(script.Parent.Parent.Config)

local Leaderboards = Config.Leaderboards

local WEEK_SECONDS = 7 * 86400

local LeaderboardRules = {}

local boardKeys: { string } = {}
for _, board in Leaderboards.boards do
	table.insert(boardKeys, board.key)
end

-- Board keys in Config order (remote validation, tabs).
function LeaderboardRules.boardKeys(): { string }
	return boardKeys
end

-- The week number of a unix time; weeks start on Monday 00:00 UTC.
function LeaderboardRules.week(unixTime: number): number
	return math.floor((unixTime - Leaderboards.weekStartOffsetDays * 86400) / WEEK_SECONDS)
end

-- Seconds until the next week starts (boards reset).
function LeaderboardRules.secondsToNextWeek(unixTime: number): number
	local week = LeaderboardRules.week(unixTime)
	return (week + 1) * WEEK_SECONDS + Leaderboards.weekStartOffsetDays * 86400 - unixTime
end

-- OrderedDataStore name of a board, danger level and week, e.g. "LB1_Wave_D3_W2912".
function LeaderboardRules.storeName(board: string, danger: number, week: number): string
	return `{Leaderboards.storePrefix}{board}_D{danger}_W{week}`
end

-- The key of a board and danger level in a player's weekly bests (ProfileTemplate.Data.weekly.best).
function LeaderboardRules.bestKey(board: string, danger: number): string
	return `{board}_D{danger}`
end

-- The score a finished run gets on a board (whole number, higher is better; 0 = nothing to write).
function LeaderboardRules.score(board: string, wave: number, kills: number): number
	local cappedKills = math.clamp(math.floor(kills), 0, Leaderboards.waveFactor - 1)
	if board == "Wave" then
		return math.max(0, math.floor(wave)) * Leaderboards.waveFactor + cappedKills
	end
	return cappedKills
end

-- A score as wave and kills (the Kills board has no wave: 0).
function LeaderboardRules.read(board: string, score: number): (number, number)
	if board == "Wave" then
		return math.floor(score / Leaderboards.waveFactor), score % Leaderboards.waveFactor
	end
	return 0, score
end

-- Text of a score, e.g. "Wave 20 · 3412 kills" or "3412 kills".
function LeaderboardRules.text(board: string, score: number): string
	local wave, kills = LeaderboardRules.read(board, score)
	if board == "Wave" then
		return `Wave {wave} · {kills} kills`
	end
	return `{kills} kills`
end

return LeaderboardRules
