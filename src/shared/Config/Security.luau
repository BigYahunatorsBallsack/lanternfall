--!strict
-- Anti-cheat values (Paket 23, DESIGN.md section 16). Read by MapService/MovementGuard (movement plausibility check),
-- AdminService (which debug commands keep a run on the leaderboards) and PartyService (invite cooldown).

return table.freeze({
	-- Movement check (MapService/MovementGuard): the client moves its own character, so the server compares every
	-- position it reads with the last one it accepted. A move that is faster than the player can walk (plus the dashes
	-- the server granted), that leaves the arena or ends inside a ruin pillar is undone: the character goes back to
	-- the last accepted spot and the services keep using that spot. Only for characters the server placed in the
	-- arena (participants of a run); the lobby and the hub stay unchecked.
	movement = table.freeze({
		enabled = true,
		studio = false, -- off in Studio (tests move characters freely); debug button "MovementCheck" turns it on
		speedTolerance = 1.25, -- allowed speed = the walk speed CombatService set x this
		burstSeconds = 2.5, -- the budget holds this many seconds of walking (lag spikes deliver moves in bursts)
		slackStuds = 6, -- always allowed on top (ping jitter, physics pushes between players)
		dashCredit = 1.25, -- a dash the server granted adds Config.Player.dash.distance x this to the budget
		dashSeconds = 0.6, -- after a granted dash the velocity may reach the dash speed for this long (ping)
		speedGraceSeconds = 1, -- after a slowdown (shop, level-up freeze, down) the old speed still counts this long
		arenaMargin = 2, -- studs a position may be beyond the arena floor's edge (the walls stop real players)
		pillarCore = 1, -- studs inside a ruin pillar's radius that count as "in the wall" (noclip)
		strikeGapSeconds = 1, -- corrections closer together than this count as one (logged once)
	}),

	-- Debug commands that do not change how a run plays. Any other debug command used while a run is on (or in the
	-- lobby before it) keeps that run off the weekly leaderboards (RunStatsService "debug").
	scoreSafeDebugCommands = table.freeze({
		"PrintProfile",
		"PrintAnalytics",
		"NextDay",
		"ResetProfile",
		"UnlockAll",
		"AddEmbers",
		"FakePurchase",
		"LaunchCheck", -- Paket 24
	}),

	-- Hub parties: the same player can be invited again only after this many seconds (no invite popup spam).
	reinviteSeconds = 10,
})
