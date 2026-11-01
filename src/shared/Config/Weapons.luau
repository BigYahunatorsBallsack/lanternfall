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
	[string]: number,
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
	structureKinds: { string }?,
	structureIntervals: { number }?,
	id: string,
	minTier: number?,
	tierScaling: { { [string]: number } }?,
	heldStats: { { [string]: number } }?,
	killGainStat: string?,
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
		scaling = { meleeDamage = 0.6 }, -- playtest after Paket 24: was 1 (many hits per second)
		rangeKeys = { "radius" },
		behavior = "OrbitBlades",
		targeting = "Orbit",
		base = {
			damage = 6, -- WP7: 12 -> 15; playtest after Paket 24: 15 -> 6, it out-damaged every other weapon by far
			count = 2,
			radius = 7, -- studs from your center to the blade tips
			bladeInnerRadius = 2, -- studs; blades reach from here to `radius`, so enemies touching you get hit (assumption)
			bladeWidth = 1, -- studs, hit width of a blade (assumption)
			hitCooldownPerEnemy = 0.6, -- seconds before the same enemy is hit again (0.5 until the playtest after Paket 24)
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
			damage = 13, -- playtest after Paket 24: evened out, was 15
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
			damage = 15, -- playtest after Paket 24: evened out, was 20
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
		-- B5: mixed like Brotato's torch (before 100 % Elemental); playtest after Paket 24: Elemental 0.8 -> 0.5
		scaling = { elementalDamage = 0.5, meleeDamage = 0.5 },
		rangeKeys = {},
		behavior = "ThornTrail",
		targeting = "Trail",
		base = {
			damage = 6, -- per tick to every enemy on the trail; playtest after Paket 24: was 8
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
			damage = 15, -- playtest after Paket 24: evened out, was 25
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

-- B7: world dimensions, projectile speeds, spread and slow parameters are Roblox adaptation assumptions.
Weapons.BrassKnuckles = {
	id = "BrassKnuckles",
	displayName = "Brass Knuckles",
	description = "Thrusts through enemies in front.",
	kind = "Melee",
	classes = { "Brawl" },
	scaling = { meleeDamage = 1 },
	tierScaling = { { meleeDamage = 1 }, { meleeDamage = 1 }, { meleeDamage = 1 }, { meleeDamage = 1 } },
	rangeKeys = { "range" },
	behavior = "BrassKnuckles",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 8.0,
		cooldown = 0.78,
		range = 15.0,
		critDamage = 1.5,
		critChance = 0.01,
		knockback = 15.0,
		lifeSteal = 0.0,
		width = 1.2,
		sweepDegrees = 120,
		attackSeconds = 0.18,
		meleeMode = 0,
	},
	tiers = {
		{},
		{ damage = 1.0, cooldown = -0.05 },
		{ damage = 2.0, cooldown = -0.04 },
		{ damage = 4.0, cooldown = -0.1 },
	},
}
Weapons.RitualDirk = {
	id = "RitualDirk",
	displayName = "Ritual Dirk",
	description = "Thrusts through enemies in front.",
	kind = "Melee",
	classes = { "Keen" },
	scaling = { meleeDamage = 0.8 },
	tierScaling = { { meleeDamage = 0.8 }, { meleeDamage = 0.8 }, { meleeDamage = 0.8 }, { meleeDamage = 0.8 } },
	rangeKeys = { "range" },
	behavior = "RitualDirk",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 9.0,
		cooldown = 1.01,
		range = 15.0,
		critDamage = 2.5,
		critChance = 0.2,
		knockback = 2.0,
		lifeSteal = 0.0,
		width = 1.2,
		sweepDegrees = 120,
		attackSeconds = 0.18,
		meleeMode = 0,
	},
	tiers = {
		{},
		{ damage = 0.44444444, cooldown = -0.08, critDamage = 0.5, critChance = 0.1 },
		{ damage = 0.55555556, cooldown = -0.07, critDamage = 0.5, critChance = 0.1 },
		{ damage = 0.77777778, cooldown = -0.08, critDamage = 0.5, critChance = 0.1 },
	},
}
Weapons.LamplighterPike = {
	id = "LamplighterPike",
	displayName = "Lamplighter Pike",
	description = "Thrusts through enemies in front.",
	kind = "Melee",
	classes = { "Primal" },
	scaling = { meleeDamage = 1 },
	tierScaling = { { meleeDamage = 1 }, { meleeDamage = 1 }, { meleeDamage = 1 }, { meleeDamage = 1 } },
	rangeKeys = { "range" },
	behavior = "LamplighterPike",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 15.0,
		cooldown = 1.52,
		range = 35.0,
		critDamage = 2.0,
		critChance = 0.03,
		knockback = 0.0,
		lifeSteal = 0.0,
		width = 1.2,
		sweepDegrees = 120,
		attackSeconds = 0.18,
		meleeMode = 0,
	},
	tiers = {
		{},
		{ damage = 0.66666667, cooldown = -0.12, range = 2.5 },
		{ damage = 1.0, cooldown = -0.12, range = 2.5 },
		{ damage = 1.33333333, cooldown = -0.04, range = 10.0 },
	},
}
Weapons.DuskSabre = {
	id = "DuskSabre",
	displayName = "Dusk Sabre",
	description = "Alternates thrusts and sweeps.",
	kind = "Melee",
	classes = { "Edge", "Knightly" },
	scaling = { meleeDamage = 1 },
	tierScaling = { { meleeDamage = 1 }, { meleeDamage = 1 }, { meleeDamage = 1 }, { meleeDamage = 1 } },
	rangeKeys = { "range" },
	behavior = "DuskSabre",
	targeting = "Nearest",
	minTier = 2,
	base = {
		damage = 30.0,
		cooldown = 1.28,
		range = 20.0,
		critDamage = 2.0,
		critChance = 0.03,
		knockback = 5.0,
		lifeSteal = 0.0,
		width = 1.2,
		sweepDegrees = 120,
		attackSeconds = 0.18,
		meleeMode = 2,
	},
	tiers = { {}, {}, { damage = 0.5, cooldown = -0.15 }, { damage = 0.66666667, cooldown = -0.15 } },
}
Weapons.Gravestone = {
	id = "Gravestone",
	displayName = "Gravestone",
	description = "Thrusts through enemies in front. Grants Armor and HP at higher tiers.",
	kind = "Melee",
	classes = { "Primal", "Bludgeon" },
	scaling = { meleeDamage = 1 },
	tierScaling = { { meleeDamage = 1 }, { meleeDamage = 1 }, { meleeDamage = 1 }, { meleeDamage = 1 } },
	rangeKeys = { "range" },
	behavior = "Gravestone",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 20.0,
		cooldown = 1.68,
		range = 15.0,
		critDamage = 1.5,
		critChance = 0.1,
		knockback = 5.0,
		lifeSteal = 0.0,
		width = 1.2,
		sweepDegrees = 120,
		attackSeconds = 0.18,
		meleeMode = 0,
	},
	tiers = {
		{},
		{ damage = 0.75, cooldown = -0.07, critChance = 0.05 },
		{ damage = 0.75, cooldown = -0.08, critChance = 0.05 },
		{ damage = 1.0, cooldown = -0.07, critChance = 0.05 },
	},
	heldStats = { {}, { armor = 1 }, { armor = 1, maxHp = 20 }, { armor = 2, maxHp = 20 } },
}
Weapons.TithePalm = {
	id = "TithePalm",
	displayName = "Tithe Palm",
	description = "Thrusts through enemies in front. Grants 3/6/12/25 Harvesting while held.",
	kind = "Melee",
	classes = { "Brawl", "Steward" },
	scaling = { meleeDamage = 0.5 },
	tierScaling = { { meleeDamage = 0.5 }, { meleeDamage = 0.5 }, { meleeDamage = 0.5 }, { meleeDamage = 0.5 } },
	rangeKeys = { "range" },
	behavior = "TithePalm",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 1.0,
		cooldown = 1.01,
		range = 15.0,
		critDamage = 1.5,
		critChance = 0.01,
		knockback = 30.0,
		lifeSteal = 0.0,
		width = 1.2,
		sweepDegrees = 120,
		attackSeconds = 0.18,
		meleeMode = 0,
	},
	tiers = { {}, { cooldown = -0.08 }, { cooldown = -0.07 }, { cooldown = -0.15 } },
	heldStats = { { harvesting = 3 }, { harvesting = 6 }, { harvesting = 12 }, { harvesting = 25 } },
}
Weapons.WraithHatchet = {
	id = "WraithHatchet",
	displayName = "Wraith Hatchet",
	description = "Sweeps through a wide arc. Every 20/18/16/12 kills this wave: permanent +1% Damage.",
	kind = "Melee",
	classes = { "Spectral" },
	scaling = { meleeDamage = 1 },
	tierScaling = { { meleeDamage = 1 }, { meleeDamage = 1 }, { meleeDamage = 1 }, { meleeDamage = 1 } },
	rangeKeys = { "range" },
	behavior = "WraithHatchet",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 14.0, -- playtest after Paket 24: weak at the start, was 12.0
		cooldown = 1.73,
		range = 20.0,
		critDamage = 2.0,
		critChance = 0.03,
		knockback = 2.0,
		lifeSteal = 0.0,
		width = 1.2,
		sweepDegrees = 120,
		attackSeconds = 0.18,
		meleeMode = 1,
		killsPerGain = 20,
	},
	tiers = {
		{},
		{ damage = 0.5, cooldown = -0.07, killsPerGain = -2 },
		{ damage = 0.5, cooldown = -0.08, killsPerGain = -2 },
		{ damage = 1.33333333, cooldown = -0.07, killsPerGain = -4 },
	},
	killGainStat = "damage",
}
Weapons.SpiritFlint = {
	id = "SpiritFlint",
	displayName = "Spirit Flint",
	description = "Sweeps through a wide arc. Every 20/18/16/12 kills this wave: permanent +1% Attack Speed.",
	kind = "Melee",
	classes = { "Spectral" },
	scaling = { meleeDamage = 1 },
	tierScaling = { { meleeDamage = 1 }, { meleeDamage = 1 }, { meleeDamage = 1 }, { meleeDamage = 1 } },
	rangeKeys = { "range" },
	behavior = "SpiritFlint",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 8.0, -- playtest after Paket 24: weak at the start, was 6.0
		cooldown = 1.23,
		range = 17.0,
		critDamage = 2.0,
		critChance = 0.03,
		knockback = 2.0,
		lifeSteal = 0.0,
		width = 1.2,
		sweepDegrees = 120,
		attackSeconds = 0.18,
		meleeMode = 1,
		killsPerGain = 20,
	},
	tiers = {
		{},
		{ damage = 0.5, cooldown = -0.06, range = 1.0, killsPerGain = -2 },
		{ damage = 0.5, cooldown = -0.07, range = 1.0, killsPerGain = -2 },
		{ damage = 1.33333333, cooldown = -0.06, range = 1.0, killsPerGain = -4 },
	},
	killGainStat = "attackSpeed",
}
Weapons.WatchmanPistol = {
	id = "WatchmanPistol",
	displayName = "Watchman Pistol",
	description = "Fires at enemies in range.",
	kind = "Ranged",
	classes = { "Longshot" },
	scaling = { rangedDamage = 1 },
	tierScaling = { { rangedDamage = 1 }, { rangedDamage = 1 }, { rangedDamage = 1 }, { rangedDamage = 1 } },
	rangeKeys = { "range" },
	behavior = "WatchmanPistol",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 12.0,
		cooldown = 1.2,
		range = 40.0,
		critDamage = 2.0,
		critChance = 0.1,
		knockback = 15.0,
		lifeSteal = 0.0,
		count = 1,
		pierce = 1,
		bounce = 0,
		projectileSpeed = 60,
		projectileRadius = 0.5,
		spreadDegrees = 8,
		pierceFalloff = 0.5,
	},
	tiers = {
		{},
		{ damage = 0.66666667, cooldown = -0.08, critChance = 0.05 },
		{ damage = 0.83333333, cooldown = -0.09, critChance = 0.05 },
		{ damage = 1.66666667, cooldown = -0.16, critChance = 0.05 },
	},
	countName = "projectile",
}
Weapons.RattleRepeater = {
	id = "RattleRepeater",
	displayName = "Rattle Repeater",
	description = "Fires at enemies in range.",
	kind = "Ranged",
	classes = { "Longshot" },
	-- playtest after Paket 24: far too strong (6 hits per second, each with half the Ranged Damage): damage 3 -> 2.5,
	-- scaling 0.5-0.8 -> 0.25-0.4
	scaling = { rangedDamage = 0.25 },
	tierScaling = { { rangedDamage = 0.25 }, { rangedDamage = 0.3 }, { rangedDamage = 0.35 }, { rangedDamage = 0.4 } },
	rangeKeys = { "range" },
	behavior = "RattleRepeater",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 2.5,
		cooldown = 0.17,
		range = 40.0,
		critDamage = 1.5,
		critChance = 0.01,
		knockback = 0.0,
		lifeSteal = 0.0,
		count = 1,
		pierce = 0,
		bounce = 0,
		projectileSpeed = 60,
		projectileRadius = 0.5,
		spreadDegrees = 8,
	},
	tiers = { {}, { damage = 0.33333333 }, { damage = 0.33333333 }, { damage = 1.0, cooldown = -0.02 } },
	countName = "projectile",
}
Weapons.ScatterBell = {
	id = "ScatterBell",
	displayName = "Scatter Bell",
	description = "A piercing spread of 4/4/4/6 pellets.",
	kind = "Ranged",
	classes = { "Longshot" },
	scaling = { rangedDamage = 0.8 },
	tierScaling = { { rangedDamage = 0.8 }, { rangedDamage = 0.85 }, { rangedDamage = 0.9 }, { rangedDamage = 1 } },
	rangeKeys = { "range" },
	behavior = "ScatterBell",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 4.0, -- playtest after Paket 24: weak at the start, was 3.0
		cooldown = 1.37,
		range = 35.0,
		critDamage = 2.0,
		critChance = 0.03,
		knockback = 8.0,
		lifeSteal = 0.0,
		count = 4,
		pierce = 2,
		bounce = 0,
		projectileSpeed = 60,
		projectileRadius = 0.5,
		spreadDegrees = 8,
		pierceFalloff = 0.3,
		fan = 1,
	},
	tiers = { {}, { damage = 1.0, cooldown = -0.09 }, { damage = 1.0, cooldown = -0.08 }, { count = 2, pierce = 1 } },
	countName = "projectile",
}
Weapons.ShrapnelOrgan = {
	id = "ShrapnelOrgan",
	displayName = "Shrapnel Organ",
	description = "Pierces 3; 50/65/80/100% chance to explode on hit.",
	kind = "Ranged",
	classes = { "Longshot", "Volatile" },
	scaling = { rangedDamage = 0.5 },
	tierScaling = { { rangedDamage = 0.5 }, { rangedDamage = 0.5 }, { rangedDamage = 0.5 }, { rangedDamage = 0.5 } },
	rangeKeys = { "range" },
	behavior = "ShrapnelOrgan",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 8.0, -- playtest after Paket 24: weak at the start, was 5.0
		cooldown = 1.3,
		range = 45.0,
		critDamage = 2.0,
		critChance = 0.03,
		knockback = 0.0,
		lifeSteal = 0.0,
		count = 1,
		pierce = 3,
		bounce = 0,
		projectileSpeed = 60,
		projectileRadius = 0.5,
		spreadDegrees = 8,
		pierceFalloff = 0,
		explosionRadius = 3,
		explosionChance = 0.5,
	},
	tiers = {
		{},
		{ damage = 1.0, cooldown = -0.08, explosionChance = 0.15 },
		{ damage = 1.0, cooldown = -0.09, explosionChance = 0.15 },
		{ damage = 2.0, cooldown = -0.08, explosionChance = 0.2 },
	},
	countName = "projectile",
}
Weapons.CinderBreath = {
	id = "CinderBreath",
	displayName = "Cinder Breath",
	description = "Piercing flames burn enemies over time.",
	kind = "Ranged",
	classes = { "Arcane", "Colossal" },
	scaling = { elementalDamage = 0.01 },
	tierScaling = {
		{ elementalDamage = 0.01 },
		{ elementalDamage = 0.01 },
		{ elementalDamage = 0.01 },
		{ elementalDamage = 0.01 },
	},
	rangeKeys = { "range" },
	behavior = "CinderBreath",
	targeting = "Nearest",
	minTier = 2,
	base = {
		damage = 1.0,
		cooldown = 0.12,
		range = 25.0,
		critDamage = 2.0,
		critChance = 0.0,
		knockback = 0.0,
		lifeSteal = 0.0,
		count = 1,
		pierce = 99,
		bounce = 0,
		projectileSpeed = 60,
		projectileRadius = 0.5,
		spreadDegrees = 8,
		pierceFalloff = 0,
		burnDamage = 1,
		burnTicks = 3,
	},
	tiers = {
		{},
		{},
		{ range = 5.0, burnDamage = 2, burnTicks = 2 },
		{ cooldown = -0.03, range = 10.0, burnDamage = 2, burnTicks = 3 },
	},
	countName = "projectile",
}
Weapons.GalvanicFork = {
	id = "GalvanicFork",
	displayName = "Galvanic Fork",
	description = "Projectiles slow nearby enemies.",
	kind = "Ranged",
	classes = { "Steward", "Arcane" },
	scaling = { elementalDamage = 0.8 },
	tierScaling = {
		{ elementalDamage = 0.8 },
		{ elementalDamage = 0.7 },
		{ elementalDamage = 0.6 },
		{ elementalDamage = 0.5 },
	},
	rangeKeys = { "range" },
	behavior = "GalvanicFork",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 10.0, -- playtest after Paket 24: weak at the start, was 7.0
		cooldown = 0.95,
		range = 20.0,
		critDamage = 2.0,
		critChance = 0.03,
		knockback = 0.0,
		lifeSteal = 0.0,
		count = 1,
		pierce = 0,
		bounce = 0,
		projectileSpeed = 60,
		projectileRadius = 0.5,
		spreadDegrees = 8,
		slow = 0.3,
		slowSeconds = 1,
		slowRadius = 2,
	},
	tiers = { {}, { count = 1 }, { count = 1 }, { damage = 1.0, count = 1 } },
	countName = "projectile",
}
Weapons.LeechCarbine = {
	id = "LeechCarbine",
	displayName = "Leech Carbine",
	description = "Shots with 50/55/60/65% Life Steal.",
	kind = "Ranged",
	classes = { "Remedy", "Longshot" },
	scaling = { rangedDamage = 1 },
	tierScaling = { { rangedDamage = 1 }, { rangedDamage = 1 }, { rangedDamage = 1 }, { rangedDamage = 1 } },
	rangeKeys = { "range" },
	behavior = "LeechCarbine",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 10.0,
		cooldown = 0.78,
		range = 40.0,
		critDamage = 2.0,
		critChance = 0.03,
		knockback = 0.0,
		lifeSteal = 0.5,
		count = 1,
		pierce = 0,
		bounce = 0,
		projectileSpeed = 60,
		projectileRadius = 0.5,
		spreadDegrees = 8,
	},
	tiers = {
		{},
		{ damage = 0.5, cooldown = -0.08, lifeSteal = 0.05 },
		{ damage = 0.5, cooldown = -0.08, lifeSteal = 0.05 },
		{ damage = 1.0, cooldown = -0.14, lifeSteal = 0.05 },
	},
	countName = "projectile",
}
Weapons.CathedralEngine = {
	id = "CathedralEngine",
	displayName = "Cathedral Engine",
	description = "Triple shots. Reloads after 100 volleys.",
	kind = "Ranged",
	classes = { "Dread", "Longshot" },
	scaling = { rangedDamage = 1, engineering = 1 },
	tierScaling = {
		{ rangedDamage = 1, engineering = 1 },
		{ rangedDamage = 1, engineering = 1 },
		{ rangedDamage = 1, engineering = 1 },
		{ rangedDamage = 1, engineering = 1 },
	},
	rangeKeys = { "range" },
	behavior = "CathedralEngine",
	targeting = "Nearest",
	minTier = 4,
	base = {
		damage = 2.0,
		cooldown = 0.073,
		range = 50.0,
		critDamage = 1.5,
		critChance = 0.03,
		knockback = 5.0,
		lifeSteal = 0.0,
		count = 3,
		pierce = 1,
		bounce = 0,
		projectileSpeed = 60,
		projectileRadius = 0.5,
		spreadDegrees = 8,
		magazine = 100,
		reloadSeconds = 2.04,
		fan = 1,
		pierceFalloff = 0.5,
	},
	tiers = { {}, {}, {}, {} },
	countName = "projectile",
}
Weapons.MortarLantern = {
	id = "MortarLantern",
	displayName = "Mortar Lantern",
	description = "Rockets explode on impact.",
	kind = "Ranged",
	classes = { "Colossal", "Volatile" },
	scaling = { rangedDamage = 1 },
	tierScaling = { { rangedDamage = 1 }, { rangedDamage = 1 }, { rangedDamage = 1 }, { rangedDamage = 1 } },
	rangeKeys = { "range" },
	behavior = "MortarLantern",
	targeting = "Nearest",
	minTier = 2,
	base = {
		damage = 22.0, -- playtest after Paket 24: evened out, was 30
		cooldown = 1.78,
		range = 50.0,
		critDamage = 2.0,
		critChance = 0.03,
		knockback = 15.0,
		lifeSteal = 0.0,
		count = 1,
		pierce = 0,
		bounce = 0,
		projectileSpeed = 60,
		projectileRadius = 0.5,
		spreadDegrees = 8,
		explosionRadius = 7.2,
	},
	tiers = {
		{},
		{},
		{ damage = 0.66666667, cooldown = -0.41, range = 5.0 },
		{ damage = 1.0, cooldown = -0.34, range = 5.0 },
	},
	countName = "projectile",
}
Weapons.WinterNeedle = {
	id = "WinterNeedle",
	displayName = "Winter Needle",
	description = "Pierces an enemy; precise elemental shots.",
	kind = "Ranged",
	classes = { "Keen", "Arcane" },
	scaling = { elementalDamage = 1 },
	tierScaling = { { elementalDamage = 1 }, { elementalDamage = 1 }, { elementalDamage = 1 }, { elementalDamage = 1 } },
	rangeKeys = { "range" },
	behavior = "WinterNeedle",
	targeting = "Nearest",
	minTier = 1,
	base = {
		damage = 12.0, -- playtest after Paket 24: weak at the start, was 10.0
		cooldown = 1.03,
		range = 40.0,
		critDamage = 2.0,
		critChance = 0.05,
		knockback = 5.0,
		lifeSteal = 0.0,
		count = 1,
		pierce = 1,
		pierceFalloff = 0.5,
		bounce = 0,
		projectileSpeed = 60,
		projectileRadius = 0.5,
		spreadDegrees = 8,
	},
	tiers = {
		{},
		{ damage = 1.0, cooldown = -0.08, critChance = 0.05 },
		{ damage = 1.0, cooldown = -0.08, critDamage = 0.5, critChance = 0.05 },
		{ damage = 1.0, cooldown = -0.17, critDamage = 0.5, critChance = 0.05 },
	},
	countName = "projectile",
}

Weapons.FoundryKey = {
	id = "FoundryKey",
	displayName = "Foundry Key",
	description = "Sweeps enemies. Deploys a sentry each wave; its kind improves with weapon tier.",
	kind = "Melee",
	classes = { "Artisan" },
	scaling = { meleeDamage = 1 },
	rangeKeys = { "range" },
	behavior = "FoundryKey",
	targeting = "Nearest",
	minTier = 1,
	structureKinds = { "BrassSentry", "CinderSentry", "PrismSentry", "SiegeSentry" },
	base = {
		damage = 14, -- playtest after Paket 24: weak at the start, was 12
		cooldown = 1.7,
		range = 17.5,
		critDamage = 2,
		critChance = 0.03,
		knockback = 20,
		lifeSteal = 0,
		width = 1.2,
		sweepDegrees = 120,
		attackSeconds = 0.18,
		meleeMode = 1,
	},
	tiers = {
		{},
		{ damage = 1 / 3, cooldown = -0.06 },
		{ damage = 1 / 3, cooldown = -0.09 },
		{
			damage = 1 / 3,
			cooldown = -0.06,
		},
	},
}
Weapons.RuneAwl = {
	id = "RuneAwl",
	displayName = "Rune Awl",
	description = "Thrusts enemies. Lays engineering mines every 12/9/6/3 seconds by tier.",
	kind = "Melee",
	classes = { "Artisan" },
	scaling = { meleeDamage = 0.5, engineering = 0.5 },
	rangeKeys = { "range" },
	behavior = "RuneAwl",
	targeting = "Nearest",
	minTier = 1,
	tierScaling = {
		{ meleeDamage = 0.5, engineering = 0.5 },
		{ meleeDamage = 0.5, engineering = 0.6 },
		{ meleeDamage = 0.5, engineering = 0.7 },
		{ meleeDamage = 0.5, engineering = 0.8 },
	},
	structureKinds = { "RuneMine", "RuneMine", "RuneMine", "RuneMine" },
	structureIntervals = { 12, 9, 6, 3 },
	base = {
		damage = 8,
		cooldown = 1.06,
		range = 13.5,
		critDamage = 2,
		critChance = 0.1,
		knockback = 3,
		lifeSteal = 0,
		width = 1.2,
		sweepDegrees = 120,
		attackSeconds = 0.18,
		meleeMode = 0,
	},
	tiers = {
		{},
		{ damage = 0.5, cooldown = -0.05, critChance = 0.05, critDamage = 0.15 },
		{ damage = 0.5, cooldown = -0.03, critChance = 0.05, critDamage = 0.15 },
		{ damage = 0.5, cooldown = -0.1, critChance = 0.1, critDamage = 0.2 },
	},
}

return table.freeze(Weapons)
