--!strict
-- Analytics events (Paket 20, DESIGN.md section 18): which events go to Roblox's AnalyticsService (Creator Hub ->
-- Analytics: Funnels, Economy, Progression, Custom), their names, fields and the per-server event budget. Read by
-- AnalyticsService and its pure rules (AnalyticsService/AnalyticsRules). Server only, nothing is sent to clients.

return table.freeze({
	enabled = true,
	-- Roblox does not record events from Studio; with this on, Studio prints every event to the Output as well
	-- (the debug button "Print analytics log" prints the last ones either way)
	printInStudio = false,
	logSize = 60, -- events the server remembers for the debug button

	-- Roblox limits events per server and minute (assumption from the docs: 120 + 20 per player). The budget below
	-- stays inside that; when it runs low, "low" priority events (card offers, shop buys) are dropped first.
	budget = table.freeze({
		perMinute = 120,
		perMinutePerPlayer = 20,
		lowReserveShare = 0.25, -- low priority events stop when less than this share of the minute is left
	}),

	-- Onboarding funnel "First start" (Creator Hub -> Analytics -> Funnels -> Onboarding). Only players without a
	-- finished run go through it; steps are logged in this order, once each (a step reached early waits for the ones
	-- before it). "BackInLobby" = the first run's results are over (lobby, hub or "Play again").
	onboarding = table.freeze({
		steps = table.freeze({
			"Joined",
			"Moved",
			"FirstKill",
			"FirstLevelUp",
			"Played3Minutes",
			"FirstRunEnded",
			"BackInLobby",
			"SecondRun",
		}),
		movedStuds = 6, -- the character walked this far in total
		teleportStuds = 100, -- a bigger step between two checks is a teleport (lobby -> arena), not walking
		playedSeconds = 180, -- "Played3Minutes": time since joining
		checkSeconds = 1, -- how often the server checks "Moved" and "Played3Minutes"
	}),

	-- Progression (Creator Hub -> Analytics -> Progression): one path per danger level, level = wave. Start when a
	-- wave starts (also after "Retry wave"), Complete when it is cleared, Fail when the run is lost there.
	progression = table.freeze({
		pathPrefix = "Danger",
		endlessSuffix = "Endless",
		firstNightPath = "FirstNight",
	}),

	-- Economy (Creator Hub -> Analytics -> Economy): the saved currency. Sources and sinks with Roblox's transaction
	-- types (Enum.AnalyticsEconomyTransactionType names).
	economy = table.freeze({
		currency = "Embers",
		sources = table.freeze({
			RunReward = "Gameplay",
			Achievement = "Gameplay",
			Quest = "Gameplay",
			LoginStreak = "TimedReward",
			Purchase = "IAP",
		}),
		sinks = table.freeze({
			EmberShop = "Shop",
		}),
	}),

	-- Custom events (Creator Hub -> Analytics -> Custom): value and up to three fields each (Roblox's limit).
	custom = table.freeze({
		RunEnded = table.freeze({ priority = "high", fields = { "Outcome", "Danger", "Players" } }), -- value: seconds
		PlayerDown = table.freeze({ priority = "high", fields = { "Cause", "Enemy", "Wave" } }),
		BossKilled = table.freeze({ priority = "high", fields = { "Boss", "Danger" } }), -- value: wave
		CardPicked = table.freeze({ priority = "high", fields = { "Card", "Tier", "Auto" } }),
		CardOffered = table.freeze({ priority = "low", fields = { "Card", "Tier" } }),
		ItemBought = table.freeze({ priority = "low", fields = { "Kind", "Item", "Wave" } }),
		Revived = table.freeze({ priority = "high", fields = { "Wave" } }),
		RetryWave = table.freeze({ priority = "high", fields = { "Wave", "Danger" } }),
		FirstNightSkipped = table.freeze({ priority = "high", fields = { "Wave" } }), -- value: wave
		-- Paket 23: the movement check moved a player back (reason Speed/Outside/Pillar); value: studs of the move
		MovementCorrected = table.freeze({ priority = "low", fields = { "Reason", "Wave" } }),
	}),

	-- "PlayerDown" cause: what hit the player in the moment they went down
	down = table.freeze({
		hitWindowSeconds = 0.5, -- a contact or shot this recent counts as the cause, else "Other" (boss attacks)
		enemyRange = 30, -- studs: the nearest enemy this close is named in the "Enemy" field
	}),

	maxFieldLength = 50, -- longer field values are cut (keeps the dashboard readable)
})
