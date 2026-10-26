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
-- A weapon without a behavior module exists only as data and cannot be given to players.
-- Values marked "assumption" are not specified in DESIGN.md; tuned by feel in WP5 and WP8, balanced in WP7.

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
	countName: string?, -- what `count` counts, for level-up cards ("+1 blade"); weapons without `count` leave it out
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
		countName = "blade",
		behavior = "OrbitBlades",
		targeting = "Orbit",
		base = {
			damage = 15, -- WP7: was 12; kills a Shadeling with one hit until minute 2 (balance sim)
			count = 2,
			radius = 7, -- studs from your center to the blade tips
			bladeInnerRadius = 2, -- studs; blades reach from here to `radius`, so enemies touching you get hit (assumption)
			bladeWidth = 1, -- studs, hit width of a blade (assumption)
			hitCooldownPerEnemy = 0.5, -- seconds before the same enemy can be hit again
			rotationSpeed = 240, -- degrees/s (assumption; WP7: was 180, blades come around more often)
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
		countName = "bolt",
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
			cooldown = 2.0, -- waits for an enemy in range once ready
			jumps = 3, -- enemies the lightning hits in total, the first one included
			range = 25, -- studs; the first enemy must be this close (assumption)
			jumpRange = 12, -- studs from one hit enemy to the next (assumption)
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
			damage = 8, -- per tick to every enemy on the trail
			tickInterval = 0.5, -- seconds; an enemy standing on several patches is still hit once per tick
			duration = 2, -- seconds a patch lies
			radius = 2.5, -- studs, size of one thorn patch (assumption)
			dropSpacing = 2, -- studs you move before the next patch is dropped (assumption)
			maxPatches = 40, -- the oldest patch goes first beyond this (assumption, ~4 s of running at L5)
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
		countName = "axe",
		behavior = "BoomerangAxe",
		targeting = "Nearest",
		base = {
			damage = 25,
			cooldown = 1.6, -- starts with the throw; waits for an enemy in range once ready
			count = 1, -- axes per throw, each at a different enemy if there are enough in range
			pierce = -1, -- -1 = unlimited; an axe hits each enemy once on the way out and once on the way back
			range = 20, -- studs it flies out before turning; enemies further away are not targeted (assumption)
			projectileSpeed = 40, -- studs/s, out and back (assumption)
			projectileRadius = 1.2, -- studs, hit size of an axe (assumption)
			catchRadius = 2, -- studs; the axe is gone once it is this close to you again (assumption)
			maxFlightSeconds = 3, -- an axe that cannot catch up with you vanishes after this (assumption)
			spreadDegrees = 20, -- extra axes without an own target fan out around the nearest by this (assumption)
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
