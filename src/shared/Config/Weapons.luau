--!strict
-- Original base-game Brotato weapon records read by WeaponService, shop and WeaponRenderer.
-- Generated from the factual catalog in assets/weapons/brotato-base; no DLC or custom weapons.
-- Range uses 0.1 studs per wiki unit; HP scaling inputs/bonuses account for this project's HP x10.

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
	brotato: boolean?,
	originalScaling: { { [string]: number } }?,
	gardenIntervals: { number }?,
	armorPerWeapon: number?,
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
	CactiClub = {
		id = "CactiClub",
		displayName = "Cacti Club",
		description = "Hits release ranged spines.",
		kind = "Melee",
		classes = { "Primal", "Colossal" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.85,
			},
			{
				meleeDamage = 0.9,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 0.8,
		},
		tierScaling = {
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.85,
			},
			{
				meleeDamage = 0.9,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "CactiClub",
		targeting = "Nearest",
		base = {
			damage = 15,
			cooldown = 1.66,
			range = 20,
			knockback = 8,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 1,
			secondaryCount = 3,
			secondaryBase = 1,
			secondaryScaling = 0.6,
			levelScaling = 0,
			secondaryRangeStuds = 40,
			secondarySpeed = 60,
			secondaryRadius = 0.5,
			secondarySlowSeconds = 1,
		},
		tiers = {
			{},
			{
				damage = 0.333333333,
				cooldown = -0.08,
				secondaryCount = 1,
				secondaryBase = 1,
				secondaryScaling = 0.1,
			},
			{
				damage = 1,
				cooldown = -0.07,
				secondaryCount = 1,
				secondaryBase = 1,
				secondaryScaling = 0.1,
			},
			{
				damage = 1.666666667,
				cooldown = -0.15,
				secondaryCount = 1,
				secondaryBase = 1,
				secondaryScaling = 0.2,
			},
		},
	},
	Chopper = {
		id = "Chopper",
		displayName = "Chopper",
		description = "Sweeps nearby enemies.",
		kind = "Melee",
		classes = { "Edge" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.5,
				maxHp = 0.15,
			},
			{
				meleeDamage = 0.5,
				maxHp = 0.2,
			},
			{
				meleeDamage = 0.5,
				maxHp = 0.25,
			},
			{
				meleeDamage = 0.5,
				maxHp = 0.3,
			},
		},
		scaling = {
			meleeDamage = 0.5,
			maxHp = 0.015,
		},
		tierScaling = {
			{
				meleeDamage = 0.5,
				maxHp = 0.015,
			},
			{
				meleeDamage = 0.5,
				maxHp = 0.02,
			},
			{
				meleeDamage = 0.5,
				maxHp = 0.025,
			},
			{
				meleeDamage = 0.5,
				maxHp = 0.03,
			},
		},
		rangeKeys = { "range" },
		behavior = "Chopper",
		targeting = "Nearest",
		base = {
			damage = 6,
			cooldown = 0.99,
			range = 13.5,
			knockback = 2,
			critDamage = 2,
			critChance = 0.1,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 1,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 1,
				range = 1.5,
				critChance = 0.05,
			},
			{
				damage = 1,
				cooldown = -0.03,
				range = 1.5,
				critChance = 0.05,
			},
			{
				damage = 2,
				cooldown = -0.07,
				range = 1.5,
				critChance = 0.05,
			},
		},
		heldStats = {
			{
				fruitHeal = 10,
			},
			{
				fruitHeal = 10,
			},
			{
				fruitHeal = 10,
			},
			{
				fruitHeal = 20,
			},
		},
	},
	OrbitBlades = {
		id = "OrbitBlades",
		displayName = "Circular Saw",
		description = "Sweeps nearby enemies.",
		kind = "Melee",
		classes = { "Edge", "Remedy" },
		minTier = 2,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "OrbitBlades",
		targeting = "Nearest",
		base = {
			damage = 10,
			cooldown = 0.72,
			range = 17.5,
			knockback = 0,
			critDamage = 2,
			critChance = 0.05,
			lifeSteal = 0.45,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 1,
			levelScaling = 0,
		},
		tiers = {
			{},
			{},
			{
				damage = 0.5,
				cooldown = -0.05,
				critChance = 0.05,
				lifeSteal = 0.05,
			},
			{
				damage = 1,
				cooldown = -0.05,
				critChance = 0.1,
				lifeSteal = 0.1,
			},
		},
	},
	Claw = {
		id = "Claw",
		displayName = "Claw",
		description = "Thrusts at nearby enemies.",
		kind = "Melee",
		classes = { "Brawl", "Keen" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				attackSpeed = 0.15,
				meleeDamage = 0.5,
			},
			{
				attackSpeed = 0.2,
				meleeDamage = 0.5,
			},
			{
				attackSpeed = 0.25,
				meleeDamage = 0.5,
			},
			{
				attackSpeed = 0.3,
				meleeDamage = 0.5,
			},
		},
		scaling = {
			attackSpeed = 0.15,
			meleeDamage = 0.5,
		},
		tierScaling = {
			{
				attackSpeed = 0.15,
				meleeDamage = 0.5,
			},
			{
				attackSpeed = 0.2,
				meleeDamage = 0.5,
			},
			{
				attackSpeed = 0.25,
				meleeDamage = 0.5,
			},
			{
				attackSpeed = 0.3,
				meleeDamage = 0.5,
			},
		},
		rangeKeys = { "range" },
		behavior = "Claw",
		targeting = "Nearest",
		base = {
			damage = 5,
			cooldown = 0.78,
			range = 15,
			knockback = 2,
			critDamage = 2,
			critChance = 0.1,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 1,
				cooldown = -0.04,
				critDamage = 0.15,
				critChance = 0.05,
			},
			{
				damage = 1,
				cooldown = -0.05,
				critDamage = 0.15,
				critChance = 0.05,
			},
			{
				damage = 2,
				cooldown = -0.08,
				critDamage = 0.2,
				critChance = 0.05,
			},
		},
	},
	Drill = {
		id = "Drill",
		displayName = "Drill",
		description = "Critical kills grant a material. Gains attack speed every 5 seconds this wave.",
		kind = "Melee",
		classes = { "Dread", "Keen" },
		minTier = 4,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
				engineering = 1,
			},
			{
				meleeDamage = 1,
				engineering = 1,
			},
			{
				meleeDamage = 1,
				engineering = 1,
			},
			{
				meleeDamage = 1,
				engineering = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
			engineering = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
				engineering = 1,
			},
			{
				meleeDamage = 1,
				engineering = 1,
			},
			{
				meleeDamage = 1,
				engineering = 1,
			},
			{
				meleeDamage = 1,
				engineering = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "Drill",
		targeting = "Nearest",
		base = {
			damage = 10,
			cooldown = 0.45,
			range = 10,
			knockback = 5,
			critDamage = 2.5,
			critChance = 0.5,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			critMaterialChance = 1,
			timedAttackSpeed = 10,
			timedSeconds = 5,
			levelScaling = 0,
		},
		tiers = { {}, {}, {}, {} },
	},
	Excalibur = {
		id = "Excalibur",
		displayName = "Excalibur",
		description = "Alternates thrusts and sweeps. -2 Armor for each held weapon.",
		kind = "Melee",
		classes = { "Dread", "Edge" },
		minTier = 4,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 2,
				maxHp = 2,
			},
			{
				meleeDamage = 2,
				maxHp = 2,
			},
			{
				meleeDamage = 2,
				maxHp = 2,
			},
			{
				meleeDamage = 2,
				maxHp = 2,
			},
		},
		scaling = {
			meleeDamage = 2,
			maxHp = 0.2,
		},
		tierScaling = {
			{
				meleeDamage = 2,
				maxHp = 0.2,
			},
			{
				meleeDamage = 2,
				maxHp = 0.2,
			},
			{
				meleeDamage = 2,
				maxHp = 0.2,
			},
			{
				meleeDamage = 2,
				maxHp = 0.2,
			},
		},
		rangeKeys = { "range" },
		behavior = "Excalibur",
		targeting = "Nearest",
		base = {
			damage = 200,
			cooldown = 0.66,
			range = 20,
			knockback = 5,
			critDamage = 2.5,
			critChance = 0.1,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 2,
			levelScaling = 0,
		},
		tiers = { {}, {}, {}, {} },
		armorPerWeapon = -2,
	},
	Quarterstaff = {
		id = "Quarterstaff",
		displayName = "Quarterstaff",
		description = "Alternates thrusts and sweeps. Grants XP Gain.",
		kind = "Melee",
		classes = { "Primal", "Knightly" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				level = 0.75,
				meleeDamage = 0.5,
			},
			{
				level = 0.85,
				meleeDamage = 0.65,
			},
			{
				level = 1,
				meleeDamage = 0.85,
			},
			{
				level = 1.25,
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 0.5,
		},
		tierScaling = {
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.65,
			},
			{
				meleeDamage = 0.85,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "Quarterstaff",
		targeting = "Nearest",
		base = {
			damage = 10,
			cooldown = 1.42,
			range = 17.5,
			knockback = 0,
			critDamage = 1.5,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 2,
			levelScaling = 0.75,
		},
		tiers = {
			{},
			{
				damage = 0.5,
				cooldown = -0.17,
				levelScaling = 0.1,
			},
			{
				damage = 0.5,
				cooldown = -0.16,
				levelScaling = 0.15,
			},
			{
				damage = 1,
				cooldown = -0.17,
				levelScaling = 0.25,
			},
		},
		heldStats = {
			{
				xpGain = 2,
			},
			{
				xpGain = 5,
			},
			{
				xpGain = 9,
			},
			{
				xpGain = 15,
			},
		},
	},
	BrassKnuckles = {
		id = "BrassKnuckles",
		displayName = "Fist",
		description = "Thrusts at nearby enemies.",
		kind = "Melee",
		classes = { "Brawl" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "BrassKnuckles",
		targeting = "Nearest",
		base = {
			damage = 8,
			cooldown = 0.78,
			range = 15,
			knockback = 15,
			critDamage = 1.5,
			critChance = 0.01,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 1,
				cooldown = -0.05,
			},
			{
				damage = 2,
				cooldown = -0.04,
			},
			{
				damage = 4,
				cooldown = -0.1,
			},
		},
	},
	FlamingBrassKnuckles = {
		id = "FlamingBrassKnuckles",
		displayName = "Flaming Brass Knuckles",
		description = "Hits apply elemental burning.",
		kind = "Melee",
		classes = { "Brawl", "Arcane" },
		minTier = 2,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "FlamingBrassKnuckles",
		targeting = "Nearest",
		base = {
			damage = 20,
			cooldown = 0.73,
			range = 15,
			knockback = 15,
			critDamage = 1.5,
			critChance = 0.01,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			burnDamage = 10,
			burnTicks = 5,
			levelScaling = 0,
		},
		tiers = {
			{},
			{},
			{
				damage = 1,
				cooldown = -0.04,
				burnDamage = 5,
				burnTicks = 1,
			},
			{
				damage = 2,
				cooldown = -0.1,
				burnDamage = 3,
				burnTicks = 1,
			},
		},
	},
	WraithHatchet = {
		id = "WraithHatchet",
		displayName = "Ghost Axe",
		description = "Weapon kills grant permanent damage each wave.",
		kind = "Melee",
		classes = { "Spectral" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "WraithHatchet",
		targeting = "Nearest",
		base = {
			damage = 12,
			cooldown = 1.73,
			range = 20,
			knockback = 2,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 1,
			killsPerGain = 20,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.5,
				cooldown = -0.07,
				killsPerGain = -2,
			},
			{
				damage = 0.5,
				cooldown = -0.08,
				killsPerGain = -2,
			},
			{
				damage = 1.333333333,
				cooldown = -0.07,
				killsPerGain = -4,
			},
		},
		killGainStat = "damage",
	},
	SpiritFlint = {
		id = "SpiritFlint",
		displayName = "Ghost Flint",
		description = "Weapon kills grant permanent attackSpeed each wave.",
		kind = "Melee",
		classes = { "Spectral" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "SpiritFlint",
		targeting = "Nearest",
		base = {
			damage = 6,
			cooldown = 1.23,
			range = 17,
			knockback = 2,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			killsPerGain = 20,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.5,
				cooldown = -0.06,
				range = 1,
				killsPerGain = -2,
			},
			{
				damage = 0.5,
				cooldown = -0.07,
				range = 1,
				killsPerGain = -2,
			},
			{
				damage = 1.333333333,
				cooldown = -0.06,
				range = 1,
				killsPerGain = -4,
			},
		},
		killGainStat = "attackSpeed",
	},
	Shockwave = {
		id = "Shockwave",
		displayName = "Hammer",
		description = "Sweeps nearby enemies.",
		kind = "Melee",
		classes = { "Bludgeon", "Colossal" },
		minTier = 2,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1.5,
			},
			{
				meleeDamage = 1.5,
			},
			{
				meleeDamage = 1.75,
			},
			{
				meleeDamage = 2,
			},
		},
		scaling = {
			meleeDamage = 1.5,
		},
		tierScaling = {
			{
				meleeDamage = 1.5,
			},
			{
				meleeDamage = 1.5,
			},
			{
				meleeDamage = 1.75,
			},
			{
				meleeDamage = 2,
			},
		},
		rangeKeys = { "range" },
		behavior = "Shockwave",
		targeting = "Nearest",
		base = {
			damage = 40,
			cooldown = 1.67,
			range = 17.5,
			knockback = 30,
			critDamage = 1.75,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 1,
			knockbackPiercing = 0.1,
			levelScaling = 0,
		},
		tiers = {
			{},
			{},
			{
				damage = 0.875,
				cooldown = -0.08,
				knockback = 10,
				knockbackPiercing = 0.05,
			},
			{
				damage = 1.125,
				cooldown = -0.09,
				knockback = 10,
				knockbackPiercing = 0.05,
			},
		},
		heldStats = {
			{
				knockback = 0,
			},
			{
				knockback = 2,
			},
			{
				knockback = 4,
			},
			{
				knockback = 6,
			},
		},
	},
	TithePalm = {
		id = "TithePalm",
		displayName = "Hand",
		description = "Thrusts at nearby enemies.",
		kind = "Melee",
		classes = { "Brawl", "Steward" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.5,
			},
		},
		scaling = {
			meleeDamage = 0.5,
		},
		tierScaling = {
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.5,
			},
		},
		rangeKeys = { "range" },
		behavior = "TithePalm",
		targeting = "Nearest",
		base = {
			damage = 1,
			cooldown = 1.01,
			range = 15,
			knockback = 30,
			critDamage = 1.5,
			critChance = 0.01,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			levelScaling = 0,
		},
		tiers = { {}, {
			cooldown = -0.08,
		}, {
			cooldown = -0.07,
		}, {
			cooldown = -0.15,
		} },
		heldStats = {
			{
				harvesting = 3,
			},
			{
				harvesting = 6,
			},
			{
				harvesting = 12,
			},
			{
				harvesting = 25,
			},
		},
	},
	Hatchet = {
		id = "Hatchet",
		displayName = "Hatchet",
		description = "Sweeps nearby enemies.",
		kind = "Melee",
		classes = { "Primal" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
				attackSpeed = 0.2,
			},
			{
				meleeDamage = 1,
				attackSpeed = 0.2,
			},
			{
				meleeDamage = 1,
				attackSpeed = 0.2,
			},
			{
				meleeDamage = 1,
				attackSpeed = 0.2,
			},
		},
		scaling = {
			meleeDamage = 1,
			attackSpeed = 0.2,
		},
		tierScaling = {
			{
				meleeDamage = 1,
				attackSpeed = 0.2,
			},
			{
				meleeDamage = 1,
				attackSpeed = 0.2,
			},
			{
				meleeDamage = 1,
				attackSpeed = 0.2,
			},
			{
				meleeDamage = 1,
				attackSpeed = 0.2,
			},
		},
		rangeKeys = { "range" },
		behavior = "Hatchet",
		targeting = "Nearest",
		base = {
			damage = 7,
			cooldown = 0.68,
			range = 12.5,
			knockback = 2,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 1,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.571428571,
				cooldown = -0.01,
			},
			{
				damage = 1.571428571,
				cooldown = -0.02,
			},
			{
				damage = 3.285714286,
				cooldown = -0.02,
			},
		},
	},
	JoustingLance = {
		id = "JoustingLance",
		displayName = "Jousting Lance",
		description = "Grants Speed. Deals less damage while standing still.",
		kind = "Melee",
		classes = { "Knightly" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.5,
				speed = 0.3,
			},
			{
				meleeDamage = 0.5,
				speed = 0.35,
			},
			{
				meleeDamage = 0.5,
				speed = 0.4,
			},
			{
				meleeDamage = 0.5,
				speed = 0.5,
			},
		},
		scaling = {
			meleeDamage = 0.5,
			speed = 0.3,
		},
		tierScaling = {
			{
				meleeDamage = 0.5,
				speed = 0.3,
			},
			{
				meleeDamage = 0.5,
				speed = 0.35,
			},
			{
				meleeDamage = 0.5,
				speed = 0.4,
			},
			{
				meleeDamage = 0.5,
				speed = 0.5,
			},
		},
		rangeKeys = { "range" },
		behavior = "JoustingLance",
		targeting = "Nearest",
		base = {
			damage = 20,
			cooldown = 1.58,
			range = 25,
			knockback = 0,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			stationaryDamage = -10,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.25,
				cooldown = -0.08,
				stationaryDamage = -5,
			},
			{
				damage = 0.25,
				cooldown = -0.08,
				stationaryDamage = -5,
			},
			{
				damage = 1,
				cooldown = -0.09,
				stationaryDamage = -5,
			},
		},
		heldStats = {
			{
				speed = 2,
			},
			{
				speed = 3,
			},
			{
				speed = 4,
			},
			{
				speed = 5,
			},
		},
	},
	RitualDirk = {
		id = "RitualDirk",
		displayName = "Knife",
		description = "Thrusts at nearby enemies.",
		kind = "Melee",
		classes = { "Keen" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
		},
		scaling = {
			meleeDamage = 0.8,
		},
		tierScaling = {
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
		},
		rangeKeys = { "range" },
		behavior = "RitualDirk",
		targeting = "Nearest",
		base = {
			damage = 9,
			cooldown = 1.01,
			range = 15,
			knockback = 2,
			critDamage = 2.5,
			critChance = 0.2,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.444444444,
				cooldown = -0.08,
				critDamage = 0.5,
				critChance = 0.1,
			},
			{
				damage = 0.555555556,
				cooldown = -0.07,
				critDamage = 0.5,
				critChance = 0.1,
			},
			{
				damage = 0.777777778,
				cooldown = -0.08,
				critDamage = 0.5,
				critChance = 0.1,
			},
		},
	},
	ChainLightning = {
		id = "ChainLightning",
		displayName = "Lightning Shiv",
		description = "Hits release bouncing elemental lightning.",
		kind = "Melee",
		classes = { "Keen", "Arcane" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
		},
		scaling = {
			meleeDamage = 0.8,
		},
		tierScaling = {
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
		},
		rangeKeys = { "range" },
		behavior = "ChainLightning",
		targeting = "Nearest",
		base = {
			damage = 3,
			cooldown = 1.01,
			range = 15,
			knockback = 0,
			critDamage = 2,
			critChance = 0.04,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			secondaryCount = 1,
			secondaryBase = 5,
			secondaryScaling = 0.8,
			secondaryElemental = 1,
			secondaryBounce = 0,
			levelScaling = 0,
			secondaryRangeStuds = 40,
			secondarySpeed = 60,
			secondaryRadius = 0.5,
			secondarySlowSeconds = 1,
		},
		tiers = {
			{},
			{
				damage = 1,
				cooldown = -0.08,
				critChance = 0.02,
				secondaryBase = 1,
				secondaryBounce = 1,
			},
			{
				damage = 1,
				cooldown = -0.07,
				critChance = 0.02,
				secondaryBase = 2,
				secondaryBounce = 1,
			},
			{
				damage = 2,
				cooldown = -0.08,
				critChance = 0.02,
				secondaryBase = 3,
				secondaryBounce = 1,
			},
		},
	},
	Plank = {
		id = "Plank",
		displayName = "Plank",
		description = "Hits create explosions.",
		kind = "Melee",
		classes = { "Volatile", "Arcane" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.6,
				elementalDamage = 0.6,
				engineering = 0.6,
			},
			{
				meleeDamage = 0.7,
				elementalDamage = 0.7,
				engineering = 0.7,
			},
			{
				meleeDamage = 0.8,
				elementalDamage = 0.8,
				engineering = 0.8,
			},
			{
				meleeDamage = 0.9,
				elementalDamage = 0.9,
				engineering = 0.9,
			},
		},
		scaling = {
			meleeDamage = 0.6,
			elementalDamage = 0.6,
			engineering = 0.6,
		},
		tierScaling = {
			{
				meleeDamage = 0.6,
				elementalDamage = 0.6,
				engineering = 0.6,
			},
			{
				meleeDamage = 0.7,
				elementalDamage = 0.7,
				engineering = 0.7,
			},
			{
				meleeDamage = 0.8,
				elementalDamage = 0.8,
				engineering = 0.8,
			},
			{
				meleeDamage = 0.9,
				elementalDamage = 0.9,
				engineering = 0.9,
			},
		},
		rangeKeys = { "range" },
		behavior = "Plank",
		targeting = "Nearest",
		base = {
			damage = 10,
			cooldown = 1.23,
			range = 15,
			knockback = 5,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 1,
			explosionChance = 0.25,
			explosionRadius = 4.5,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.5,
				cooldown = -0.09,
				explosionChance = 0.05,
			},
			{
				damage = 0.5,
				cooldown = -0.08,
				explosionChance = 0.1,
			},
			{
				damage = 1,
				cooldown = -0.08,
				explosionChance = 0.1,
			},
		},
	},
	PlasmaSledge = {
		id = "PlasmaSledge",
		displayName = "Plasma Sledge",
		description = "Hits create explosions.",
		kind = "Melee",
		classes = { "Arcane", "Volatile" },
		minTier = 3,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1.5,
				elementalDamage = 1.5,
			},
			{
				meleeDamage = 1.5,
				elementalDamage = 1.5,
			},
			{
				meleeDamage = 1.5,
				elementalDamage = 1.5,
			},
			{
				meleeDamage = 2,
				elementalDamage = 2,
			},
		},
		scaling = {
			meleeDamage = 1.5,
			elementalDamage = 1.5,
		},
		tierScaling = {
			{
				meleeDamage = 1.5,
				elementalDamage = 1.5,
			},
			{
				meleeDamage = 1.5,
				elementalDamage = 1.5,
			},
			{
				meleeDamage = 1.5,
				elementalDamage = 1.5,
			},
			{
				meleeDamage = 2,
				elementalDamage = 2,
			},
		},
		rangeKeys = { "range" },
		behavior = "PlasmaSledge",
		targeting = "Nearest",
		base = {
			damage = 80,
			cooldown = 1.55,
			range = 17.5,
			knockback = 30,
			critDamage = 1.75,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 1,
			explosionChance = 0.25,
			explosionRadius = 6,
			levelScaling = 0,
		},
		tiers = {
			{},
			{},
			{},
			{
				damage = 0.5,
				cooldown = -0.06,
				explosionChance = 0.25,
				explosionRadius = 1.5,
			},
		},
	},
	PowerFist = {
		id = "PowerFist",
		displayName = "Power Fist",
		description = "Hits create explosions.",
		kind = "Melee",
		classes = { "Brawl", "Volatile" },
		minTier = 3,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "PowerFist",
		targeting = "Nearest",
		base = {
			damage = 40,
			cooldown = 0.69,
			range = 15,
			knockback = 15,
			critDamage = 1.5,
			critChance = 0.01,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			explosionChance = 0.25,
			explosionRadius = 4.5,
			levelScaling = 0,
		},
		tiers = {
			{},
			{},
			{},
			{
				damage = 1,
				cooldown = -0.1,
				explosionChance = 0.25,
				explosionRadius = 1.5,
			},
		},
	},
	ThornTrail = {
		id = "ThornTrail",
		displayName = "Pruner",
		description = "Plants a garden that produces fruit.",
		kind = "Melee",
		classes = { "Steward" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.65,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 0.5,
		},
		tierScaling = {
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.65,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "ThornTrail",
		targeting = "Nearest",
		base = {
			damage = 10,
			cooldown = 1.14,
			range = 15,
			knockback = 2,
			critDamage = 1.25,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.5,
				cooldown = -0.08,
				critDamage = 0.25,
				critChance = 0.03,
			},
			{
				damage = 0.5,
				cooldown = -0.08,
				critDamage = 0.25,
				critChance = 0.03,
			},
			{
				damage = 0.5,
				cooldown = -0.09,
				critDamage = 0.25,
				critChance = 0.03,
			},
		},
		structureKinds = { "MoonGarden", "MoonGarden", "MoonGarden", "MoonGarden" },
		gardenIntervals = { 15, 14, 12, 10 },
	},
	Gravestone = {
		id = "Gravestone",
		displayName = "Rock",
		description = "Thrusts at nearby enemies.",
		kind = "Melee",
		classes = { "Primal", "Bludgeon" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "Gravestone",
		targeting = "Nearest",
		base = {
			damage = 20,
			cooldown = 1.68,
			range = 15,
			knockback = 5,
			critDamage = 1.5,
			critChance = 0.1,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.75,
				cooldown = -0.07,
				critChance = 0.05,
			},
			{
				damage = 0.75,
				cooldown = -0.08,
				critChance = 0.05,
			},
			{
				damage = 1,
				cooldown = -0.07,
				critChance = 0.05,
			},
		},
		heldStats = {
			{},
			{
				armor = 1,
			},
			{
				armor = 1,
				maxHp = 20,
			},
			{
				armor = 2,
				maxHp = 20,
			},
		},
	},
	Scissors = {
		id = "Scissors",
		displayName = "Scissors",
		description = "Thrusts at nearby enemies.",
		kind = "Melee",
		classes = { "Remedy", "Keen" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
		},
		scaling = {
			meleeDamage = 0.8,
		},
		tierScaling = {
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
			{
				meleeDamage = 0.8,
			},
		},
		rangeKeys = { "range" },
		behavior = "Scissors",
		targeting = "Nearest",
		base = {
			damage = 5,
			cooldown = 1.01,
			range = 15,
			knockback = 2,
			critDamage = 2,
			critChance = 0.1,
			lifeSteal = 0.4,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 1,
				cooldown = -0.03,
				critDamage = 0.15,
				critChance = 0.02,
				lifeSteal = 0.05,
			},
			{
				damage = 1,
				cooldown = -0.04,
				critDamage = 0.15,
				critChance = 0.03,
				lifeSteal = 0.05,
			},
			{
				damage = 1,
				cooldown = -0.08,
				critDamage = 0.2,
				critChance = 0.05,
				lifeSteal = 0.1,
			},
		},
	},
	RuneAwl = {
		id = "RuneAwl",
		displayName = "Screwdriver",
		description = "Places engineering landmines at tier-dependent intervals.",
		kind = "Melee",
		classes = { "Artisan" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.5,
				engineering = 0.5,
			},
			{
				meleeDamage = 0.5,
				engineering = 0.6,
			},
			{
				meleeDamage = 0.5,
				engineering = 0.7,
			},
			{
				meleeDamage = 0.5,
				engineering = 0.8,
			},
		},
		scaling = {
			meleeDamage = 0.5,
			engineering = 0.5,
		},
		tierScaling = {
			{
				meleeDamage = 0.5,
				engineering = 0.5,
			},
			{
				meleeDamage = 0.5,
				engineering = 0.6,
			},
			{
				meleeDamage = 0.5,
				engineering = 0.7,
			},
			{
				meleeDamage = 0.5,
				engineering = 0.8,
			},
		},
		rangeKeys = { "range" },
		behavior = "RuneAwl",
		targeting = "Nearest",
		base = {
			damage = 8,
			cooldown = 1.06,
			range = 13.5,
			knockback = 3,
			critDamage = 2,
			critChance = 0.1,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.5,
				cooldown = -0.05,
				critDamage = 0.15,
				critChance = 0.05,
			},
			{
				damage = 0.5,
				cooldown = -0.03,
				critDamage = 0.15,
				critChance = 0.05,
			},
			{
				damage = 0.5,
				cooldown = -0.1,
				critDamage = 0.2,
				critChance = 0.1,
			},
		},
		structureKinds = { "RuneMine", "RuneMine", "RuneMine", "RuneMine" },
		structureIntervals = { 12, 9, 6, 3 },
	},
	Scythe = {
		id = "Scythe",
		displayName = "Scythe",
		description = "Drains 3 HP per second; gains 3% Damage when hurt this wave.",
		kind = "Melee",
		classes = { "Dread", "Spectral" },
		minTier = 4,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1.5,
				lifeSteal = 1,
			},
			{
				meleeDamage = 1.5,
				lifeSteal = 1,
			},
			{
				meleeDamage = 1.5,
				lifeSteal = 1,
			},
			{
				meleeDamage = 1.5,
				lifeSteal = 1,
			},
		},
		scaling = {
			meleeDamage = 1.5,
			lifeSteal = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1.5,
				lifeSteal = 1,
			},
			{
				meleeDamage = 1.5,
				lifeSteal = 1,
			},
			{
				meleeDamage = 1.5,
				lifeSteal = 1,
			},
			{
				meleeDamage = 1.5,
				lifeSteal = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "Scythe",
		targeting = "Nearest",
		base = {
			damage = 150,
			cooldown = 0.72,
			range = 25,
			knockback = 5,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 1,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 1,
			selfDamage = 30,
			selfDamageSeconds = 1,
			damageOnHurt = 3,
			levelScaling = 0,
		},
		tiers = { {}, {}, {}, {} },
	},
	LamplighterPike = {
		id = "LamplighterPike",
		displayName = "Spear",
		description = "Thrusts at nearby enemies.",
		kind = "Melee",
		classes = { "Primal" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "LamplighterPike",
		targeting = "Nearest",
		base = {
			damage = 15,
			cooldown = 1.52,
			range = 35,
			knockback = 0,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.666666667,
				cooldown = -0.12,
				range = 2.5,
			},
			{
				damage = 1,
				cooldown = -0.12,
				range = 2.5,
			},
			{
				damage = 1.333333333,
				cooldown = -0.04,
				range = 10,
			},
		},
	},
	SpikyShield = {
		id = "SpikyShield",
		displayName = "Spiky Shield",
		description = "Thrusts at nearby enemies.",
		kind = "Melee",
		classes = { "Knightly", "Bludgeon" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				armor = 1,
			},
			{
				armor = 1.25,
			},
			{
				armor = 1.5,
			},
			{
				armor = 2,
			},
		},
		scaling = {
			armor = 1,
		},
		tierScaling = {
			{
				armor = 1,
			},
			{
				armor = 1.25,
			},
			{
				armor = 1.5,
			},
			{
				armor = 2,
			},
		},
		rangeKeys = { "range" },
		behavior = "SpikyShield",
		targeting = "Nearest",
		base = {
			damage = 10,
			cooldown = 1.16,
			range = 15,
			knockback = 20,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.5,
			},
			{
				damage = 0.5,
			},
			{
				damage = 1,
				cooldown = -0.15,
			},
		},
	},
	Stick = {
		id = "Stick",
		displayName = "Stick",
		description = "Each additional Stick adds base damage.",
		kind = "Melee",
		classes = { "Primal" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "Stick",
		targeting = "Nearest",
		base = {
			damage = 8,
			cooldown = 1.29,
			range = 17.5,
			knockback = 0,
			critDamage = 1.5,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			damagePerCopy = 4,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.125,
				cooldown = -0.07,
				damagePerCopy = 2,
			},
			{
				damage = 0.125,
				cooldown = -0.07,
				damagePerCopy = 2,
			},
			{
				damage = 0.25,
				cooldown = -0.06,
				damagePerCopy = 2,
			},
		},
	},
	DuskSabre = {
		id = "DuskSabre",
		displayName = "Sword",
		description = "Thrusts at nearby enemies.",
		kind = "Melee",
		classes = { "Edge", "Knightly" },
		minTier = 2,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "DuskSabre",
		targeting = "Nearest",
		base = {
			damage = 30,
			cooldown = 1.28,
			range = 20,
			knockback = 5,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 2,
			levelScaling = 0,
		},
		tiers = {
			{},
			{},
			{
				damage = 0.5,
				cooldown = -0.15,
			},
			{
				damage = 0.666666667,
				cooldown = -0.15,
			},
		},
	},
	ThiefDagger = {
		id = "ThiefDagger",
		displayName = "Thief Dagger",
		description = "Critical kills can grant a material.",
		kind = "Melee",
		classes = { "Keen" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.5,
			},
		},
		scaling = {
			meleeDamage = 0.5,
		},
		tierScaling = {
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.5,
			},
			{
				meleeDamage = 0.5,
			},
		},
		rangeKeys = { "range" },
		behavior = "ThiefDagger",
		targeting = "Nearest",
		base = {
			damage = 6,
			cooldown = 1.01,
			range = 15,
			knockback = 2,
			critDamage = 2,
			critChance = 0.2,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			critMaterialChance = 0.5,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 1,
				cooldown = -0.08,
				critChance = 0.05,
				critMaterialChance = 0.06,
			},
			{
				damage = 1,
				cooldown = -0.07,
				critChance = 0.05,
				critMaterialChance = 0.06,
			},
			{
				damage = 2,
				cooldown = -0.13,
				critChance = 0.1,
				critMaterialChance = 0.18,
			},
		},
	},
	ThunderSword = {
		id = "ThunderSword",
		displayName = "Thunder Sword",
		description = "Hits release slowing elemental projectiles.",
		kind = "Melee",
		classes = { "Edge", "Arcane" },
		minTier = 3,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1.25,
				elementalDamage = 1.25,
			},
			{
				meleeDamage = 1.25,
				elementalDamage = 1.25,
			},
			{
				meleeDamage = 1.25,
				elementalDamage = 1.25,
			},
			{
				meleeDamage = 1.5,
				elementalDamage = 1.5,
			},
		},
		scaling = {
			meleeDamage = 1.25,
			elementalDamage = 1.25,
		},
		tierScaling = {
			{
				meleeDamage = 1.25,
				elementalDamage = 1.25,
			},
			{
				meleeDamage = 1.25,
				elementalDamage = 1.25,
			},
			{
				meleeDamage = 1.25,
				elementalDamage = 1.25,
			},
			{
				meleeDamage = 1.5,
				elementalDamage = 1.5,
			},
		},
		rangeKeys = { "range" },
		behavior = "ThunderSword",
		targeting = "Nearest",
		base = {
			damage = 40,
			cooldown = 1.21,
			range = 20,
			knockback = 5,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 1,
			secondaryCount = 2,
			secondaryBase = 0,
			secondaryScaling = 1,
			secondaryElemental = 1,
			secondarySlow = 0.8,
			secondaryBounce = 0,
			levelScaling = 0,
			secondaryRangeStuds = 40,
			secondarySpeed = 60,
			secondaryRadius = 0.5,
			secondarySlowSeconds = 1,
		},
		tiers = { {}, {}, {}, {
			damage = 0.875,
			cooldown = -0.15,
			secondaryCount = 2,
		} },
	},
	Torch = {
		id = "Torch",
		displayName = "Torch",
		description = "Hits apply elemental burning.",
		kind = "Melee",
		classes = { "Primal", "Arcane" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.5,
				elementalDamage = 0.5,
			},
			{
				meleeDamage = 0.65,
				elementalDamage = 0.65,
			},
			{
				meleeDamage = 0.8,
				elementalDamage = 0.8,
			},
			{
				meleeDamage = 1,
				elementalDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 0.5,
			elementalDamage = 0.5,
		},
		tierScaling = {
			{
				meleeDamage = 0.5,
				elementalDamage = 0.5,
			},
			{
				meleeDamage = 0.65,
				elementalDamage = 0.65,
			},
			{
				meleeDamage = 0.8,
				elementalDamage = 0.8,
			},
			{
				meleeDamage = 1,
				elementalDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "Torch",
		targeting = "Nearest",
		base = {
			damage = 1,
			cooldown = 1.1,
			range = 17.5,
			knockback = 20,
			critDamage = 1.5,
			critChance = 0,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 1,
			burnDamage = 3,
			burnTicks = 3,
			burnSpread = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				cooldown = -0.06,
				burnDamage = 2,
				burnTicks = 2,
			},
			{
				cooldown = -0.09,
				burnDamage = 3,
				burnTicks = 1,
				burnSpread = 1,
			},
			{
				cooldown = -0.15,
				burnDamage = 4,
				burnTicks = 3,
			},
		},
	},
	FoundryKey = {
		id = "FoundryKey",
		displayName = "Wrench",
		description = "Deploys a turret that improves with weapon tier.",
		kind = "Melee",
		classes = { "Artisan" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "FoundryKey",
		targeting = "Nearest",
		base = {
			damage = 12,
			cooldown = 1.7,
			range = 17.5,
			knockback = 20,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 1,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.333333333,
				cooldown = -0.06,
			},
			{
				damage = 0.333333333,
				cooldown = -0.09,
			},
			{
				damage = 0.333333333,
				cooldown = -0.06,
			},
		},
		structureKinds = { "BrassSentry", "CinderSentry", "PrismSentry", "SiegeSentry" },
	},
	ChainGun = {
		id = "ChainGun",
		displayName = "Chain Gun",
		description = "Fires a magazine, then reloads.",
		kind = "Ranged",
		classes = { "Dread", "Longshot" },
		minTier = 4,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 1,
				engineering = 1,
			},
			{
				rangedDamage = 1,
				engineering = 1,
			},
			{
				rangedDamage = 1,
				engineering = 1,
			},
			{
				rangedDamage = 1,
				engineering = 1,
			},
		},
		scaling = {
			rangedDamage = 1,
			engineering = 1,
		},
		tierScaling = {
			{
				rangedDamage = 1,
				engineering = 1,
			},
			{
				rangedDamage = 1,
				engineering = 1,
			},
			{
				rangedDamage = 1,
				engineering = 1,
			},
			{
				rangedDamage = 1,
				engineering = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "ChainGun",
		targeting = "Nearest",
		base = {
			damage = 2,
			cooldown = 0.073,
			range = 50,
			knockback = 5,
			critDamage = 1.5,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = 1,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			magazine = 100,
			reloadSeconds = 2.04,
			levelScaling = 0,
		},
		tiers = { {}, {}, {}, {} },
	},
	BoomerangAxe = {
		id = "BoomerangAxe",
		displayName = "Crossbow",
		description = "Critical projectiles pierce enemies.",
		kind = "Ranged",
		classes = { "Keen", "Knightly" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 0.5,
				range = 0.1,
			},
			{
				rangedDamage = 0.5,
				range = 0.1,
			},
			{
				rangedDamage = 0.5,
				range = 0.1,
			},
			{
				rangedDamage = 0.5,
				range = 0.1,
			},
		},
		scaling = {
			rangedDamage = 0.5,
			range = 0.1,
		},
		tierScaling = {
			{
				rangedDamage = 0.5,
				range = 0.1,
			},
			{
				rangedDamage = 0.5,
				range = 0.1,
			},
			{
				rangedDamage = 0.5,
				range = 0.1,
			},
			{
				rangedDamage = 0.5,
				range = 0.1,
			},
		},
		rangeKeys = { "range" },
		behavior = "BoomerangAxe",
		targeting = "Nearest",
		base = {
			damage = 10,
			cooldown = 1.13,
			range = 35,
			knockback = 8,
			critDamage = 1.5,
			critChance = 0.3,
			lifeSteal = 0,
			count = 1,
			pierce = 0,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			critPierce = 1,
			pierceFalloff = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.2,
				critDamage = 0.25,
				critChance = 0.05,
				critPierce = 1,
			},
			{
				damage = 0.3,
				critDamage = 0.25,
				critChance = 0.05,
				critPierce = 1,
			},
			{
				damage = 0.3,
				critDamage = 0.25,
				critChance = 0.05,
				critPierce = 1,
			},
		},
	},
	ScatterBell = {
		id = "ScatterBell",
		displayName = "Double Barrel Shotgun",
		description = "Projectiles pierce enemies.",
		kind = "Ranged",
		classes = { "Longshot" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 0.8,
			},
			{
				rangedDamage = 0.85,
			},
			{
				rangedDamage = 0.9,
			},
			{
				rangedDamage = 1,
			},
		},
		scaling = {
			rangedDamage = 0.8,
		},
		tierScaling = {
			{
				rangedDamage = 0.8,
			},
			{
				rangedDamage = 0.85,
			},
			{
				rangedDamage = 0.9,
			},
			{
				rangedDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "ScatterBell",
		targeting = "Nearest",
		base = {
			damage = 3,
			cooldown = 1.37,
			range = 35,
			knockback = 8,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			count = 4,
			pierce = 2,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 10,
			fan = 1,
			pierceFalloff = 0.3,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 1,
				cooldown = -0.09,
			},
			{
				damage = 1,
				cooldown = -0.08,
			},
			{
				count = 2,
				pierce = 1,
			},
		},
	},
	CinderBreath = {
		id = "CinderBreath",
		displayName = "Flamethrower",
		description = "Hits apply elemental burning.",
		kind = "Ranged",
		classes = { "Arcane", "Colossal" },
		minTier = 2,
		brotato = true,
		originalScaling = {
			{
				elementalDamage = 0.01,
			},
			{
				elementalDamage = 0.01,
			},
			{
				elementalDamage = 0.01,
			},
			{
				elementalDamage = 0.01,
			},
		},
		scaling = {
			elementalDamage = 0.01,
		},
		tierScaling = {
			{
				elementalDamage = 0.01,
			},
			{
				elementalDamage = 0.01,
			},
			{
				elementalDamage = 0.01,
			},
			{
				elementalDamage = 0.01,
			},
		},
		rangeKeys = { "range" },
		behavior = "CinderBreath",
		targeting = "Nearest",
		base = {
			damage = 1,
			cooldown = 0.12,
			range = 25,
			knockback = 0,
			critDamage = 2,
			critChance = 0,
			lifeSteal = 0,
			count = 1,
			pierce = 99,
			bounce = 0,
			projectileSpeed = 35,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			burnDamage = 1,
			burnTicks = 3,
			levelScaling = 0,
		},
		tiers = {
			{},
			{},
			{
				range = 5,
				burnDamage = 2,
				burnTicks = 2,
			},
			{
				cooldown = -0.03,
				range = 10,
				burnDamage = 2,
				burnTicks = 3,
			},
		},
	},
	CathedralEngine = {
		id = "CathedralEngine",
		displayName = "Gatling Laser",
		description = "Projectiles pierce enemies.",
		kind = "Ranged",
		classes = { "Dread", "Colossal" },
		minTier = 4,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
		},
		scaling = {
			rangedDamage = 1,
		},
		tierScaling = {
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "CathedralEngine",
		targeting = "Nearest",
		base = {
			damage = 10,
			cooldown = 0.073,
			range = 50,
			knockback = 5,
			critDamage = 3,
			critChance = 0.1,
			lifeSteal = 0,
			count = 1,
			pierce = 3,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			pierceFalloff = 0.25,
			levelScaling = 0,
		},
		tiers = { {}, {}, {}, {} },
	},
	GhostScepter = {
		id = "GhostScepter",
		displayName = "Ghost Scepter",
		description = "Weapon kills grant permanent maxHp each wave.",
		kind = "Ranged",
		classes = { "Spectral" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
		},
		scaling = {
			rangedDamage = 1,
		},
		tierScaling = {
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "GhostScepter",
		targeting = "Nearest",
		base = {
			damage = 10,
			cooldown = 0.98,
			range = 30,
			knockback = 2,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = 0,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			killsPerGain = 20,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.5,
				cooldown = -0.05,
				range = 5,
				killsPerGain = -2,
			},
			{
				damage = 0.5,
				cooldown = -0.05,
				range = 5,
				killsPerGain = -2,
			},
			{
				damage = 1,
				cooldown = -0.05,
				range = 5,
				killsPerGain = -4,
			},
		},
		killGainStat = "maxHp",
	},
	LaserGun = {
		id = "LaserGun",
		displayName = "Laser Gun",
		description = "Projectiles pierce enemies.",
		kind = "Ranged",
		classes = { "Longshot" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 4,
			},
			{
				rangedDamage = 4.5,
			},
			{
				rangedDamage = 5,
			},
			{
				rangedDamage = 6,
			},
		},
		scaling = {
			rangedDamage = 4,
		},
		tierScaling = {
			{
				rangedDamage = 4,
			},
			{
				rangedDamage = 4.5,
			},
			{
				rangedDamage = 5,
			},
			{
				rangedDamage = 6,
			},
		},
		rangeKeys = { "range" },
		behavior = "LaserGun",
		targeting = "Nearest",
		base = {
			damage = 40,
			cooldown = 1.98,
			range = 50,
			knockback = 0,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = 1,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			pierceFalloff = 0.25,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.375,
				cooldown = -0.08,
			},
			{
				damage = 0.375,
				cooldown = -0.08,
			},
			{
				damage = 0.75,
				cooldown = -0.17,
			},
		},
	},
	LeechCarbine = {
		id = "LeechCarbine",
		displayName = "Medical Gun",
		description = "Fires at nearby enemies.",
		kind = "Ranged",
		classes = { "Remedy", "Longshot" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
		},
		scaling = {
			rangedDamage = 1,
		},
		tierScaling = {
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "LeechCarbine",
		targeting = "Nearest",
		base = {
			damage = 10,
			cooldown = 0.78,
			range = 40,
			knockback = 0,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0.5,
			count = 1,
			pierce = 0,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.5,
				cooldown = -0.08,
				lifeSteal = 0.05,
			},
			{
				damage = 0.5,
				cooldown = -0.08,
				lifeSteal = 0.05,
			},
			{
				damage = 1,
				cooldown = -0.14,
				lifeSteal = 0.05,
			},
		},
	},
	Minigun = {
		id = "Minigun",
		displayName = "Minigun",
		description = "Projectiles pierce enemies.",
		kind = "Ranged",
		classes = { "Colossal", "Longshot" },
		minTier = 3,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.75,
			},
		},
		scaling = {
			rangedDamage = 0.5,
		},
		tierScaling = {
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.75,
			},
		},
		rangeKeys = { "range" },
		behavior = "Minigun",
		targeting = "Nearest",
		base = {
			damage = 2,
			cooldown = 0.09,
			range = 40,
			knockback = 3,
			critDamage = 1.75,
			critChance = 0.01,
			lifeSteal = 0,
			count = 1,
			pierce = 1,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			pierceFalloff = 0.25,
			levelScaling = 0,
		},
		tiers = {
			{},
			{},
			{},
			{
				damage = 1.5,
				range = 5,
				critDamage = 0.25,
				critChance = 0.02,
				pierce = 1,
			},
		},
	},
	NuclearLauncher = {
		id = "NuclearLauncher",
		displayName = "Nuclear Launcher",
		description = "Hits create explosions.",
		kind = "Ranged",
		classes = { "Colossal", "Volatile" },
		minTier = 3,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 1,
				elementalDamage = 1,
			},
			{
				rangedDamage = 1,
				elementalDamage = 1,
			},
			{
				rangedDamage = 1,
				elementalDamage = 1,
			},
			{
				rangedDamage = 1,
				elementalDamage = 1,
			},
		},
		scaling = {
			rangedDamage = 1,
			elementalDamage = 1,
		},
		tierScaling = {
			{
				rangedDamage = 1,
				elementalDamage = 1,
			},
			{
				rangedDamage = 1,
				elementalDamage = 1,
			},
			{
				rangedDamage = 1,
				elementalDamage = 1,
			},
			{
				rangedDamage = 1,
				elementalDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "NuclearLauncher",
		targeting = "Nearest",
		base = {
			damage = 60,
			cooldown = 2.12,
			range = 80,
			knockback = 15,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = 0,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			explosionRadius = 12,
			levelScaling = 0,
		},
		tiers = { {}, {}, {}, {
			damage = 1,
			explosionRadius = 1.5,
		} },
	},
	Obliterator = {
		id = "Obliterator",
		displayName = "Obliterator",
		description = "Projectiles pierce enemies.",
		kind = "Ranged",
		classes = { "Longshot", "Colossal" },
		minTier = 3,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 10,
			},
			{
				rangedDamage = 10,
			},
			{
				rangedDamage = 10,
			},
			{
				rangedDamage = 15,
			},
		},
		scaling = {
			rangedDamage = 10,
		},
		tierScaling = {
			{
				rangedDamage = 10,
			},
			{
				rangedDamage = 10,
			},
			{
				rangedDamage = 10,
			},
			{
				rangedDamage = 15,
			},
		},
		rangeKeys = { "range" },
		behavior = "Obliterator",
		targeting = "Nearest",
		base = {
			damage = 250,
			cooldown = 3.23,
			range = 80,
			knockback = 0,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = -1,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			pierceFalloff = 0,
			levelScaling = 0,
		},
		tiers = { {}, {}, {}, {
			damage = 0.6,
			range = 20,
		} },
	},
	WatchmanPistol = {
		id = "WatchmanPistol",
		displayName = "Pistol",
		description = "Projectiles pierce enemies.",
		kind = "Ranged",
		classes = { "Longshot" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
		},
		scaling = {
			rangedDamage = 1,
		},
		tierScaling = {
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "WatchmanPistol",
		targeting = "Nearest",
		base = {
			damage = 12,
			cooldown = 1.2,
			range = 40,
			knockback = 15,
			critDamage = 2,
			critChance = 0.1,
			lifeSteal = 0,
			count = 1,
			pierce = 1,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.666666667,
				cooldown = -0.08,
				critChance = 0.05,
			},
			{
				damage = 0.833333333,
				cooldown = -0.09,
				critChance = 0.05,
			},
			{
				damage = 1.666666667,
				cooldown = -0.16,
				critChance = 0.05,
			},
		},
	},
	PotatoThrower = {
		id = "PotatoThrower",
		displayName = "Potato Thrower",
		description = "Fires at nearby enemies.",
		kind = "Ranged",
		classes = { "Steward" },
		minTier = 2,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 0.4,
				maxHp = 0.2,
			},
			{
				rangedDamage = 0.4,
				maxHp = 0.2,
			},
			{
				rangedDamage = 0.4,
				maxHp = 0.2,
			},
			{
				rangedDamage = 0.4,
				maxHp = 0.2,
			},
		},
		scaling = {
			rangedDamage = 0.4,
			maxHp = 0.02,
		},
		tierScaling = {
			{
				rangedDamage = 0.4,
				maxHp = 0.02,
			},
			{
				rangedDamage = 0.4,
				maxHp = 0.02,
			},
			{
				rangedDamage = 0.4,
				maxHp = 0.02,
			},
			{
				rangedDamage = 0.4,
				maxHp = 0.02,
			},
		},
		rangeKeys = { "range" },
		behavior = "PotatoThrower",
		targeting = "Nearest",
		base = {
			damage = 3,
			cooldown = 0.45,
			range = 50,
			knockback = 20,
			critDamage = 1.5,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = 0,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			levelScaling = 0,
		},
		tiers = {
			{},
			{},
			{
				damage = 0.666666667,
				cooldown = -0.08,
				knockback = 5,
			},
			{
				damage = 1.666666667,
				cooldown = -0.09,
				knockback = 5,
			},
		},
	},
	Railgun = {
		id = "Railgun",
		displayName = "Railgun",
		description = "Gains base damage every 5 seconds this wave; resets when hurt.",
		kind = "Ranged",
		classes = { "Longshot", "Colossal" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 0.8,
				dodge = 0.3,
			},
			{
				rangedDamage = 0.8,
				dodge = 0.35,
			},
			{
				rangedDamage = 0.8,
				dodge = 0.4,
			},
			{
				rangedDamage = 1,
				dodge = 0.45,
			},
		},
		scaling = {
			rangedDamage = 0.8,
			dodge = 0.3,
		},
		tierScaling = {
			{
				rangedDamage = 0.8,
				dodge = 0.3,
			},
			{
				rangedDamage = 0.8,
				dodge = 0.35,
			},
			{
				rangedDamage = 0.8,
				dodge = 0.4,
			},
			{
				rangedDamage = 1,
				dodge = 0.45,
			},
		},
		rangeKeys = { "range" },
		behavior = "Railgun",
		targeting = "Nearest",
		base = {
			damage = 10,
			cooldown = 1.07,
			range = 30,
			knockback = 15,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = 1,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			timedBaseDamage = 3,
			timedSeconds = 5,
			pierceFalloff = 0.5,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.5,
				cooldown = -0.05,
				timedBaseDamage = 1,
				pierceFalloff = -0.15,
			},
			{
				damage = 0.5,
				cooldown = -0.04,
				pierce = 1,
				timedBaseDamage = 1,
			},
			{
				damage = 1.5,
				cooldown = -0.03,
				pierce = 1,
				timedBaseDamage = 1,
				pierceFalloff = -0.1,
			},
		},
	},
	Revolver = {
		id = "Revolver",
		displayName = "Revolver",
		description = "Fires a magazine, then reloads.",
		kind = "Ranged",
		classes = { "Longshot" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1.3,
			},
			{
				rangedDamage = 1.65,
			},
			{
				rangedDamage = 2,
			},
		},
		scaling = {
			rangedDamage = 1,
		},
		tierScaling = {
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1.3,
			},
			{
				rangedDamage = 1.65,
			},
			{
				rangedDamage = 2,
			},
		},
		rangeKeys = { "range" },
		behavior = "Revolver",
		targeting = "Nearest",
		base = {
			damage = 15,
			cooldown = 0.43,
			range = 45,
			knockback = 15,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = 0,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			magazine = 6,
			reloadSeconds = 2.07,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.333333333,
				cooldown = -0.01,
				reloadSeconds = -0.14,
			},
			{
				damage = 0.333333333,
				cooldown = -0.02,
				reloadSeconds = -0.13,
			},
			{
				damage = 1,
				cooldown = -0.02,
				reloadSeconds = -0.13,
			},
		},
	},
	MortarLantern = {
		id = "MortarLantern",
		displayName = "Rocket Launcher",
		description = "Hits create explosions.",
		kind = "Ranged",
		classes = { "Colossal", "Volatile" },
		minTier = 2,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
		},
		scaling = {
			rangedDamage = 1,
		},
		tierScaling = {
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
			{
				rangedDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "MortarLantern",
		targeting = "Nearest",
		base = {
			damage = 30,
			cooldown = 1.78,
			range = 50,
			knockback = 15,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = 0,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			explosionRadius = 7.2,
			levelScaling = 0,
		},
		tiers = {
			{},
			{},
			{
				damage = 0.666666667,
				cooldown = -0.41,
				range = 5,
			},
			{
				damage = 1,
				cooldown = -0.34,
				range = 5,
			},
		},
	},
	ShrapnelOrgan = {
		id = "ShrapnelOrgan",
		displayName = "Shredder",
		description = "Hits create explosions.",
		kind = "Ranged",
		classes = { "Longshot", "Volatile" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.5,
			},
		},
		scaling = {
			rangedDamage = 0.5,
		},
		tierScaling = {
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.5,
			},
		},
		rangeKeys = { "range" },
		behavior = "ShrapnelOrgan",
		targeting = "Nearest",
		base = {
			damage = 5,
			cooldown = 1.3,
			range = 45,
			knockback = 0,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = 3,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			explosionChance = 0.5,
			explosionRadius = 4.5,
			pierceFalloff = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 1,
				cooldown = -0.08,
				explosionChance = 0.15,
				explosionRadius = 0.3,
			},
			{
				damage = 1,
				cooldown = -0.09,
				explosionChance = 0.15,
				explosionRadius = 0.3,
			},
			{
				damage = 2,
				cooldown = -0.08,
				explosionChance = 0.2,
				explosionRadius = 0.3,
			},
		},
	},
	Shuriken = {
		id = "Shuriken",
		displayName = "Shuriken",
		description = "Critical projectiles bounce between enemies.",
		kind = "Ranged",
		classes = { "Keen" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.25,
			},
			{
				meleeDamage = 0.34,
			},
			{
				meleeDamage = 0.42,
			},
			{
				meleeDamage = 0.5,
			},
		},
		scaling = {
			meleeDamage = 0.25,
		},
		tierScaling = {
			{
				meleeDamage = 0.25,
			},
			{
				meleeDamage = 0.34,
			},
			{
				meleeDamage = 0.42,
			},
			{
				meleeDamage = 0.5,
			},
		},
		rangeKeys = { "range" },
		behavior = "Shuriken",
		targeting = "Nearest",
		base = {
			damage = 7,
			cooldown = 0.87,
			range = 35,
			knockback = 0,
			critDamage = 1.5,
			critChance = 0.35,
			lifeSteal = 0,
			count = 1,
			pierce = 0,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			critBounce = 1,
			bounceFalloff = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.285714286,
				cooldown = -0.04,
				critChance = 0.03,
				critBounce = 1,
			},
			{
				damage = 0.285714286,
				cooldown = -0.03,
				critChance = 0.03,
				critBounce = 1,
			},
			{
				damage = 0.571428571,
				cooldown = -0.1,
				critChance = 0.04,
				critBounce = 1,
			},
		},
	},
	Slingshot = {
		id = "Slingshot",
		displayName = "Slingshot",
		description = "Projectiles bounce between enemies.",
		kind = "Ranged",
		classes = { "Primal" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 0.8,
			},
			{
				rangedDamage = 0.8,
			},
			{
				rangedDamage = 0.8,
			},
			{
				rangedDamage = 0.8,
			},
		},
		scaling = {
			rangedDamage = 0.8,
		},
		tierScaling = {
			{
				rangedDamage = 0.8,
			},
			{
				rangedDamage = 0.8,
			},
			{
				rangedDamage = 0.8,
			},
			{
				rangedDamage = 0.8,
			},
		},
		rangeKeys = { "range" },
		behavior = "Slingshot",
		targeting = "Nearest",
		base = {
			damage = 10,
			cooldown = 1.22,
			range = 30,
			knockback = 5,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = 0,
			bounce = 1,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			bounceFalloff = 0,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.3,
				cooldown = -0.05,
				bounce = 1,
			},
			{
				damage = 0.3,
				cooldown = -0.04,
				bounce = 1,
			},
			{
				damage = 0.4,
				cooldown = -0.03,
				bounce = 1,
			},
		},
	},
	RattleRepeater = {
		id = "RattleRepeater",
		displayName = "SMG",
		description = "Fires at nearby enemies.",
		kind = "Ranged",
		classes = { "Longshot" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.6,
			},
			{
				rangedDamage = 0.7,
			},
			{
				rangedDamage = 0.8,
			},
		},
		scaling = {
			rangedDamage = 0.5,
		},
		tierScaling = {
			{
				rangedDamage = 0.5,
			},
			{
				rangedDamage = 0.6,
			},
			{
				rangedDamage = 0.7,
			},
			{
				rangedDamage = 0.8,
			},
		},
		rangeKeys = { "range" },
		behavior = "RattleRepeater",
		targeting = "Nearest",
		base = {
			damage = 3,
			cooldown = 0.17,
			range = 40,
			knockback = 0,
			critDamage = 1.5,
			critChance = 0.01,
			lifeSteal = 0,
			count = 1,
			pierce = 0,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.333333333,
			},
			{
				damage = 0.333333333,
			},
			{
				damage = 1,
				cooldown = -0.02,
			},
		},
	},
	SniperGun = {
		id = "SniperGun",
		displayName = "Sniper Gun",
		description = "Hits release projectiles scaling with Range.",
		kind = "Ranged",
		classes = { "Longshot", "Keen" },
		minTier = 3,
		brotato = true,
		originalScaling = {
			{
				rangedDamage = 1,
				range = 0.2,
			},
			{
				rangedDamage = 1,
				range = 0.2,
			},
			{
				rangedDamage = 1,
				range = 0.2,
			},
			{
				rangedDamage = 1,
				range = 0.3,
			},
		},
		scaling = {
			rangedDamage = 1,
			range = 0.2,
		},
		tierScaling = {
			{
				rangedDamage = 1,
				range = 0.2,
			},
			{
				rangedDamage = 1,
				range = 0.2,
			},
			{
				rangedDamage = 1,
				range = 0.2,
			},
			{
				rangedDamage = 1,
				range = 0.3,
			},
		},
		rangeKeys = { "range" },
		behavior = "SniperGun",
		targeting = "Nearest",
		base = {
			damage = 50,
			cooldown = 2.4,
			range = 80,
			knockback = 30,
			critDamage = 3,
			critChance = 0.2,
			lifeSteal = 0,
			count = 1,
			pierce = 0,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			secondaryCount = 5,
			secondaryBase = 5,
			secondaryScaling = 0.1,
			secondaryRange = 1,
			levelScaling = 0,
			secondaryRangeStuds = 40,
			secondarySpeed = 60,
			secondaryRadius = 0.5,
			secondarySlowSeconds = 1,
		},
		tiers = {
			{},
			{},
			{},
			{
				damage = 0.6,
				range = 20,
				critDamage = 1,
				secondaryCount = 3,
				secondaryScaling = 0.05,
			},
		},
	},
	GalvanicFork = {
		id = "GalvanicFork",
		displayName = "Taser",
		description = "Fires at nearby enemies.",
		kind = "Ranged",
		classes = { "Steward", "Arcane" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				elementalDamage = 0.8,
			},
			{
				elementalDamage = 0.7,
			},
			{
				elementalDamage = 0.6,
			},
			{
				elementalDamage = 0.5,
			},
		},
		scaling = {
			elementalDamage = 0.8,
		},
		tierScaling = {
			{
				elementalDamage = 0.8,
			},
			{
				elementalDamage = 0.7,
			},
			{
				elementalDamage = 0.6,
			},
			{
				elementalDamage = 0.5,
			},
		},
		rangeKeys = { "range" },
		behavior = "GalvanicFork",
		targeting = "Nearest",
		base = {
			damage = 7,
			cooldown = 0.95,
			range = 20,
			knockback = 0,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = 0,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			fan = 1,
			slow = 0.8,
			slowSeconds = 1,
			slowRadius = 4,
			levelScaling = 0,
		},
		tiers = { {}, {
			count = 1,
		}, {
			count = 1,
		}, {
			damage = 1,
			count = 1,
		} },
	},
	SparkBolt = {
		id = "SparkBolt",
		displayName = "Wand",
		description = "Hits apply elemental burning.",
		kind = "Ranged",
		classes = { "Arcane" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				elementalDamage = 0.5,
			},
			{
				elementalDamage = 0.65,
			},
			{
				elementalDamage = 0.8,
			},
			{
				elementalDamage = 1,
			},
		},
		scaling = {
			elementalDamage = 0.5,
		},
		tierScaling = {
			{
				elementalDamage = 0.5,
			},
			{
				elementalDamage = 0.65,
			},
			{
				elementalDamage = 0.8,
			},
			{
				elementalDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "SparkBolt",
		targeting = "Nearest",
		base = {
			damage = 1,
			cooldown = 0.87,
			range = 35,
			knockback = 10,
			critDamage = 2,
			critChance = 0,
			lifeSteal = 0,
			count = 1,
			pierce = 1,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			burnDamage = 3,
			burnTicks = 3,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				cooldown = -0.09,
				range = 2.5,
				burnDamage = 2,
				burnTicks = 2,
			},
			{
				cooldown = -0.08,
				range = 2.5,
				burnDamage = 3,
				burnTicks = 1,
			},
			{
				cooldown = -0.17,
				range = 2.5,
				burnDamage = 4,
				burnTicks = 3,
			},
		},
	},
	DEXtroyer = {
		id = "DEXtroyer",
		displayName = "DEX-troyer",
		description = "Hits create explosions.",
		kind = "Melee",
		classes = { "Dread", "Volatile" },
		minTier = 4,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
				engineering = 1,
			},
			{
				meleeDamage = 1,
				engineering = 1,
			},
			{
				meleeDamage = 1,
				engineering = 1,
			},
			{
				meleeDamage = 1,
				engineering = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
			engineering = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
				engineering = 1,
			},
			{
				meleeDamage = 1,
				engineering = 1,
			},
			{
				meleeDamage = 1,
				engineering = 1,
			},
			{
				meleeDamage = 1,
				engineering = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "DEXtroyer",
		targeting = "Nearest",
		base = {
			damage = 100,
			cooldown = 1.33,
			range = 40,
			knockback = 10,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			explosionChance = 0.5,
			explosionRadius = 7.5,
			secondaryCount = 1,
			secondaryBase = 30,
			secondaryScaling = 1,
			secondaryElemental = 1,
			secondaryBounce = 5,
			levelScaling = 0,
			secondaryRangeStuds = 40,
			secondarySpeed = 60,
			secondaryRadius = 0.5,
			secondarySlowSeconds = 1,
		},
		tiers = { {}, {}, {}, {} },
	},
	Fireball = {
		id = "Fireball",
		displayName = "Fireball",
		description = "Hits apply elemental burning.",
		kind = "Ranged",
		classes = { "Volatile", "Arcane" },
		minTier = 2,
		brotato = true,
		originalScaling = {
			{
				elementalDamage = 0.25,
			},
			{
				elementalDamage = 0.25,
			},
			{
				elementalDamage = 0.5,
			},
			{
				elementalDamage = 0.75,
			},
		},
		scaling = {
			elementalDamage = 0.25,
		},
		tierScaling = {
			{
				elementalDamage = 0.25,
			},
			{
				elementalDamage = 0.25,
			},
			{
				elementalDamage = 0.5,
			},
			{
				elementalDamage = 0.75,
			},
		},
		rangeKeys = { "range" },
		behavior = "Fireball",
		targeting = "Nearest",
		base = {
			damage = 5,
			cooldown = 1.12,
			range = 40,
			knockback = 0,
			critDamage = 1.5,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = 0,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			explosionRadius = 6,
			burnDamage = 5,
			burnTicks = 3,
			levelScaling = 0,
		},
		tiers = {
			{},
			{},
			{
				damage = 1,
				cooldown = -0.09,
				range = 5,
				burnDamage = 1,
				burnTicks = 1,
			},
			{
				damage = 2,
				cooldown = -0.16,
				range = 5,
				burnDamage = 2,
				burnTicks = 1,
			},
		},
	},
	WinterNeedle = {
		id = "WinterNeedle",
		displayName = "Icicle",
		description = "Projectiles pierce enemies.",
		kind = "Ranged",
		classes = { "Keen", "Arcane" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				elementalDamage = 1,
			},
			{
				elementalDamage = 1,
			},
			{
				elementalDamage = 1,
			},
			{
				elementalDamage = 1,
			},
		},
		scaling = {
			elementalDamage = 1,
		},
		tierScaling = {
			{
				elementalDamage = 1,
			},
			{
				elementalDamage = 1,
			},
			{
				elementalDamage = 1,
			},
			{
				elementalDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "WinterNeedle",
		targeting = "Nearest",
		base = {
			damage = 10,
			cooldown = 1.03,
			range = 40,
			knockback = 5,
			critDamage = 2,
			critChance = 0.05,
			lifeSteal = 0,
			count = 1,
			pierce = 1,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 1,
				cooldown = -0.08,
				critChance = 0.05,
			},
			{
				damage = 1,
				cooldown = -0.08,
				critDamage = 0.5,
				critChance = 0.05,
			},
			{
				damage = 1,
				cooldown = -0.17,
				critDamage = 0.5,
				critChance = 0.05,
			},
		},
	},
	ParticleAccelerator = {
		id = "ParticleAccelerator",
		displayName = "Particle Accelerator",
		description = "Pierces enemies, burns, and slows with Engineering. Cannot bounce.",
		kind = "Ranged",
		classes = { "Colossal", "Arcane" },
		minTier = 3,
		brotato = true,
		originalScaling = {
			{
				elementalDamage = 1,
				engineering = 1,
			},
			{
				elementalDamage = 1,
				engineering = 1,
			},
			{
				elementalDamage = 1,
				engineering = 1,
			},
			{
				elementalDamage = 1,
				engineering = 1,
			},
		},
		scaling = {
			elementalDamage = 1,
			engineering = 1,
		},
		tierScaling = {
			{
				elementalDamage = 1,
				engineering = 1,
			},
			{
				elementalDamage = 1,
				engineering = 1,
			},
			{
				elementalDamage = 1,
				engineering = 1,
			},
			{
				elementalDamage = 1,
				engineering = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "ParticleAccelerator",
		targeting = "Nearest",
		base = {
			damage = 60,
			cooldown = 1.95,
			range = 80,
			knockback = 0,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			count = 1,
			pierce = -1,
			bounce = 0,
			projectileSpeed = 60,
			projectileRadius = 0.5,
			spreadDegrees = 8,
			pierceFalloff = 0,
			noBounce = 1,
			burnDamage = 8,
			burnTicks = 8,
			engineeringSlow = 0.01,
			slowSeconds = 1,
			levelScaling = 0,
		},
		tiers = {
			{},
			{},
			{},
			{
				damage = 1,
				cooldown = -0.33,
				burnDamage = 2,
				burnTicks = 2,
				engineeringSlow = 0.01,
			},
		},
	},
	SharpTooth = {
		id = "SharpTooth",
		displayName = "Sharp Tooth",
		description = "Gains Life Steal as health is lost.",
		kind = "Melee",
		classes = { "Primal", "Keen" },
		minTier = 1,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 0.5,
				lifeSteal = 0.5,
			},
			{
				meleeDamage = 0.5,
				lifeSteal = 0.65,
			},
			{
				meleeDamage = 0.5,
				lifeSteal = 0.8,
			},
			{
				meleeDamage = 0.5,
				lifeSteal = 1,
			},
		},
		scaling = {
			meleeDamage = 0.5,
			lifeSteal = 0.5,
		},
		tierScaling = {
			{
				meleeDamage = 0.5,
				lifeSteal = 0.5,
			},
			{
				meleeDamage = 0.5,
				lifeSteal = 0.65,
			},
			{
				meleeDamage = 0.5,
				lifeSteal = 0.8,
			},
			{
				meleeDamage = 0.5,
				lifeSteal = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "SharpTooth",
		targeting = "Nearest",
		base = {
			damage = 5,
			cooldown = 1.14,
			range = 15,
			knockback = 2,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 0,
			missingHpLifeSteal = 0.25,
			levelScaling = 0,
		},
		tiers = {
			{},
			{
				damage = 0.6,
				cooldown = -0.07,
				range = 1,
				critDamage = 0.15,
				critChance = 0.03,
				missingHpLifeSteal = -0.05,
			},
			{
				damage = 0.6,
				cooldown = -0.07,
				range = 1,
				critDamage = 0.15,
				critChance = 0.03,
				missingHpLifeSteal = -0.05,
			},
			{
				damage = 0.8,
				cooldown = -0.07,
				range = 1,
				critDamage = 0.2,
				critChance = 0.03,
				missingHpLifeSteal = -0.05,
			},
		},
	},
	VorpalSword = {
		id = "VorpalSword",
		displayName = "Vorpal Sword",
		description = "Alternates thrusts and sweeps; can execute ordinary enemies.",
		kind = "Melee",
		classes = { "Edge", "Knightly" },
		minTier = 2,
		brotato = true,
		originalScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		scaling = {
			meleeDamage = 1,
		},
		tierScaling = {
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
			{
				meleeDamage = 1,
			},
		},
		rangeKeys = { "range" },
		behavior = "VorpalSword",
		targeting = "Nearest",
		base = {
			damage = 20,
			cooldown = 1.11,
			range = 20,
			knockback = 5,
			critDamage = 2,
			critChance = 0.03,
			lifeSteal = 0,
			width = 1.2,
			sweepDegrees = 120,
			attackSeconds = 0.18,
			meleeMode = 2,
			executeChance = 0.01,
			levelScaling = 0,
		},
		tiers = {
			{},
			{},
			{
				damage = 0.75,
				cooldown = -0.08,
				executeChance = 0.01,
			},
			{
				damage = 1,
				cooldown = -0.08,
				executeChance = 0.01,
			},
		},
	},
}

return table.freeze(Weapons)
