--!strict
-- Run flow, spawn director, XP curve, level-up and co-op rules (DESIGN.md sections 3, 7, 8, 9).
-- Read by RunDirector, SpawnDirector, UpgradeService and ReviveService; `flow` also by the lobby UI.

local Enemies = require(script.Parent.Enemies)

-- Brotato's 20 waves (since B3, before 12): 20 s, +5 s per wave up to 60 s from wave 9, the final wave 90 s
local WAVE_LENGTHS = { 20, 25, 30, 35, 40, 45, 50, 55, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 90 }

local function sum(list: { number }): number
	local total = 0
	for _, value in list do
		total += value
	end
	return total
end

-- One spawn group of a wave (B9, Brotato): `size` enemies of `enemy` appear together at one spot every `every`
-- seconds of the wave (DESIGN.md section 7).
local function group(enemy: string, size: number, every: number)
	return table.freeze({ enemy = enemy, size = size, every = every })
end

-- A wave's spawn groups; `announce` lists the kinds that are new, for the wave banner (HUD; since B11 the danger
-- level leaves out kinds that do not come).
local function wave(groups: { any }, announce: { string }?)
	local list = {}
	for _, enemyId in announce or {} do
		local kind = Enemies.types[enemyId]
		table.insert(list, table.freeze({ enemy = enemyId, name = `{if kind then kind.displayName else enemyId}s` }))
	end
	return table.freeze({ groups = table.freeze(groups), announce = if announce then table.freeze(list) else nil })
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
		defaultClassId = "BladeWarden",
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
		-- Spawn groups of every wave (B9, Brotato's waves; before: a rate curve and a mix by minute). Each group
		-- fires every `every` seconds from the wave start (the first time after firstShare of that) and brings
		-- size * wave intensity * fPlayers * the team's Enemies stat enemies of one kind, spread around one spot on
		-- the spawn ring (groupSpread * sqrt(count) studs). The numbers keep the enemies per second and the mix of
		-- the old rate curve and mix (before the wave intensity, which averages 0.95). Since B9 part 2 the new kinds
		-- (Config.Enemies: Stalker from wave 4, Brood Egg and Gobbler 8, Herald 9, Skulker and Mender 10, Reaper 11,
		-- Thornback 12) take a share of the Shadelings' rate. B11: Brute and Abyss Brute groups at 65 % of their size
		-- (owner test 30.10.2026: the big ones pile up and cannot be killed, the small ones are fine).
		groups = table.freeze({
			wave({ group("Shadeling", 4, 2.5) }), -- wave 1: 1.60 enemies/s
			wave({ group("Shadeling", 6, 2.4) }), -- wave 2: 2.50 enemies/s
			wave({ group("Shadeling", 6, 2.3), group("Brute", 2, 4.6) }, { "Brute" }), -- wave 3: 3.26 enemies/s
			wave({ group("Shadeling", 7, 2.6), group("Brute", 2.6, 5.2), group("Stalker", 2, 6) }, { "Stalker" }), -- wave 4: 3.79 enemies/s
			wave({
				group("Shadeling", 7, 2.7),
				group("Brute", 2.6, 5.2),
				group("Charger", 3, 5.8),
				group("Stalker", 2, 6),
			}, { "Charger" }), -- wave 5: 4.21 enemies/s
			wave({
				group("Shadeling", 6, 2.4),
				group("Brute", 2.6, 5.2),
				group("Charger", 3, 5.2),
				group("Spitter", 3, 6.3),
				group("Stalker", 3, 7),
			}, { "Spitter" }), -- wave 6: 4.75 enemies/s
			wave({
				group("Shadeling", 7, 2.5),
				group("Brute", 2.6, 4.8),
				group("Charger", 4, 6.4),
				group("Spitter", 4, 7.7),
				group("Stalker", 3, 7),
			}), -- wave 7: 5.21 enemies/s
			wave({
				group("Shadeling", 7, 2.6),
				group("Brute", 3.2, 5.5),
				group("Charger", 4, 5.9),
				group("Spitter", 4, 7),
				group("Stalker", 3, 7),
				group("BroodEgg", 2, 9),
				group("Gobbler", 1, 10),
			}, { "BroodEgg", "Gobbler" }), -- wave 8: 5.60 enemies/s
			wave({
				group("Shadeling", 5, 2.5),
				group("AbyssShadeling", 4, 3.3),
				group("Brute", 2.6, 5),
				group("Charger", 4, 5.4),
				group("Spitter", 4, 6.5),
				group("Stalker", 3, 7),
				group("BroodEgg", 2, 9),
				group("Gobbler", 1, 10),
				group("Herald", 1, 12),
			}, { "AbyssShadeling", "Herald" }), -- wave 9: 6.20 enemies/s
			wave({
				group("Shadeling", 5, 2.4),
				group("AbyssShadeling", 3, 3),
				group("Brute", 2.6, 4.7),
				group("Charger", 5, 6.3),
				group("Spitter", 5, 7.6),
				group("Stalker", 3, 7),
				group("BroodEgg", 2, 9),
				group("Gobbler", 1, 10),
				group("Herald", 1, 12),
				group("Skulker", 2, 10),
				group("Mender", 1, 12),
			}, { "Skulker", "Mender" }), -- wave 10: 6.50 enemies/s
			wave({
				group("Shadeling", 2, 2.3),
				group("AbyssShadeling", 5, 2.9),
				group("Brute", 2, 4.3),
				group("Charger", 4, 6),
				group("Spitter", 5, 7.2),
				group("Splitter", 5, 5.5),
				group("Stalker", 3, 7),
				group("BroodEgg", 2, 9),
				group("Gobbler", 1, 10),
				group("Herald", 1, 12),
				group("Skulker", 2, 10),
				group("Mender", 1, 12),
				group("Reaper", 2, 8),
			}, { "Splitter", "Reaper" }), -- wave 11: 6.93 enemies/s
			wave({
				group("Shadeling", 3, 2.7),
				group("AbyssShadeling", 6, 3.2),
				group("Brute", 2, 5.4),
				group("Charger", 4, 5.7),
				group("Spitter", 5, 6.8),
				group("Splitter", 6, 6.3),
				group("Stalker", 3, 7),
				group("BroodEgg", 2, 9),
				group("Gobbler", 1, 10),
				group("Herald", 1, 12),
				group("Skulker", 2, 10),
				group("Mender", 1, 12),
				group("Reaper", 2, 8),
				group("Thornback", 2, 9),
			}, { "Thornback" }), -- wave 12: 7.52 enemies/s
			wave({
				group("Shadeling", 2, 2.6),
				group("AbyssShadeling", 6, 3.1),
				group("Brute", 1.3, 5.2),
				group("AbyssBrute", 3.2, 6.5),
				group("Charger", 6, 6.5),
				group("Spitter", 4, 6.5),
				group("Splitter", 5, 5.9),
				group("Stalker", 3, 7),
				group("BroodEgg", 2, 9),
				group("Gobbler", 1, 10),
				group("Herald", 1, 12),
				group("Mender", 1, 12),
				group("Skulker", 2, 10),
				group("Reaper", 2, 8),
				group("Thornback", 2, 9),
			}, { "AbyssBrute" }), -- wave 13: 7.83 enemies/s
			wave({
				group("Shadeling", 2, 2.5),
				group("AbyssShadeling", 6, 3),
				group("Brute", 1.3, 5),
				group("AbyssBrute", 3.9, 7.4),
				group("Charger", 6, 6.2),
				group("Spitter", 5, 7.4),
				group("Splitter", 5, 5.6),
				group("Stalker", 3, 7),
				group("BroodEgg", 2, 9),
				group("Gobbler", 1, 10),
				group("Herald", 1, 12),
				group("Mender", 1, 12),
				group("Skulker", 2, 10),
				group("Reaper", 2, 8),
				group("Thornback", 2, 9),
			}), -- wave 14: 8.14 enemies/s
			wave({
				group("Shadeling", 2, 2.4),
				group("AbyssShadeling", 7, 3.1),
				group("Brute", 1.3, 4.8),
				group("AbyssBrute", 3.9, 7.1),
				group("Charger", 6, 5.9),
				group("Spitter", 5, 7.1),
				group("Splitter", 6, 6.5),
				group("Stalker", 3, 7),
				group("BroodEgg", 2, 9),
				group("Gobbler", 1, 10),
				group("Herald", 1, 12),
				group("Mender", 1, 12),
				group("Skulker", 2, 10),
				group("Reaper", 2, 8),
				group("Thornback", 2, 9),
			}), -- wave 15: 8.59 enemies/s
			wave({
				group("AbyssShadeling", 9, 3),
				group("AbyssBrute", 5.9, 7.4),
				group("Charger", 7, 5.7),
				group("Spitter", 5, 6.9),
				group("Splitter", 6, 5.7),
				group("Stalker", 3, 7),
				group("BroodEgg", 2, 9),
				group("Gobbler", 1, 10),
				group("Herald", 1, 12),
				group("Mender", 1, 12),
				group("Skulker", 2, 10),
				group("Reaper", 2, 8),
				group("Thornback", 2, 9),
			}), -- wave 16: 8.81 enemies/s
			wave({
				group("AbyssShadeling", 10, 3.1),
				group("AbyssBrute", 5.9, 7.1),
				group("Charger", 8, 6.3),
				group("Spitter", 5, 6.7),
				group("Splitter", 6, 5.5),
				group("Stalker", 3, 7),
				group("BroodEgg", 2, 9),
				group("Gobbler", 1, 10),
				group("Herald", 1, 12),
				group("Mender", 1, 12),
				group("Skulker", 2, 10),
				group("Reaper", 2, 8),
				group("Thornback", 2, 9),
			}), -- wave 17: 9.19 enemies/s
			wave({
				group("AbyssShadeling", 10, 3),
				group("AbyssBrute", 5.9, 6.9),
				group("Charger", 8, 6.1),
				group("Spitter", 6, 7.5),
				group("Splitter", 7, 6.3),
				group("Stalker", 3, 7),
				group("BroodEgg", 2, 9),
				group("Gobbler", 1, 10),
				group("Herald", 1, 12),
				group("Mender", 1, 12),
				group("Skulker", 2, 10),
				group("Reaper", 2, 8),
				group("Thornback", 2, 9),
			}), -- wave 18: 9.45 enemies/s
			wave({
				group("AbyssShadeling", 10, 2.9),
				group("AbyssBrute", 5.9, 6.7),
				group("Charger", 8, 6),
				group("Spitter", 6, 7.3),
				group("Splitter", 7, 6.1),
				group("Stalker", 3, 7),
				group("BroodEgg", 2, 9),
				group("Gobbler", 1, 10),
				group("Herald", 1, 12),
				group("Mender", 1, 12),
				group("Skulker", 2, 10),
				group("Reaper", 2, 8),
				group("Thornback", 2, 9),
			}), -- wave 19: 9.68 enemies/s
			wave({
				group("AbyssShadeling", 11, 3),
				group("AbyssBrute", 6.5, 7.2),
				group("Charger", 8, 5.8),
				group("Spitter", 6, 7.1),
				group("Splitter", 7, 5.9),
				group("Stalker", 3, 7),
				group("BroodEgg", 2, 9),
				group("Gobbler", 1, 10),
				group("Herald", 1, 12),
				group("Mender", 1, 12),
				group("Skulker", 2, 10),
				group("Reaper", 2, 8),
				group("Thornback", 2, 9),
			}), -- wave 20: 10.06 enemies/s
		}),
		-- How many growth steps an enemy spawned in wave n has (B9): HP = hp + hpPerWave * hpSteps[n], damage alike
		-- (Config.Enemies). Brotato counts n - 1; with that the balance simulation lost 12 of 12 runs by wave 3-10
		-- (2.3 times the HP in wave 5). So the steps follow the tested curves from before B9 (few early, many late),
		-- HP 30 % and damage 15 % above them. Balance simulation (fight bot, 2 classes x 12 seeds): 8 of 24 won
		-- before B9, 18 of 24 with spawn groups on the old curves and 18 of 24 with these steps, so groups make
		-- the run easier in a way HP and damage barely change (assumption: enemies come in clumps from fewer
		-- directions). The owner judges it in the test.
		growth = table.freeze({
			hpSteps = table.freeze({
				0, -- wave 1: the kind's own values, like Brotato
				0.22,
				0.45,
				0.79,
				1.2,
				1.68,
				2.25,
				2.91,
				3.68,
				4.54,
				5.45,
				6.41,
				7.64,
				9.18,
				11,
				13.09,
				15.39,
				17.88,
				20.55,
				23.41,
			}),
			damageSteps = table.freeze({
				0,
				0.17,
				0.29,
				0.62,
				1.18,
				1.75,
				2.43,
				3.21,
				4,
				4.85,
				5.75,
				6.65,
				7.89,
				9.48,
				11.05,
				12.8,
				14.71,
				16.63,
				18.69,
				20.88,
			}),
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

	-- XP for level L -> L+1 = round((L + offset)^exponent * fPlayers); Brotato's (L + 3)^2 since B2
	xpCurve = table.freeze({ offset = 3, exponent = 2 }),

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
		-- dashing and taking hits (owner feedback after WP9)
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
