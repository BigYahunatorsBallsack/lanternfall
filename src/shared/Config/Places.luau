--!strict
-- Places, teleports, parties and quick join (Paket 15, DESIGN.md sections 13 and 15). Read by PlaceService,
-- PartyService and RunPlaceService on the server and by PartyController on the client.
--
-- The game has two places per experience: the hub (start place, up to 24 players) with the lobby, parties and
-- portals, and the run place (max. 4 players) where each group plays in its own reserved server. Both get the same
-- code; Util/PlaceRules decides from game.PlaceId which one a server is. A place that is not listed here (0 = not
-- set yet, or an unpublished file) runs lobby and arena in one server like before ("Single").

return table.freeze({
	-- One entry per experience (place ids from Creator Hub -> Places); the live experience gets its own entry later.
	experiences = table.freeze({
		table.freeze({ name = "Lanternfall Test", hub = 0, run = 0 }),
	}) :: { { name: string, hub: number, run: number } },

	party = table.freeze({
		maxSize = 4, -- = Config.Run.maxPlayers (ConfigCheck)
		inviteSeconds = 30, -- an invite expires after this
		startCountdownSeconds = 3, -- "Party run starts in 3" before the teleport; the leader may cancel
	}),

	quickJoin = table.freeze({
		minPlayers = 2, -- a group starts its countdown once it has this many players
		countdownSeconds = 15, -- then waits this long for more players
		fullCountdownSeconds = 3, -- a full group (party.maxSize) starts after this
	}),

	teleport = table.freeze({
		attempts = 3, -- TeleportAsync tries per teleport (Roblox recommends retrying)
		retryDelaySeconds = 2,
		timeoutSeconds = 30, -- players still here after this count as failed and may try again
	}),

	runPlace = table.freeze({
		waitForGroupSeconds = 20, -- the run starts when the whole group has arrived and loaded, at the latest this long
		-- after the first one arrived
		hubTagSeconds = 120, -- in the hub, players coming back from the same run join one party again within this
	}),

	-- Portals in the hub lobby (ProximityPrompts): offsets from the lobby center, studs
	portals = table.freeze({
		table.freeze({ mode = "Solo", label = "PLAY SOLO", offset = Vector3.new(-22, 0, -32) }),
		table.freeze({ mode = "Party", label = "PARTY RUN", offset = Vector3.new(0, 0, -34) }),
		table.freeze({ mode = "QuickJoin", label = "QUICK JOIN", offset = Vector3.new(22, 0, -32) }),
	}) :: { { mode: string, label: string, offset: Vector3 } },
	portalPromptDistance = 10,
})
