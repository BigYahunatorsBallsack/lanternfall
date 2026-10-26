--!strict
-- Weapon records (DESIGN.md section 6). Read by the weapon framework (WeaponService, WeaponRenderer) and
-- UpgradeService.
--
-- `base` holds level 1 stats. `levels[n]` lists what changes when reaching level n:
--   damage    = fraction added to the damage multiplier (0.15 = +15 % of the level 1 damage)
--   count     = extra blades / projectiles / axes
--   radius    = studs added to radius
--   cooldown  = seconds added to cooldown (negative = faster)
--   duration  = seconds added to duration
--   jumps     = extra chain jumps
-- Owner bonuses (class, later passives and talents) scale damage, cooldown and radius on top (WeaponStats).
-- `behavior` names the behavior module in WeaponService/Behaviors and the visual in WeaponRenderer/Visuals.
-- A weapon without a behavior module exists only as data and cannot be given to players yet (WP8).
-- Values marked "assumption" are not specified in DESIGN.md; tuned by feel in WP5, balanced in WP7.

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
			radius = 7, -- studs from your center to the blade tips
			bladeInnerRadius = 2, -- studs; blades reach from here to `radius`, so enemies touching you get hit (assumption)
			bladeWidth = 1, -- studs, hit width of a blade (assumption)
			hitCooldownPerEnemy = 0.5, -- seconds before the same enemy can be hit again
			rotationSpeed = 180, -- degrees/s (assumption)
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
			count = 1, -- bolts per shot, each at a different enemy if there are enough in range
			pierce = 1, -- enemies a bolt flies through; it stops at the next one
			projectileSpeed = 60, -- studs/s (assumption)
			projectileRadius = 0.5, -- studs, hit size of a bolt (assumption)
			range = 40, -- studs; enemies further away are not targeted, bolts vanish after this (assumption)
			spreadDegrees = 12, -- extra bolts without an own target fan out around the nearest by this (assumption)
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
			cooldown = 3.0, -- waits for an enemy in the radius once ready
			radius = 10,
			knockback = 3, -- studs enemies are pushed away, divided by their mass above 1 (assumption)
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
