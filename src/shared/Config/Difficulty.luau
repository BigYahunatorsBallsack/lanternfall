--!strict
-- Danger levels 0-5, enemy sliders and endless mode (B11, Brotato's "Danger levels" and "Endless Mode", DESIGN.md
-- section 10). Read by Util/DangerRules, Util/RunSchedule, RunDirector (lobby choice), DangerService, SpawnDirector,
-- BossService and the lobby UI (DangerChoice). Until WP13 every level is open to everyone.

export type Level = {
	level: number, -- 0..5
	displayName: string,
	description: string, -- lobby text
	enemyHp: number, -- multiplier on every enemy's HP (Brotato: total, not stacked per level)
	enemyDamage: number,
	newEnemies: boolean, -- the kinds in `newEnemies` below take part in the spawn groups
	challengeSlots: number, -- elite or horde waves per 20 waves (Enemies.eliteWaves.slots)
	bossCount: number, -- bosses in wave 20, each with Enemies.bossWave.hpShareWhenSeveral HP when more than one
	gloomElites: boolean, -- the old Gloom Elites with a chest at the minutes of Run.spawn.elites
}

local function level(
	n: number,
	description: string,
	scale: number,
	newEnemies: boolean,
	challengeSlots: number,
	bossCount: number
): Level
	return table.freeze({
		level = n,
		displayName = `Danger {n}`,
		description = description,
		enemyHp = scale,
		enemyDamage = scale,
		newEnemies = newEnemies,
		challengeSlots = challengeSlots,
		bossCount = bossCount,
		-- Brotato has no such elites; the accepted plan (29.10.2026) was "elites only in elite waves from danger 2",
		-- so they are off everywhere (switch back on per level here)
		gloomElites = false,
	})
end

local Difficulty = {
	-- index = level + 1 (Brotato wiki "Danger Levels")
	levels = table.freeze({
		level(0, "No modifiers", 1, false, 0, 1),
		level(1, "New enemies appear", 1, true, 0, 1),
		level(2, "New enemies · an elite or horde wave (11 or 12)", 1, true, 1, 1),
		level(3, "New enemies · one elite or horde wave · enemies +12% HP and damage", 1.12, true, 1, 1),
		level(4, "New enemies · three elite or horde waves (11-18) · enemies +26% HP and damage", 1.26, true, 3, 1),
		level(
			5,
			"New enemies · three elite or horde waves · enemies +40% · two bosses (75% HP each)",
			1.4,
			true,
			3,
			2
		),
	}),
	defaultLevel = 0,
	-- Danger 1 brings these kinds (B9 part 2's new enemies, our counterpart to Brotato's "new enemies appear");
	-- below it their spawn groups are left out
	newEnemies = table.freeze({
		"Stalker",
		"Skulker",
		"Thornback",
		"Herald",
		"Mender",
		"BroodEgg",
		"Reaper",
		"Gobbler",
	}),

	-- Elite or horde wave (Brotato): each of the first two slots is a horde wave with hordeChance, the third slot is
	-- always an elite wave. Hordes only in the first 20 waves.
	hordeChance = 0.4,
	horde = table.freeze({
		spawnMultiplier = 2, -- enemies of the wave's spawn groups (Brotato gives no number, assumption)
		orbShare = 0.65, -- Brotato: enemies drop 35 % fewer materials during a horde
	}),

	-- Our tuning on every level: enemy HP and the number of enemies the spawn groups bring, before the level and the
	-- sliders (1 = as configured; the B11 owner test only asked for weaker Brutes, see Config.Enemies)
	base = table.freeze({ enemyHp = 1, enemyCount = 1 }),

	-- Brotato's accessibility sliders (percent): they multiply with the danger level; Enemy count is our own
	sliders = table.freeze({
		enemyHp = table.freeze({ min = 25, max = 200, step = 25, default = 100, label = "Enemy HP" }),
		enemyDamage = table.freeze({ min = 25, max = 200, step = 25, default = 100, label = "Enemy damage" }),
		enemySpeed = table.freeze({ min = 25, max = 150, step = 25, default = 100, label = "Enemy speed" }),
		enemyCount = table.freeze({ min = 25, max = 200, step = 25, default = 100, label = "Enemy count" }),
	}),
	sliderOrder = table.freeze({ "enemyHp", "enemyDamage", "enemySpeed", "enemyCount" }),

	-- Endless mode (Brotato): the run goes on after wave 20 until everyone is out; reaching it counts as a win.
	-- endless wave = wave - 20; mult = 2 + max(0, (wave - 35) * 0.2); factor = w (w + 1) / 2 / 100 * mult.
	-- Enemy HP x (1 + factor * hpFactor), damage x (1 + factor), speed x (1 + min(speedCap, factor / speedDivisor)).
	endless = table.freeze({
		multBase = 2,
		multFromWave = 35,
		multPerWave = 0.2,
		hpFactor = 2.25,
		speedDivisor = 13.33,
		speedCap = 1.75,
		waveSeconds = 60, -- Brotato's wiki gives no length; the 60 s of waves 9-19 (assumption)
		bossEvery = 10, -- waves 30, 40, ... are boss waves with every boss, whatever the danger level
		bossWaveSeconds = 90, -- like wave 20 (assumption)
		championsPerBlock = 1, -- each block of 10 waves after 20 adds one champion to every elite wave
		-- after wave 20 bosses and champions drop a normal crate instead of the legendary one (Brotato)
		legendaryCrates = false,
	}),
}

return table.freeze(Difficulty)
