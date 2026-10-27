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
	ranged: Ranged?,
	elite: boolean?, -- set only on the elite variants built by Util/EnemyKinds
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
}

-- Gloom Elite: any enemy type, bigger and tougher (Util/EnemyKinds builds one elite variant per type).
local Elite = table.freeze({
	hpMultiplier = 8,
	speedMultiplier = 0.9,
	damageMultiplier = 1.5, -- contact and projectile damage
	sizeMultiplier = 1.5, -- collision radius and model
	massMultiplier = 2.25, -- pushes normal enemies of its type aside (assumption)
	xp = 25,
	dropsChest = true,
	typeIdOffset = 128, -- snapshot typeId of the elite variant = typeId + this (base typeIds stay below it)
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
