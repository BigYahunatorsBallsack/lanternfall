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
	ranged: { keepDistance: number, fireInterval: number, projectileDamage: number }?,
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
			keepDistance = 30, -- studs; EnemySim keeps it there
			fireInterval = 2.5, -- shooting follows in WP9
			projectileDamage = 8,
		},
	},
}

local Elite = table.freeze({
	hpMultiplier = 8,
	speedMultiplier = 0.9,
	damageMultiplier = 1.5,
	sizeMultiplier = 1.5,
	xp = 25,
	dropsChest = true,
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
