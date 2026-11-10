--!strict
-- Stable Charm scene overrides and allied support values; server Charm rules and client feedback read these facts.
-- Source: docs/characters/charm-source.json, installed stable PC 1.2.0.1.
return table.freeze({
	duration = 8,
	playerBodyRadius = 2.4, -- native Player Collision circle24 points
	playerBodyOffsetZ = -1.2, -- native Player Collision offset-12 points
	summonPadding = 2, -- shared EnemySim spawn-around spacing, technical existing simulation convention
	goalPrecision = 1,
	goalAttempts = 8,
	aroundRange = 15,
	aroundRandomization = 5,
	movement = {
		Brute = "Random",
		Herald = "Random",
		Mender = "Random",
		Skulker = "Random",
		Reaper = "Random",
		BroodEgg = "Random",
		Splitter = "Random",
		Spitter = "Random",
		DreadTendril = "Random",
		Thornback = "AroundTarget",
	},
	maximumPerOwner = 999,
	damageMultiplier = 3,
	bonusSpeedPoints = 100,
	endlessDivisor = 2,
	color = { 155, 198, 221 },
	excludedKinds = { Tree = true, Looter = true },
	healer = table.freeze({ radius = 20.0639, base = 1, perWave = 0.5 }),
	buffer = table.freeze({
		radius = 30.904,
		firstSeconds = 0.25,
		interval = 4,
		count = 1,
		duration = 5,
		playerMaxHp = 20,
		playerSpeed = 20,
		playerAttackSpeed = 20,
		structureDamage = 20,
		structureRange = 20,
		structureAttackSpeed = 20,
	}),
})
