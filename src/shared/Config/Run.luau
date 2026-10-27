--!strict
-- Run flow, spawn director, XP curve, level-up and co-op rules (DESIGN.md sections 3, 7, 8, 9).
-- Read by RunDirector, SpawnDirector, UpgradeService and ReviveService; `flow` also by the lobby UI.

local Run = {
	durationSeconds = 720, -- boss spawns at 12:00, normal spawning stops
	maxPlayers = 4,

	-- Lobby -> countdown -> run -> results -> lobby (prototype: lobby and arena in one server)
	flow = table.freeze({
		countdownSeconds = 10, -- starts when the first player is ready
		allReadyCountdownSeconds = 3, -- countdown is cut to this once every player in the server is ready
		resultsSeconds = 15, -- results screen, then everyone returns to the lobby
		defaultClassId = "BladeWarden",
		defaultDifficulty = "Normal", -- until difficulty selection arrives in WP13
	}),

	-- fPlayers = 1 + perExtraPlayer * (n - 1)
	playerFactor = table.freeze({ perExtraPlayer = 0.6 }),

	spawn = table.freeze({
		-- enemies/s = (base + perMinute * t) * fPlayers
		baseRate = 1.5,
		ratePerMinute = 0.55,
		-- enemy HP factor = 1 + hpPerMinute * t
		hpPerMinute = 0.15,
		-- alive cap = base + perExtraPlayer * (n - 1), at most max
		cap = table.freeze({ base = 80, perExtraPlayer = 20, max = 140 }),
		ringMin = 45, -- studs around a random player
		ringMax = 60,
		-- against running away (WP9): this share of spawns lands in a cone in front of a walking player (assumption)
		ahead = table.freeze({ share = 0.35, halfAngleDegrees = 60, minSpeed = 4 }),
		-- enemies farther than `distance` from every living player move to a new spawn point (like a fresh spawn),
		-- so a crowd trailing behind a runner comes back in front of them; at the alive cap also the `atCapCount`
		-- farthest ones beyond `atCapDistance`, so running in circles with a full trailing crowd does not stop new
		-- enemies from coming (assumption)
		recycle = table.freeze({ distance = 80, intervalSeconds = 1, atCapDistance = 40, atCapCount = 5 }),
		-- enemy mix by minute; the last entry with fromMinute <= t applies
		mix = table.freeze({
			table.freeze({ fromMinute = 0, weights = table.freeze({ Shadeling = 1 }) }),
			table.freeze({ fromMinute = 2, weights = table.freeze({ Shadeling = 0.8, Brute = 0.2 }) }),
			table.freeze({ fromMinute = 4, weights = table.freeze({ Shadeling = 0.7, Brute = 0.2, Spitter = 0.1 }) }),
		}),
		swarmRush = table.freeze({
			atMinutes = table.freeze({ 5, 9 }),
			durationSeconds = 30,
			rateMultiplier = 2,
			enemy = "Shadeling",
			ringCount = 24, -- extra Shadelings in a closed ring at ringMin around every player when it starts (assumption)
		}),
		-- one Gloom Elite of the current mix (Config.Enemies.elite) at these times, also above the alive cap
		elite = table.freeze({ firstAtMinute = 2, everyMinutes = 2 }),
	}),

	-- XP for level L -> L+1 = round((base + coefficient * L^exponent) * fPlayers)
	xpCurve = table.freeze({ base = 5, coefficient = 2.4, exponent = 1.3 }),

	-- XP orbs dropped by killed enemies; every orb counts for the whole team (DESIGN.md section 8)
	xpOrbs = table.freeze({
		maxOrbs = 300, -- orbs on the floor at once; past this a new orb's XP joins the nearest one (assumption)
	}),

	levelUp = table.freeze({
		cardCount = 3,
		ownedItemWeight = 2, -- owned items are this many times as likely
		autoPickSeconds = 10, -- first card is picked automatically after this
		freeRerollsPerRun = 1,
		maxedOutRewards = table.freeze({ embers = 25, healFraction = 0.3 }),
		protectionAfterPick = 0.5, -- seconds still invulnerable after the last pick, to step out of the crowd (assumption)
		inputDelaySeconds = 0.4, -- cards ignore taps this long after they appear, against accidental picks (assumption)
	}),

	coop = table.freeze({
		chestRadius = 20, -- studs, every player inside gets an elite chest reward
		chestOpenRadius = 3.5, -- studs; a living player this close opens the chest (assumption)
		chestHealFraction = 0.5, -- every rewarded player also heals this share of max HP (WP9, against chip damage)
		downTimerSeconds = 30,
		reviveSeconds = 3,
		reviveHpFraction = 0.4,
		maxPurchasedRevivesPerRun = 1,
	}),
}

return table.freeze(Run)
