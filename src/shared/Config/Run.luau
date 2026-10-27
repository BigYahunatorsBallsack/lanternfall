--!strict
-- Run flow, spawn director, XP curve, level-up and co-op rules (DESIGN.md sections 3, 7, 8, 9).
-- Read by RunDirector, SpawnDirector, UpgradeService and ReviveService; `flow` also by the lobby UI.

local WAVE_LENGTHS = { 20, 25, 30, 35, 40, 45, 50, 55, 60, 60, 60, 60 }

local function sum(list: { number }): number
	local total = 0
	for _, value in list do
		total += value
	end
	return total
end

local Run = {
	durationSeconds = sum(WAVE_LENGTHS), -- fighting time of all waves; then the boss spawns and normal spawning stops
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
		-- Curves are keyframes { minute, value }, linear in between and flat after the last one (Util/RunSchedule).
		-- A "minute" here is one wave of the schedule: wave n runs from minute n - 1 to minute n, whatever its length
		-- in seconds, so minute 2 = the start of wave 3.
		-- enemies/s = rate curve * wave intensity * fPlayers (* Swarm Rush)
		rateCurve = table.freeze({
			table.freeze({ 0, 1 }), -- calm start: a few Shadelings for the first level-ups
			table.freeze({ 1, 2.2 }),
			table.freeze({ 3, 3.6 }),
			table.freeze({ 6, 5 }),
			table.freeze({ 9, 6.8 }),
			table.freeze({ 12, 8.6 }),
		}),
		-- multiplier on enemy HP at spawn time (times difficulty); grows faster and faster
		hpCurve = table.freeze({
			table.freeze({ 0, 1 }),
			table.freeze({ 2, 1.15 }),
			table.freeze({ 4, 1.4 }),
			table.freeze({ 6, 1.75 }),
			table.freeze({ 8, 2.3 }),
			table.freeze({ 10, 3 }),
			table.freeze({ 12, 3.8 }),
		}),
		-- multiplier on contact and projectile damage at spawn time (times difficulty)
		damageCurve = table.freeze({
			table.freeze({ 0, 1 }),
			table.freeze({ 6, 1.1 }),
			table.freeze({ 12, 1.25 }),
		}),
		-- Waves (Brotato direction since B1): wave n lasts lengthsSeconds[n], then the shop opens (Config.Shop) and the
		-- clock stops until the next wave. The rate ramps from rampFrom to rampTo through each wave; the final wave runs
		-- at finalRate times that. Wave 1 = 20 s, +5 s per wave, at most 60 s, like Brotato.
		waves = table.freeze({
			lengthsSeconds = table.freeze(WAVE_LENGTHS),
			rampFrom = 0.7,
			rampTo = 1.2,
			finalRate = 1.4,
		}),
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
		-- enemy mix by minute; the last entry with fromMinute <= t applies. `announce` shows on the wave banner of the
		-- wave that starts at fromMinute (HUD).
		mix = table.freeze({
			table.freeze({ fromMinute = 0, weights = table.freeze({ Shadeling = 1 }) }),
			table.freeze({
				fromMinute = 2,
				announce = "Brutes",
				weights = table.freeze({ Shadeling = 0.8, Brute = 0.2 }),
			}),
			table.freeze({
				fromMinute = 3,
				announce = "Chargers",
				weights = table.freeze({ Shadeling = 0.7, Brute = 0.18, Charger = 0.12 }),
			}),
			table.freeze({
				fromMinute = 4,
				announce = "Spitters",
				weights = table.freeze({ Shadeling = 0.62, Brute = 0.16, Charger = 0.12, Spitter = 0.1 }),
			}),
			table.freeze({
				fromMinute = 6,
				announce = "Abyss Shadelings",
				weights = table.freeze({
					Shadeling = 0.45,
					AbyssShadeling = 0.2,
					Brute = 0.13,
					Charger = 0.12,
					Spitter = 0.1,
				}),
			}),
			table.freeze({
				fromMinute = 7,
				announce = "Splitters",
				weights = table.freeze({
					Shadeling = 0.25,
					AbyssShadeling = 0.3,
					Brute = 0.1,
					Charger = 0.12,
					Spitter = 0.1,
					Splitter = 0.13,
				}),
			}),
			table.freeze({
				fromMinute = 8,
				announce = "Abyss Brutes",
				weights = table.freeze({
					Shadeling = 0.1,
					AbyssShadeling = 0.42,
					Brute = 0.05,
					AbyssBrute = 0.1,
					Charger = 0.12,
					Spitter = 0.1,
					Splitter = 0.11,
				}),
			}),
			table.freeze({
				fromMinute = 10,
				weights = table.freeze({
					AbyssShadeling = 0.5,
					AbyssBrute = 0.14,
					Charger = 0.14,
					Spitter = 0.1,
					Splitter = 0.12,
				}),
			}),
		}),
		swarmRush = table.freeze({
			atMinutes = table.freeze({ 5, 9 }),
			durationShare = 0.6, -- of its wave
			rateMultiplier = 2,
			enemy = "Shadeling",
			ringCount = 24, -- extra Shadelings in a closed ring at ringMin around every player when it starts (assumption)
		}),
		-- Gloom Elites of the current mix (Config.Enemies.elite) at these minutes, also above the alive cap; from
		-- affixFromMinute each gets a random affix (Swift, Armored, Summoning)
		elites = table.freeze({
			waves = table.freeze({
				table.freeze({ atMinute = 2, count = 1 }),
				table.freeze({ atMinute = 4, count = 1 }),
				table.freeze({ atMinute = 6, count = 2 }),
				table.freeze({ atMinute = 8, count = 1 }),
				table.freeze({ atMinute = 10, count = 2 }),
			}),
			affixFromMinute = 6,
		}),
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
		-- While picking: true = the player stands still and is invulnerable (original design); false = they keep walking,
		-- dashing and taking hits (owner feedback after WP9)
		freezeWhileChoosing = false,
		protectionAfterPick = 0.5, -- with freezeWhileChoosing: seconds still invulnerable after the last pick (assumption)
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
