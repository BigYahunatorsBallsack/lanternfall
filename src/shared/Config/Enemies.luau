--!strict
-- Enemy, elite and boss records (DESIGN.md section 7). Read by EnemySim, SpawnDirector and EnemyRenderer.
-- `typeId` is the 1-byte id sent in enemy snapshots; it must be unique and stay stable.

export type Enemy = {
	id: string,
	typeId: number,
	displayName: string,
	hp: number,
	speed: number, -- studs/s
	contactDamage: number,
	xp: number,
	radius: number, -- collision circle, studs (assumption)
	mass: number, -- crowd weight: heavier enemies push lighter ones aside (assumption)
	look: string?, -- reuses the model of this enemy id in another color (EnemyRenderer/Models); default: its own id
	ranged: Ranged?,
	charge: Charge?,
	split: Split?,
	-- set only on the variants built by Util/EnemyKinds
	elite: boolean?,
	affix: number?, -- index into elite.affixes, 1 or more
	damageTaken: number?, -- multiplier on every hit it takes (1 if nil)
	summon: Summon?,
}

-- Enemies that hold their distance and shoot (Spitter). Projectiles fly straight, are stopped by obstacles and
-- hurt the first player they touch (EnemySim/Volleys).
export type Ranged = {
	keepDistance: number, -- studs; EnemySim keeps it there
	fireInterval: number, -- seconds between shots
	fireRange: number, -- studs; shoots only at a player this close (assumption)
	projectileDamage: number,
	projectileSpeed: number, -- studs/s (assumption)
	projectileRange: number, -- studs a shot flies before it fades (assumption)
	projectileRadius: number, -- studs, hit circle of a shot (assumption)
	aimLead: number, -- 0 = aims where the player is, 1 = where a player walking straight on will be (assumption)
}

-- Enemies that stop, wind up (clients see it glow) and then rush in a straight line at where the player stood
-- (Charger, since the fun package after WP9). Side-stepping during the wind-up dodges it.
export type Charge = {
	triggerRange: number, -- studs; winds up when the nearest player is this close and the cooldown is over
	windupSeconds: number, -- standing still and glowing before the rush
	speed: number, -- studs/s during the rush
	maxDistance: number, -- studs; the rush ends here, at an obstacle, the arena edge or a player
	recoverSeconds: number, -- standing still after the rush
	cooldownSeconds: number, -- walking normally before the next wind-up can start
}

-- Enemies that fall apart into smaller ones when killed (Splitter). The new ones keep the minute and difficulty
-- multipliers of the parent and may go above the alive cap (up to Run.spawn.cap.max).
export type Split = {
	enemy: string, -- key in types
	count: number,
	spread: number, -- studs from the parent's centre
}

-- Elites with the Summoner affix call enemies around themselves every intervalSeconds while a player is around.
export type Summon = {
	enemy: string, -- key in types
	count: number,
	intervalSeconds: number,
}

-- An extra trait of a Gloom Elite, picked at random (Run.spawn.elites.affixFromMinute). Its index travels in the
-- snapshot (Net/Snapshot flags), so at most 3.
export type Affix = {
	id: string,
	displayName: string, -- in front of the elite's name, e.g. "Swift Gloom Brute"
	speedMultiplier: number?,
	damageTaken: number?, -- multiplier on every hit it takes
	summon: Summon?,
}

local Enemies: { [string]: Enemy } = {
	Shadeling = {
		id = "Shadeling",
		typeId = 1,
		displayName = "Shadeling",
		hp = 10,
		speed = 14,
		contactDamage = 5,
		xp = 1,
		radius = 1.5,
		mass = 1,
	},
	Brute = {
		id = "Brute",
		typeId = 2,
		displayName = "Brute",
		hp = 60,
		speed = 8,
		contactDamage = 12,
		xp = 4,
		radius = 2.5,
		mass = 6,
	},
	Spitter = {
		id = "Spitter",
		typeId = 3,
		displayName = "Spitter",
		hp = 20,
		speed = 10,
		contactDamage = 0,
		xp = 2,
		radius = 1.5,
		mass = 1,
		ranged = {
			keepDistance = 30,
			fireInterval = 2.5,
			fireRange = 34,
			projectileDamage = 8,
			projectileSpeed = 18,
			projectileRange = 50,
			projectileRadius = 0.6,
			aimLead = 0.3,
		},
	},
	-- typeId 4 is the boss
	Charger = {
		id = "Charger",
		typeId = 5,
		displayName = "Charger",
		hp = 40,
		speed = 9,
		contactDamage = 8,
		xp = 4,
		radius = 1.8,
		mass = 3,
		charge = {
			triggerRange = 24,
			windupSeconds = 0.9,
			speed = 38,
			maxDistance = 30,
			recoverSeconds = 1.2,
			cooldownSeconds = 3,
		},
	},
	Splitter = {
		id = "Splitter",
		typeId = 6,
		displayName = "Splitter",
		hp = 32,
		speed = 11,
		contactDamage = 7,
		xp = 2,
		radius = 1.9,
		mass = 2,
		split = { enemy = "Splitling", count = 3, spread = 1.5 },
	},
	-- only from Splitters
	Splitling = {
		id = "Splitling",
		typeId = 7,
		displayName = "Splitling",
		hp = 6,
		speed = 15,
		contactDamage = 3,
		xp = 1,
		radius = 1,
		mass = 0.6,
	},
	-- stronger versions of the first enemies for the second half of the run
	AbyssShadeling = {
		id = "AbyssShadeling",
		typeId = 8,
		displayName = "Abyss Shadeling",
		hp = 18,
		speed = 15,
		contactDamage = 8,
		xp = 2,
		radius = 1.6,
		mass = 1.2,
		look = "Shadeling",
	},
	AbyssBrute = {
		id = "AbyssBrute",
		typeId = 9,
		displayName = "Abyss Brute",
		hp = 140,
		speed = 8.5,
		contactDamage = 18,
		xp = 8,
		radius = 2.8,
		mass = 8,
		look = "Brute",
	},
}

-- Gloom Elite: any enemy type, bigger and tougher (Util/EnemyKinds builds one elite variant per type and affix).
local Elite = table.freeze({
	hpMultiplier = 8,
	speedMultiplier = 0.9,
	damageMultiplier = 1.5, -- contact and projectile damage
	sizeMultiplier = 1.5, -- collision radius and model
	massMultiplier = 2.25, -- pushes normal enemies of its type aside (assumption)
	xp = 25,
	dropsChest = true,
	typeIdOffset = 128, -- snapshot typeId of the elite variant = typeId + this (base typeIds stay below it)
	affixes = table.freeze({
		table.freeze({ id = "Swift", displayName = "Swift", speedMultiplier = 1.45 }),
		table.freeze({ id = "Armored", displayName = "Armored", damageTaken = 0.6 }),
		table.freeze({
			id = "Summoner",
			displayName = "Summoning",
			summon = table.freeze({ enemy = "Shadeling", count = 4, intervalSeconds = 6 }),
		}),
	}) :: { Affix },
})

local Boss = table.freeze({
	id = "LanternEater",
	typeId = 4,
	displayName = "The Lantern Eater",
	hp = 4000, -- multiplied by the player factor (see Run.playerFactor)
	speed = 9,
	radius = 5, -- assumption
	slam = table.freeze({ radius = 14, telegraph = 1.2, damage = 35 }),
	charge = table.freeze({ telegraph = 0.8, damage = 30 }),
	summon = table.freeze({ interval = 25, count = 20, enemy = "Shadeling" }),
	phase2 = table.freeze({ hpThreshold = 0.5, attackSpeedMultiplier = 1.25 }),
	reward = table.freeze({ upgradesPerPlayer = 3 }), -- embers in Economy.embers.bossKill
})

return table.freeze({
	types = table.freeze(Enemies),
	elite = Elite,
	boss = Boss,
})
