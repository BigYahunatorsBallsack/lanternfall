--!strict
-- Run flow, spawn director, XP curve, level-up and co-op rules (DESIGN.md sections 3, 7, 8, 9).
-- Read by RunDirector, SpawnDirector, UpgradeService and ReviveService; `flow` also by the lobby UI.

local EnemyWaves = require(script.Parent.EnemyWaves)
local Stats = require(script.Parent.Stats)

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

	spawn = table.freeze({
		-- Waves (Brotato direction since B1): wave n lasts lengthsSeconds[n], then the shop opens (Config.Shop) and the
		-- clock stops until the next wave. Wave 1 = 20 s, +5 s per wave, at most 60 s, the final one 90 s, like Brotato
		-- (the same lengths as Config.EnemyWaves).
		waves = table.freeze({
			lengthsSeconds = table.freeze(WAVE_LENGTHS),
		}),
		-- Brotato's enemy maximum: the wave's maxEnemies (100) plus perExtraPlayerShare of it per extra player
		-- (4 players: 137). When a spawn group fires with more regular enemies alive, random ones are removed without
		-- loot (bosses, champions and trees do not count). `max` is EnemySim's technical ceiling for everything alive at
		-- once (births still arrive between group firings, plus bosses, champions, summons and trees).
		cap = table.freeze({ perExtraPlayerShare = 1 / 8, max = 200 }),
		-- studs around a player for debug spawns (AdminService) and Gloom Elites; wave spawns use `layout`
		ringMin = 32,
		ringMax = 52,
		-- Brotato's spawn geometry in its pixels (SpawnRules turns them into studs, 450 px/s = the player's speed):
		-- groups and enemies keep minPlayerDistance from every player (shrinking by distanceStep per retry, down to
		-- minDistanceFloor), edge spawns stand edgeDistance in from the arena wall. Lanternfall's arena is a 160-stud
		-- square; Brotato's Crash Zone is 2048 x 1536 px (204.8 x 153.6 studs).
		layout = table.freeze({
			studsPerPixel = Stats.range.studsPerPoint,
			minPlayerDistance = 300,
			minDistanceFloor = 25,
			distanceStep = 5,
			edgeDistance = 64,
		}),
		-- Brotato's spawn queue: one queued enemy every secondsPerSpawn (3 frames at 60 fps); from `limit` queued on,
		-- (queued - limit) / burstDivisor of them per step, at most burstMax. Each one shows its red cross for
		-- markerSeconds, then appears.
		queue = table.freeze({ secondsPerSpawn = 3 / 60, limit = 100, burstDivisor = 10, burstMax = 2 }),
		-- Brotato 1.2.0.1's own spawn groups (generated, tools/build-enemy-waves.py)
		groups = EnemyWaves,
		-- Wiki: base + increment * (wave - 1), no extra normal-enemy damage multiplier.
		growth = table.freeze({
			hpSteps = table.freeze({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }),
			damageSteps = table.freeze({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }),
			damageScale = 1,
		}),
		-- red crosses on the floor show where enemies will appear, this long before they do (Brotato's entity birth:
		-- 60 frames)
		markerSeconds = 1,
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
