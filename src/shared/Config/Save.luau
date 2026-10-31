--!strict
-- Player data saving (Paket 12, DESIGN.md section 16). Read by PlayerDataService on the server.

return table.freeze({
	storeName = "PlayerData", -- DataStore name; the test experience has its own DataStores, so test data stays there
	keyPrefix = "Player_", -- one profile per player, key = keyPrefix .. UserId
	saveAfterRun = true, -- one extra save right after every run (ProfileStore also autosaves every 300 s)
	-- Kick texts (game text, English)
	kickLoadFailed = "Your saved data could not be loaded. Please rejoin in a moment.",
	kickSessionEnded = "Your saved data was opened on another server. Please rejoin.",
})
