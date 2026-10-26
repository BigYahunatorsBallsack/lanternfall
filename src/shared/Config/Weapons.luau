--!strict
-- Weapon records (DESIGN.md section 6). Read by the weapon framework and UpgradeService.
--
-- `base` holds level 1 stats. `levels[n]` lists what changes when reaching level n:
--   damage    = multiplier added to damage (0.15 = +15 %)
--   count     = extra blades / projectiles / axes
--   radius    = studs added to radius
--   cooldown  = seconds added to cooldown (negative = faster)
--   duration  = seconds added to duration
--   jumps     = extra chain jumps
-- `behavior` names the behavior module (one module per weapon, added in WP5).
-- Values marked "assumption" are not specified in DESIGN.md yet and get tuned in WP5.

export type LevelDelta = {
	damage: number?,
	count: number?,
	radius: number?,
	cooldown: number?,
	duration: number?,
	jumps: number?,
}

export type Weapon = {
	id: string,
	displayName: string,
	description: string,
	behavior: string,
	targeting: "Orbit" | "Nearest" | "Self" | "Chain" | "Trail" | "Random",
	base: { [string]: number },
	levels: { LevelDelta },
}

local Weapons: { [string]: Weapon } = {
	OrbitBlades = {
		id = "OrbitBlades",
		displayName = "Orbit Blades",
		description = "Blades circle around you.",
		behavior = "OrbitBlades",
		targeting = "Orbit",
		base = {
			damage = 12,
			count = 2,
			radius = 7,
			hitCooldownPerEnemy = 0.5,
			rotationSpeed = 180, -- degrees/s, assumption
		},
		levels = {
			{},
			{ damage = 0.15 },
			{ count = 1 },
			{ damage = 0.15 },
			{ count = 1 },
		},
	},
	SparkBolt = {
		id = "SparkBolt",
		displayName = "Spark Bolt",
		description = "Fires at the nearest enemy, pierces 1.",
		behavior = "SparkBolt",
		targeting = "Nearest",
		base = {
			damage = 15,
			cooldown = 0.9,
			count = 1,
			pierce = 1,
			projectileSpeed = 60, -- studs/s, assumption
			range = 40, -- studs, assumption
		},
		levels = {
			{},
			{ count = 1 },
			{ damage = 0.2 },
			{ count = 1 },
			{ damage = 0.2 },
		},
	},
	Shockwave = {
		id = "Shockwave",
		displayName = "Shockwave",
		description = "A blast around you.",
		behavior = "Shockwave",
		targeting = "Self",
		base = {
			damage = 20,
			cooldown = 3.0,
			radius = 10,
		},
		levels = {
			{},
			{ radius = 2, cooldown = -0.3 },
			{ radius = 2, cooldown = -0.3 },
			{ radius = 2, cooldown = -0.3 },
			{ radius = 2, cooldown = -0.3 },
		},
	},
	ChainLightning = {
		id = "ChainLightning",
		displayName = "Chain Lightning",
		description = "Lightning jumps between enemies.",
		behavior = "ChainLightning",
		targeting = "Chain",
		base = {
			damage = 18,
			cooldown = 2.0,
			jumps = 3,
			jumpRange = 12, -- studs, assumption
		},
		levels = {
			{},
			{ jumps = 1, damage = 0.15 },
			{ jumps = 1, damage = 0.15 },
			{ jumps = 1, damage = 0.15 },
			{ jumps = 1, damage = 0.15 },
		},
	},
	ThornTrail = {
		id = "ThornTrail",
		displayName = "Thorn Trail",
		description = "Leaves thorns behind you.",
		behavior = "ThornTrail",
		targeting = "Trail",
		base = {
			damage = 8,
			tickInterval = 0.5,
			duration = 2,
		},
		levels = {
			{},
			{ duration = 0.5, damage = 0.2 },
			{ duration = 0.5, damage = 0.2 },
			{ duration = 0.5, damage = 0.2 },
			{ duration = 0.5, damage = 0.2 },
		},
	},
	BoomerangAxe = {
		id = "BoomerangAxe",
		displayName = "Boomerang Axe",
		description = "Flies out and back, pierces everything.",
		behavior = "BoomerangAxe",
		targeting = "Nearest",
		base = {
			damage = 25,
			cooldown = 1.6,
			count = 1,
			pierce = -1, -- -1 = unlimited
			range = 20, -- studs, assumption
			projectileSpeed = 40, -- studs/s, assumption
		},
		levels = {
			{},
			{ damage = 0.15 },
			{ count = 1 },
			{ damage = 0.15 },
			{ count = 1 },
		},
	},
}

return table.freeze(Weapons)
