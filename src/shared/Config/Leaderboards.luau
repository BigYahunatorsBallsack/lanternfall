--!strict
-- Weekly leaderboards (Paket 18, DESIGN.md section 11): per danger level the best wave reached (more kills break a
-- tie) and the most kills in one run, for the whole game and for the player's friends. A new week starts Monday 00:00
-- UTC with empty boards. Scores are written by the server after each finished run (OrderedDataStore, one store per
-- board, danger and week). Read by Util/LeaderboardRules, LeaderboardService and LeaderboardController.

export type Board = {
	key: string, -- part of the store name, never change it (old scores would be lost)
	name: string, -- game text (tab)
}

return table.freeze({
	boards = table.freeze({
		table.freeze({ key = "Wave", name = "BEST WAVE" }),
		table.freeze({ key = "Kills", name = "MOST KILLS" }),
	}) :: { Board },
	scopes = table.freeze({ "Global", "Friends" }),
	storePrefix = "LB1_", -- OrderedDataStore name = prefix .. board .. "_D" .. danger .. "_W" .. week
	-- Wave board score = wave * waveFactor + kills (kills capped below waveFactor), so one number sorts both
	waveFactor = 1000000,
	topSize = 50, -- entries shown on the global board
	friendsMax = 30, -- friends looked up for the friends board (each one is a DataStore read)
	cacheSeconds = 60, -- a board is read again at most this often per server
	writeRetries = 2, -- extra tries of a failed score write
	-- The DataStore read budget left in this server below which friend lookups stop (the board shows who it found)
	minReadBudget = 10,
	weekStartOffsetDays = 4, -- 1970-01-01 was a Thursday: + 4 days = the first Monday, so weeks start on Monday
})
