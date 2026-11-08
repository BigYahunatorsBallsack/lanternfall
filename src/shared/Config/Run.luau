--!strict
-- Run flow, spawn director, XP curve, level-up and co-op rules (DESIGN.md sections 3, 7, 8, 9).
-- Read by RunDirector, SpawnDirector, UpgradeService and ReviveService; `flow` also by the lobby UI.

local EnemyWaves = require(script.Parent.EnemyWaves)

-- Brotato's 20 waves (since B3, before 12): 20 s, +5 s per wave up to 60 s from wave 9, the final wave 90 s
local WAVE_LENGTHS = { 20, 25, 30, 35, 40, 45, 50, 55, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 90 }

local function sum(list: { number }): number
	local total = 0
	for _, value in list do
		total += value
	end
	return total
end

local Run = {
	durationSeconds = sum(WAVE_LENGTHS), -- fighting time of all waves; surviving the last one wins (boss in WP10)
	maxPlayers = 4,
	-- Random seed of a run (RandomService, since B4): 0 = a new one every run (printed to the output), any other
	-- number replays the same shop offers, cards, drops, spawns and combat rolls as far as the players act the same.
	seed = 0,

	-- Lobby -> countdown -> run -> results -> lobby (prototype: lobby and arena in one server)
	flow = table.freeze({
		countdownSeconds = 10, -- starts when the first player is ready
		allReadyCountdownSeconds = 3, -- countdown is cut to this once every player in the server is ready
		resultsSeconds = 15, -- results screen, then everyone returns to the lobby
		defaultClassId = "NightWatch",
		-- B11 part 2: "Retry wave" on the results after a defeat starts the lost wave again from its start state
		-- (XP, level, Shards, stats, weapons, items, HP), this often per run (assumption)
		maxRetries = 3,
		-- playtest after Paket 24: endless mode is no longer picked in the lobby; winning the boss wave asks every
		-- participant "continue endless or stop?" for this long (more "continue" than "stop" goes on, else it is won)
		endlessChoiceSeconds = 20,
	}),

	-- fPlayers = 1 + perExtraPlayer * (n - 1)
	playerFactor = table.freeze({ perExtraPlayer = 0.6 }),

	spawn = table.freeze({
		-- Waves (Brotato direction since B1): wave n lasts lengthsSeconds[n], then the shop opens (Config.Shop) and the
		-- clock stops until the next wave. The rate ramps from rampFrom to rampTo through each wave; the final wave runs
		-- at finalRate times that. Wave 1 = 20 s, +5 s per wave, at most 60 s, the final one 90 s, like Brotato.
		waves = table.freeze({
			lengthsSeconds = table.freeze(WAVE_LENGTHS),
			rampFrom = 0.7,
			rampTo = 1.2,
			finalRate = 1.4,
		}),
		-- alive cap = base + perExtraPlayer * (n - 1), at most max
		cap = table.freeze({ base = 80, perExtraPlayer = 20, max = 140 }),
		-- studs around a random player; since B9 closer (before 45-60, just out of sight), so the spawn markers are
		-- seen (assumption)
		ringMin = 32,
		ringMax = 52,
		-- against running away (WP9): this share of spawns lands in a cone in front of a walking player (assumption)
		ahead = table.freeze({ share = 0.35, halfAngleDegrees = 60, minSpeed = 4 }),
		-- enemies farther than `distance` from every living player move to a new spawn point (like a fresh spawn),
		-- so a crowd trailing behind a runner comes back in front of them; at the alive cap also the `atCapCount`
		-- farthest ones beyond `atCapDistance`, so running in circles with a full trailing crowd does not stop new
		-- enemies from coming (assumption)
		recycle = table.freeze({ distance = 80, intervalSeconds = 1, atCapDistance = 40, atCapCount = 5 }),
		-- Wiki first appearances are enforced per danger by SpawnRules. Density remains a Roblox adaptation.
		groups = EnemyWaves,
		-- Wiki: base + increment * (wave - 1), no extra normal-enemy damage multiplier.
		growth = table.freeze({
			hpSteps = table.freeze({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }),
			damageSteps = table.freeze({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }),
			damageScale = 1,
		}),
		firstShare = 0.3, -- a group fires the first time after this share of its interval (assumption)
		-- at the alive cap a group waits for room instead of being dropped; it saves up at most this many firings
		maxOwedFirings = 2,
		groupSpread = 1.6, -- studs * sqrt(enemies in the group) (assumption)
		-- red crosses on the floor show where enemies will appear, this long before they do (Brotato; assumption)
		markerSeconds = 1,
		swarmRush = table.freeze({
			atMinutes = table.freeze({ 6, 11, 16 }),
			durationShare = 0.6, -- of its wave
			rateMultiplier = 2, -- of the wave's groups, which pause meanwhile
			enemy = "Shadeling",
			every = 2, -- seconds between the Shadeling groups of a Swarm Rush (B9)
			ringCount = 24, -- extra Shadelings in a closed ring around every player when it starts (assumption)
			ringDistance = 45, -- studs; the old ringMin, so the ring did not come closer with B9
		}),
		-- Gloom Elites of the wave's groups (weighted by enemies per second) (Config.Enemies.elite) at these minutes, also above the alive cap; from
		-- affixFromMinute each gets a random affix (Swift, Armored, Summoning)
		elites = table.freeze({
			waves = table.freeze({
				table.freeze({ atMinute = 2, count = 1 }),
				table.freeze({ atMinute = 5, count = 1 }),
				table.freeze({ atMinute = 8, count = 1 }),
				table.freeze({ atMinute = 10, count = 2 }),
				table.freeze({ atMinute = 12, count = 1 }),
				table.freeze({ atMinute = 14, count = 2 }),
				table.freeze({ atMinute = 16, count = 2 }),
				table.freeze({ atMinute = 18, count = 2 }),
			}),
			affixFromMinute = 8,
		}),
	}),

	-- Native starts at LV.0; next XP is (3 + (L + 1))^2 times the character's exact required-XP multiplier.
	xpCurve = table.freeze({ offset = 4, exponent = 2 }),

	-- XP orbs dropped by killed enemies; every orb counts for the whole team (DESIGN.md section 8)
	xpOrbs = table.freeze({
		maxOrbs = 50, -- orbs on the floor at once; past this a new orb's XP joins the nearest one (Brotato, since B6)
	}),

	-- Level-up cards (Brotato direction since B2): stat upgrades (Config.Stats), each card its own stat and rarity tier.
	-- The tier is rolled like shop items with the level in place of the wave (Config.Items.tiers, Luck raises it);
	-- some levels always give one tier: guaranteedTiers[level], and every legendaryEvery.every levels from
	-- legendaryEvery.fromLevel a Legendary (Brotato: 5 -> II, 10/15/20 -> III, 25, 30, ... -> IV).
	levelUp = table.freeze({
		cardCount = 4,
		guaranteedTiers = table.freeze({ [5] = 2, [10] = 3, [15] = 3, [20] = 3 }),
		legendaryEvery = table.freeze({ fromLevel = 25, every = 5 }),
		autoPickSeconds = 10, -- first card is picked automatically after this
		-- While picking: true = the player stands still and is invulnerable (original design); false = they keep walking,
		-- taking hits (owner feedback after WP9)
		freezeWhileChoosing = false,
		protectionAfterPick = 0.5, -- with freezeWhileChoosing: seconds still invulnerable after the last pick (assumption)
		inputDelaySeconds = 0.4, -- cards ignore taps this long after they appear, against accidental picks (assumption)
	}),

	coop = table.freeze({
		chestRadius = 20, -- studs, every player inside gets an elite chest reward
		chestOpenRadius = 3.5, -- studs; a living player this close opens the chest (assumption)
		chestHealFraction = 0.5, -- every rewarded player also heals this share of max HP (WP9, against chip damage)
		downTimerSeconds = 30, -- a downed player is out for the rest of the wave after this (WP11)
		reviveSeconds = 3, -- a living teammate stands next to them this long to revive them
		reviveHpFraction = 0.4,
		maxPurchasedRevivesPerRun = 1,
		-- WP11 (assumptions, check in the test)
		reviveRadius = 6, -- studs between the teammate and the downed player (ground distance)
		reviveDecaySeconds = 3, -- with nobody near, a started revive drains back to zero in this time
		downTimerPausesWhileReviving = true, -- the 30 s stand still while a teammate is reviving
		reviveProtectionSeconds = 2, -- invulnerable this long after standing up
		outReturnsAtWaveEnd = true, -- players who are out stand up at the end of the wave too (Brotato co-op)
	}),
}

return table.freeze(Run)
