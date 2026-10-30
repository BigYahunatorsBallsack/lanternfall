--!strict
-- Weapon records (DESIGN.md section 6). Read by the weapon framework (WeaponService, WeaponRenderer) and
-- UpgradeService.
--
-- `base` holds tier I stats. `tiers[n]` lists what changes when reaching tier n (Brotato's tiers I-IV since B3, before
-- levels 1-5; two equal weapons of the same tier merge into the next one, DESIGN.md section 6):
--   damage    = fraction added to the damage multiplier (0.15 = +15 % of the tier I damage)
--   count     = extra blades / projectiles / axes
--   radius    = studs added to radius
--   cooldown  = seconds added to cooldown (negative = faster)
--   duration  = seconds added to duration
--   jumps     = extra chain jumps
--   any other base stat (critChance, lifeSteal, ...) = added to it
-- The owner's stats (Config.Stats, since B2) come on top (WeaponStats): `scaling` adds that share of a stat to the
-- damage (Brotato: "20 (+80 % Melee)"; any stat, several at once), Damage %, Attack Speed and Crit Chance work on
-- every weapon, Range lengthens the stats in `rangeKeys` (melee weapons get only part of it).
-- Since B5 (Brotato's combat, rules in Config.Combat) every weapon also has:
--   kind        "Melee" or "Ranged" (Range reaches melee weapons only in part)
--   classes     1-2 weapon classes (Config.WeaponClasses; set bonuses, the shop's class pool)
--   critChance  chance per hit (0.03 = 3 %) before the Crit Chance stat; critDamage the crit multiplier (x1.5-x4)
--   lifeSteal   own life steal chance per hit (0.03 = 3 %) on top of the Life Steal stat (optional)
--   knockback   Brotato points (Config.Combat.knockback), plus the Knockback stat; 0 = none
-- and optionally: pierce (enemies a projectile flies through, -1 = all) with pierceFalloff (default
-- Config.Combat.piercing), bounce (projectile bounces; the Bounce stat adds), slow + slowSeconds (share of their speed
-- hit enemies lose and for how long), burnDamage + burnTicks (+ burnChance, burnSpread: a burn per hit, scaling with
-- 100 % Elemental Damage like Brotato's), explosionRadius + explosionDamage (a blast around every hit enemy).
-- `behavior` names the behavior module in WeaponService/Behaviors and the visual in WeaponRenderer/Visuals.
-- A weapon without a behavior module exists only as data and cannot be given to players.
-- Values marked "assumption" are not specified in DESIGN.md; tuned by feel in WP5 and WP8, balanced in WP7.

export type TierDelta = {
	damage: number?,
	count: number?,
	radius: number?,
	cooldown: number?,
	duration: number?,
	jumps: number?,
	lifeSteal: number?, -- B5: own life steal added
	critChance: number?,
	critDamage: number?,
	knockback: number?,
}

export type WeaponKind = "Melee" | "Ranged"

export type Weapon = {
	id: string,
	displayName: string,
	description: string,
	kind: WeaponKind, -- since B5; before, `class` also named Elemental weapons
	classes: { string }, -- keys in Config.WeaponClasses (B5)
	scaling: { [string]: number }, -- stat id -> share added to the damage (1 = 100 %)
	rangeKeys: { string }, -- stats that grow with the Range stat (studs)
	countName: string?, -- what `count` counts, for shop offers ("+1 blade"); weapons without `count` leave it out
	behavior: string,
	targeting: "Orbit" | "Nearest" | "Self" | "Chain" | "Trail" | "Random",
	base: { [string]: number },
	tiers: { TierDelta }, -- one entry per tier (Config.Player.maxWeaponTier), the first one empty
}

local Weapons: { [string]: Weapon } = {
	OrbitBlades = {
		id = "OrbitBlades",
		displayName = "Orbit Blades",
		description = "Blades circle around you.",
		countName = "blade",
		kind = "Melee",
		classes = { "Edge", "Spectral" },
		scaling = { meleeDamage = 1 },
		rangeKeys = { "radius" },
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
			critChance = 0.08, -- B5, like Brotato's quick blades
			critDamage = 2,
			knockback = 2,
			lifeSteal = 0,
		},
		tiers = {
			{},
			{ damage = 0.2, count = 1 },
			{ damage = 0.3, count = 1, lifeSteal = 0.03 }, -- B5: own life steal from tier III (like Brotato's saws)
			{ damage = 0.6, lifeSteal = 0.03 },
		},
	},
	SparkBolt = {
		id = "SparkBolt",
		displayName = "Spark Bolt",
		description = "Fires at the nearest enemy, pierces 1.",
		countName = "bolt",
		kind = "Ranged",
		classes = { "Arcane", "Keen" },
		scaling = { rangedDamage = 1 },
		rangeKeys = { "range" },
		behavior = "SparkBolt",
		targeting = "Nearest",
		base = {
			damage = 15,
			cooldown = 0.9,
			count = 1, -- bolts per shot, each at a different enemy if there are enough in range
			pierce = 1, -- enemies a bolt flies through (each 50 % less, Config.Combat.piercing); it stops at the next one
			bounce = 0, -- the Bounce stat adds bounces (B5)
			projectileSpeed = 60, -- studs/s (assumption)
			projectileRadius = 0.5, -- studs, hit size of a bolt (assumption)
			range = 40, -- studs; enemies further away are not targeted, bolts vanish after this (assumption)
			spreadDegrees = 12, -- extra bolts without an own target fan out around the nearest by this (assumption)
			knockback = 8, -- B5: Brotato points like a crossbow (before 0.8 studs along the bolt)
			critChance = 0.2, -- B5: a precise weapon, many small crits (like Brotato's crossbow)
			critDamage = 1.5,
		},
		tiers = {
			{},
			{ count = 1 },
			{ damage = 0.4 },
			{ damage = 0.5, cooldown = -0.15 },
		},
	},
	Shockwave = {
		id = "Shockwave",
		displayName = "Shockwave",
		description = "A blast around you, pushes enemies away.",
		kind = "Melee",
		classes = { "Bludgeon", "Colossal" },
		scaling = { meleeDamage = 1, armor = 0.5 }, -- B5: heavy weapons in Brotato also grow with Armor
		rangeKeys = { "radius" },
		behavior = "Shockwave",
		targeting = "Self",
		base = {
			damage = 20,
			cooldown = 3.0, -- waits for an enemy in the radius once ready
			radius = 10,
			knockback = 30, -- B5: Brotato points like a hammer (before 3 studs)
			critChance = 0.03,
			critDamage = 1.75,
		},
		tiers = {
			{},
			{ damage = 0.3, radius = 2, cooldown = -0.3 },
			{ damage = 0.4, radius = 2, cooldown = -0.3 },
			{ damage = 0.6, radius = 3, cooldown = -0.4 },
		},
	},
	ChainLightning = {
		id = "ChainLightning",
		displayName = "Chain Lightning",
		description = "Lightning jumps between enemies.",
		kind = "Ranged",
		classes = { "Arcane", "Keen" },
		scaling = { elementalDamage = 1 },
		rangeKeys = { "range", "jumpRange" },
		behavior = "ChainLightning",
		targeting = "Chain",
		base = {
			damage = 18,
			cooldown = 2.0, -- waits for an enemy in range once ready
			jumps = 3, -- enemies the lightning hits in total, the first one included
			range = 25, -- studs; the first enemy must be this close (assumption)
			jumpRange = 12, -- studs from one hit enemy to the next (assumption); the Bounce stat adds jumps (B5)
			critChance = 0.03,
			critDamage = 2,
			knockback = 0,
		},
		tiers = {
			{},
			{ jumps = 1, damage = 0.3 },
			{ jumps = 1, damage = 0.3 },
			{ jumps = 1, damage = 0.6 },
		},
	},
	ThornTrail = {
		id = "ThornTrail",
		displayName = "Thorn Trail",
		description = "Leaves thorns behind you that slow enemies.",
		kind = "Melee",
		classes = { "Primal", "Arcane" },
		scaling = { elementalDamage = 0.8, meleeDamage = 0.5 }, -- B5: mixed like Brotato's torch (before 100 % Elemental)
		rangeKeys = {},
		behavior = "ThornTrail",
		targeting = "Trail",
		base = {
			damage = 8, -- per tick to every enemy on the trail
			tickInterval = 0.5, -- seconds; an enemy standing on several patches is still hit once per tick
			duration = 2, -- seconds a patch lies
			radius = 2.5, -- studs, size of one thorn patch (assumption)
			dropSpacing = 2, -- studs you move before the next patch is dropped (assumption)
			maxPatches = 40, -- the oldest patch goes first beyond this (assumption, ~4 s of running at L5)
			slow = 0.3, -- B5: enemies hit lose this share of their speed (assumption) ...
			slowSeconds = 0.6, -- ... for this long, so they stay slow while they stand on thorns
			critChance = 0, -- like Brotato's torch: no crits without Crit Chance
			critDamage = 1.5,
			knockback = 0,
		},
		tiers = {
			{},
			{ duration = 0.5, damage = 0.4 },
			{ duration = 0.5, damage = 0.5 },
			{ duration = 1, damage = 0.8 },
		},
	},
	BoomerangAxe = {
		id = "BoomerangAxe",
		displayName = "Boomerang Axe",
		description = "Flies out and back, pierces everything.",
		countName = "axe",
		kind = "Ranged",
		classes = { "Edge", "Primal" },
		scaling = { rangedDamage = 0.8, meleeDamage = 0.5 }, -- B5: a thrown blade (before 100 % Ranged)
		rangeKeys = { "range" },
		behavior = "BoomerangAxe",
		targeting = "Nearest",
		base = {
			damage = 25,
			cooldown = 1.6, -- starts with the throw; waits for an enemy in range once ready
			count = 1, -- axes per throw, each at a different enemy if there are enough in range
			pierce = -1, -- -1 = unlimited; an axe hits each enemy once on the way out and once on the way back
			pierceFalloff = 0, -- B5: no damage lost per pierce (like Brotato's crossbow)
			range = 20, -- studs it flies out before turning; enemies further away are not targeted (assumption)
			projectileSpeed = 40, -- studs/s, out and back (assumption)
			projectileRadius = 1.2, -- studs, hit size of an axe (assumption)
			catchRadius = 2, -- studs; the axe is gone once it is this close to you again (assumption)
			maxFlightSeconds = 3, -- an axe that cannot catch up with you vanishes after this (assumption)
			spreadDegrees = 20, -- extra axes without an own target fan out around the nearest by this (assumption)
			knockback = 15, -- B5: Brotato points (before 1.5 studs along the flight)
			critChance = 0.05, -- B5: rare but heavy crits
			critDamage = 2.5,
		},
		tiers = {
			{},
			{ damage = 0.3, cooldown = -0.2 },
			{ count = 1 },
			{ damage = 0.4, cooldown = -0.2 },
		},
	},
}

return table.freeze(Weapons)
