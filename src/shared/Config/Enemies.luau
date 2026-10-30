--!strict
-- Enemy, elite, champion and boss records (DESIGN.md section 7). Read by EnemySim, SpawnDirector, BossService and
-- EnemyRenderer.
-- `typeId` is the 1-byte id sent in enemy snapshots; it must be unique and stay stable.

export type Enemy = {
	id: string,
	typeId: number,
	displayName: string,
	hp: number,
	speed: number, -- studs/s
	contactDamage: number,
	-- B9, Brotato: HP and damage grow by these per growth step (damage: contact damage, or the shot damage of an
	-- enemy without contact damage); wave n: hp + hpPerWave * Run.spawn.growth.hpSteps[n] (about n - 1 by wave 20).
	-- All kinds use about 0.68 x hp and 0.34 x damage, which gives the 14x HP and 7.5x damage of wave 20 from before.
	hpPerWave: number,
	damagePerWave: number,
	xp: number,
	radius: number, -- collision circle, studs (assumption)
	mass: number, -- crowd weight: heavier enemies push lighter ones aside (assumption)
	-- share of a knockback the enemy ignores (0..1, Brotato's knockback resistance, B5); default 1 - 1 / mass above 1
	knockbackResistance: number?,
	look: string?, -- reuses the model of this enemy id in another color (EnemyRenderer/Models); default: its own id
	ranged: Ranged?,
	charge: Charge?,
	split: Split?,
	-- set only on the variants built by Util/EnemyKinds
	elite: boolean?,
	affix: number?, -- index into elite.affixes, 1 or more
	damageTaken: number?, -- multiplier on every hit it takes (1 if nil)
	summon: Summon?,
	-- since B6 (Config.Loot)
	loot: Loot?,
	flee: Flee?,
	anchored: boolean?, -- never moves, nothing pushes it (Trees); players walk through it
	-- since B9 part 2 (Brotato's enemy behaviours, DESIGN.md section 7)
	accelerate: Accelerate?,
	retaliate: Retaliate?,
	pulse: Pulse?,
	hatch: Hatch?,
	slash: Slash?,
	eat: Eat?,
	-- since WP10: a boss of the boss wave (Config.Enemies.bosses) or, since WP10 part 2, a champion of an elite wave
	-- (Config.Enemies.champions); BossService runs its phases and attacks
	boss: BossPlan?,
}

-- WP10, Brotato's bosses: phases ("mutations") that switch at an HP share or after some seconds, whichever comes
-- first; each phase runs its attacks in turn with a pause in between. Every attack warns first (a red circle or
-- line on the floor, BossTelegraphs), strikes and recovers. BossService/BossBrain is the state machine.
export type BossPlan = {
	phases: { BossPhase }, -- in order; phase 1 starts at spawn
	attacks: { [string]: BossAttack },
}

export type BossPhase = {
	fromHp: number?, -- starts once the boss is at or below this share of its max HP ...
	afterSeconds: number?, -- ... or this many seconds after it appeared, whichever comes first (not for phase 1)
	attacks: { string }, -- keys in BossPlan.attacks, tried in this order (one on cooldown or out of range is skipped)
	pauseSeconds: number, -- walking between two attacks
	speedMultiplier: number?, -- on its walking speed in this phase (default 1)
	roam: boolean?, -- runs all over the arena instead of after the nearest player
	flee: boolean?, -- runs away from the nearest player (WP10 part 2, Brotato's Monk)
	orbit: BossOrbit?, -- projectiles circling it during this phase
	announce: string?, -- message to everyone when the phase starts
}

-- Projectiles that circle the boss and hurt players they touch (Brotato's Predator).
export type BossOrbit = {
	count: number,
	radius: number, -- studs from its centre
	turnsPerSecond: number,
	hitRadius: number, -- studs, size of each projectile
	damage: number, -- grows with the boss's damage like its contact damage
}

-- One attack. `kind` decides which fields it uses:
--   Dash: rushes `distance` studs at `speed` along the line it showed; hurts every player it runs into once.
--   Slam: hits everyone within `radius` of where it stands.
--   Ring: `count` projectiles in every direction, `bursts` times `burstGapSeconds` apart.
--   Rain: `count` red circles (`radius`) at random spots within `spread` of every living player; they hit when the
--     wind-up ends (Brotato's Invoker: projectiles that "spawn after a second of priming").
--   Circle: `count` spots on a circle of `spread` studs around every living player; each fires a projectile at the
--     centre when the wind-up ends.
-- Since WP10 part 2 (the champions, Brotato's elites):
--   Cleave: `count` slashes from where it stands (red strips `distance` long, `radius` half wide): a fan of `arc`
--     degrees aimed at the nearest player, or with `around` evenly in every direction; hits each player once.
--   Volley: `count` projectiles in a fan of `arc` degrees at the nearest player, `bursts` times.
--   Scatter: `count` projectiles in random directions.
--   Summon: `count` enemies of `enemy` (with this wave's growth) within `spread` studs of it.
--   A Dash can also fire a pair of projectiles to its sides every `trailEvery` studs and `startShots` projectiles
--   (fan of `arc`) at the nearest player when it starts.
-- Each champion also has a signature move (owner feedback: attacks should not feel like reskins):
--   Dash `bounces` off walls and pillars (`bounceShots` in a ring each time), steers after the nearest player with
--     `turnRate` (degrees/s) and leaves a pool every `poolEvery` studs.
--   Boomerang: `count` projectiles in a fan of `arc` that fly `projectileRange` studs and come back to it.
--   Pools: `count` pools (`poolRadius`) within `spread` studs of it that hurt every `poolTick` s for `poolSeconds`.
--   March: `count` circles (`radius`) `spacing` studs apart from it towards the nearest player, `stepSeconds` apart.
--   Cross: an X of two strips `distance` long (`radius` half wide) on the nearest player; `count` of them,
--     `stepSeconds` apart, the later ones within `spread` studs.
--   Leap: jumps onto where the nearest player stood when the warning showed; hits within `radius`, then a ring of
--     `count` projectiles.
--   A Ring with `spinPerBurst` (degrees) turns with every burst: a spiral.
export type BossAttack = {
	kind: string,
	windupSeconds: number, -- the warning on the floor
	recoverSeconds: number,
	cooldownSeconds: number?, -- from the start of its wind-up until it may come again
	range: number?, -- only starts when the nearest player is at most this far from the boss's edge
	moving: boolean?, -- keeps walking during wind-up and strike (else it stands still)
	damage: number, -- per hit or projectile; grows with the boss's damage like its contact damage
	speed: number?, -- Dash
	distance: number?, -- Dash
	radius: number?, -- Slam, Rain: hit circle
	count: number?, -- Ring, Rain, Circle
	bursts: number?, -- Ring
	burstGapSeconds: number?, -- Ring
	spread: number?, -- Rain, Circle
	projectileSpeed: number?, -- Ring, Circle
	projectileRange: number?, -- Ring (Circle: twice its spread)
	projectileRadius: number?, -- Ring, Circle
	-- since WP10 part 2
	arc: number?, -- Cleave, Volley, Dash startShots: degrees of the fan
	around: boolean?, -- Cleave: in every direction instead of at the nearest player
	enemy: string?, -- Summon: key in Config.Enemies.types
	trailEvery: number?, -- Dash: studs between two pairs of side projectiles
	startShots: number?, -- Dash
	bounces: number?, -- Dash
	bounceShots: number?, -- Dash
	turnRate: number?, -- Dash
	poolEvery: number?, -- Dash
	poolRadius: number?, -- Dash, Pools
	poolSeconds: number?, -- Dash, Pools
	poolTick: number?, -- Dash, Pools (default 0.5)
	spacing: number?, -- March
	stepSeconds: number?, -- March, Cross
	spinPerBurst: number?, -- Ring
}

-- Enemies that get faster the longer they live (Stalker, B9).
export type Accelerate = {
	perSecond: number, -- share of its base speed it gains every second
	max: number, -- at most this many times its base speed
}

-- Enemies that shoot a ring of projectiles when hit (Thornback, B9). Shots fly like the Spitter's (EnemySim/Volleys).
export type Retaliate = {
	count: number, -- shots in the ring
	cooldownSeconds: number, -- at most one ring this often
	projectileDamage: number, -- grows with the enemy's damage like its contact damage
	projectileSpeed: number,
	projectileRange: number,
	projectileRadius: number,
}

-- Enemies that help the others around them every few seconds while a player is near (Herald buffs, Mender heals; B9).
-- Clients see a ring around it for a moment when it does (Net/Snapshot mode bits).
export type Pulse = {
	radius: number, -- studs around it
	intervalSeconds: number,
	-- Herald: up to `buffCount` enemies that are not buffed yet get stronger for good
	buffCount: number?,
	buffDamage: number?, -- multiplier on contact and shot damage
	buffSpeed: number?, -- multiplier on speed
	buffHp: number?, -- share of max HP added (to HP and max HP)
	-- Mender: every other enemy in the radius heals this share of its max HP
	heal: number?,
}

-- Enemies that stand still and hatch into others after a while unless killed first (Brood Egg, B9).
export type Hatch = {
	seconds: number,
	enemy: string, -- key in types
	count: number,
	spread: number, -- studs around the egg
}

-- Enemies that stop near a player, wind up (a red disc on the floor shows the area) and then hit everyone in the
-- circle (Reaper, B9). Walking out during the wind-up dodges it.
export type Slash = {
	triggerRange: number, -- studs from its centre to the player's
	windupSeconds: number,
	radius: number, -- studs around its centre
	damage: number, -- grows with the enemy's damage like its contact damage
	recoverSeconds: number,
	cooldownSeconds: number, -- walking before the next wind-up
}

-- Enemies that go for the orbs on the floor and eat them; killed they drop what they ate (Gobbler, B9).
export type Eat = {
	seekRange: number, -- studs; it walks to the nearest orb within this, else to the nearest player
	reach: number, -- studs from its edge at which it swallows an orb
}

-- What a killed enemy drops besides its orb (B6, Config.Loot); missing values use the defaults there.
export type Loot = {
	alwaysOrbs: boolean?, -- drops its orb whatever the wave's drop chance
	consumableChance: number?, -- chance of a fruit or crate, before Luck
	crateShare: number?, -- share of those that are crates, before Luck and the crates of this wave
	crate: boolean?, -- always a crate (Looters)
}

-- Enemies that run away from the nearest player and do not attack (Looters, B6). SpawnDirector removes them
-- (without a kill) after Config.Loot.looter.lifetimeSeconds.
export type Flee = {
	edgeMargin: number, -- studs; closer to the arena edge it also runs along the wall, so it is not stuck in a corner
	range: number?, -- B9: flees only from a player closer than this, otherwise acts normally (nil: always)
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
		hpPerWave = 6.8,
		damagePerWave = 1.7,
		xp = 1,
		radius = 1.5,
		mass = 1,
		knockbackResistance = 0, -- B5, like Brotato's Baby Alien
	},
	Brute = {
		id = "Brute",
		typeId = 2,
		displayName = "Brute",
		hp = 60,
		speed = 8,
		contactDamage = 12,
		hpPerWave = 41,
		damagePerWave = 4.1,
		xp = 4,
		radius = 2.5,
		mass = 6,
		knockbackResistance = 0.9, -- B5, like Bruiser
		loot = { consumableChance = 0.03 }, -- B6, assumption: tougher enemies drop more
	},
	Spitter = {
		id = "Spitter",
		typeId = 3,
		displayName = "Spitter",
		hp = 20,
		speed = 10,
		contactDamage = 0,
		hpPerWave = 13.6,
		damagePerWave = 2.7,
		xp = 2,
		radius = 1.5,
		mass = 1,
		knockbackResistance = 0.95, -- B5, like Spitter
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
	-- typeId 4 is the first boss (bosses below)
	Charger = {
		id = "Charger",
		typeId = 5,
		displayName = "Charger",
		hp = 40,
		speed = 9,
		contactDamage = 8,
		hpPerWave = 27,
		damagePerWave = 2.7,
		xp = 4,
		radius = 1.8,
		mass = 3,
		knockbackResistance = 0.8, -- B5, like Charger
		loot = { consumableChance = 0.02 }, -- B6, assumption
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
		hpPerWave = 22,
		damagePerWave = 2.4,
		xp = 2,
		radius = 1.9,
		mass = 2,
		knockbackResistance = 0.5, -- B5, like Helmet Alien
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
		hpPerWave = 4.1,
		damagePerWave = 1,
		xp = 1,
		radius = 1,
		mass = 0.6,
		knockbackResistance = 0, -- B5, like Baby Alien
	},
	-- stronger versions of the first enemies for the second half of the run
	AbyssShadeling = {
		id = "AbyssShadeling",
		typeId = 8,
		displayName = "Abyss Shadeling",
		hp = 18,
		speed = 15,
		contactDamage = 8,
		hpPerWave = 12.2,
		damagePerWave = 2.7,
		xp = 2,
		radius = 1.6,
		mass = 1.2,
		knockbackResistance = 0, -- B5, like Chaser
		look = "Shadeling",
	},
	AbyssBrute = {
		id = "AbyssBrute",
		typeId = 9,
		displayName = "Abyss Brute",
		hp = 140,
		speed = 8.5,
		contactDamage = 18,
		hpPerWave = 95,
		damagePerWave = 6.1,
		xp = 8,
		radius = 2.8,
		mass = 8,
		knockbackResistance = 0.9, -- B5, like Bruiser
		look = "Brute",
		loot = { consumableChance = 0.03 }, -- B6, assumption
	},
	-- B6: Brotato's Loot Alien. Appears now and then (Config.Loot.looter), runs away, escapes after a while; killed
	-- it drops a crate and a big orb. HP like Brotato's (about 12 Shadelings), faster than the crowd.
	Looter = {
		id = "Looter",
		typeId = 10,
		displayName = "Looter",
		hp = 120, -- assumption, see above
		speed = 17,
		contactDamage = 0,
		hpPerWave = 82,
		damagePerWave = 0,
		xp = 8, -- Brotato: 8 materials
		radius = 1.4,
		mass = 1,
		knockbackResistance = 0,
		loot = { alwaysOrbs = true, consumableChance = 1, crate = true },
		flee = { edgeMargin = 12 },
	},
	-- B6: Brotato's Tree. Stands still and does nothing (Config.Loot.trees); killed it drops a fruit (or a crate) and
	-- an orb of 3.
	Tree = {
		id = "Tree",
		typeId = 11,
		displayName = "Tree",
		hp = 30, -- assumption; grows with the HP curve like every enemy
		speed = 0,
		contactDamage = 0,
		hpPerWave = 20.4,
		damagePerWave = 0,
		xp = 3, -- Brotato: 3 materials
		radius = 2.2,
		mass = 1000,
		knockbackResistance = 1,
		loot = { alwaysOrbs = true, consumableChance = 1, crateShare = 0.2 }, -- Brotato: 20 % crates
		anchored = true,
	},
	-- B9 part 2: Brotato's other enemy behaviours, each with its own silhouette or palette (EnemyRenderer/Models).
	-- Values are assumptions in the spirit of the Brotato enemies they follow; check them in the test.
	-- Accelerator (like Brotato's ones that speed up): starts slow, keeps getting faster.
	Stalker = {
		id = "Stalker",
		typeId = 12,
		displayName = "Stalker",
		hp = 14,
		speed = 8,
		contactDamage = 6,
		hpPerWave = 9.5,
		damagePerWave = 2,
		xp = 2,
		radius = 1.5,
		mass = 1,
		knockbackResistance = 0,
		look = "Shadeling",
		accelerate = { perSecond = 0.12, max = 2.4 },
	},
	-- Fleeing shooter: keeps far away, runs off when a player comes close and shoots from a distance.
	Skulker = {
		id = "Skulker",
		typeId = 13,
		displayName = "Skulker",
		hp = 18,
		speed = 13,
		contactDamage = 0,
		hpPerWave = 12.2,
		damagePerWave = 2.4,
		xp = 3,
		radius = 1.5,
		mass = 1,
		knockbackResistance = 0.5,
		look = "Spitter",
		ranged = {
			keepDistance = 36,
			fireInterval = 3,
			fireRange = 40,
			projectileDamage = 7,
			projectileSpeed = 20,
			projectileRange = 55,
			projectileRadius = 0.6,
			aimLead = 0.5,
		},
		flee = { edgeMargin = 12, range = 22 },
	},
	-- Counter-shooter: slow and tough; every hit makes it spray a ring of thorns.
	Thornback = {
		id = "Thornback",
		typeId = 14,
		displayName = "Thornback",
		hp = 70,
		speed = 7,
		contactDamage = 10,
		hpPerWave = 48,
		damagePerWave = 3.4,
		xp = 5,
		radius = 2.3,
		mass = 5,
		knockbackResistance = 0.9,
		look = "Brute",
		loot = { consumableChance = 0.03 },
		retaliate = {
			count = 8,
			cooldownSeconds = 1.5,
			projectileDamage = 6,
			projectileSpeed = 15,
			projectileRange = 26,
			projectileRadius = 0.6,
		},
	},
	-- Buffer: walks with the crowd and makes the enemies around it stronger for good.
	Herald = {
		id = "Herald",
		typeId = 15,
		displayName = "Herald",
		hp = 30,
		speed = 9,
		contactDamage = 4,
		hpPerWave = 20.4,
		damagePerWave = 1.4,
		xp = 4,
		radius = 1.6,
		mass = 1.5,
		knockbackResistance = 0.5,
		look = "Spitter",
		pulse = {
			radius = 14,
			intervalSeconds = 4,
			buffCount = 5,
			buffDamage = 1.5,
			buffSpeed = 1.25,
			buffHp = 0.5,
		},
	},
	-- Healer: heals the enemies around it every few seconds; kill it first.
	Mender = {
		id = "Mender",
		typeId = 16,
		displayName = "Mender",
		hp = 30,
		speed = 9,
		contactDamage = 4,
		hpPerWave = 20.4,
		damagePerWave = 1.4,
		xp = 4,
		radius = 1.6,
		mass = 1.5,
		knockbackResistance = 0.5,
		look = "Spitter",
		pulse = { radius = 14, intervalSeconds = 3, heal = 0.3 },
	},
	-- Egg: lies still and hatches into Shadelings unless it is broken in time.
	BroodEgg = {
		id = "BroodEgg",
		typeId = 17,
		displayName = "Brood Egg",
		hp = 20,
		speed = 0,
		contactDamage = 0,
		hpPerWave = 13.6,
		damagePerWave = 0,
		xp = 1,
		radius = 1.4,
		mass = 1000,
		knockbackResistance = 1,
		anchored = true,
		hatch = { seconds = 5, enemy = "Shadeling", count = 4, spread = 2 },
	},
	-- Slasher: stops next to a player, winds up and cuts everything around it.
	Reaper = {
		id = "Reaper",
		typeId = 18,
		displayName = "Reaper",
		hp = 45,
		speed = 11,
		contactDamage = 0,
		hpPerWave = 30.6,
		damagePerWave = 4.8,
		xp = 4,
		radius = 1.8,
		mass = 3,
		knockbackResistance = 0.8,
		look = "Charger",
		slash = {
			triggerRange = 7,
			windupSeconds = 0.7,
			radius = 7.5,
			damage = 14,
			recoverSeconds = 0.6,
			cooldownSeconds = 1.6,
		},
	},
	-- Loot eater: goes for the orbs on the floor and swallows them; killed it drops all it ate.
	Gobbler = {
		id = "Gobbler",
		typeId = 19,
		displayName = "Gobbler",
		hp = 40,
		speed = 12,
		contactDamage = 5,
		hpPerWave = 27,
		damagePerWave = 1.7,
		xp = 3,
		radius = 1.6,
		mass = 1.5,
		knockbackResistance = 0.3,
		look = "Looter",
		loot = { alwaysOrbs = true },
		eat = { seekRange = 45, reach = 0.8 },
	},
}

-- Gloom Elite: any enemy type, bigger and tougher (Util/EnemyKinds builds one elite variant per type and affix).
local Elite = table.freeze({
	hpMultiplier = 8,
	speedMultiplier = 0.9,
	damageMultiplier = 1.5, -- contact and projectile damage
	sizeMultiplier = 1.5, -- collision radius and model
	massMultiplier = 2.25, -- pushes normal enemies of its type aside (assumption)
	knockbackResistance = 1, -- B5: elites ignore knockback like in Brotato
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

-- WP10: the bosses of the boss wave (the last wave, Run.spawn.waves), after Brotato's two (wave 20, 90 s). One of
-- them comes, picked at random (B11: both on the highest danger level). The wave ends with a victory when every
-- boss is dead or when its time runs out (Brotato). Values from Brotato's Predator and Invoker, scaled like our other
-- enemies (HP about 3.4x, damage about 3x, speed relative to the player); attack numbers the wiki does not give are
-- assumptions. HP and damage then get the difficulty and the team's enemy stats, HP also the player factor
-- (Run.playerFactor). Bosses count as elites for Damage vs Elites and ignore knockback; Heralds and Menders skip them.
local Bosses: { [string]: Enemy } = {
	-- like Brotato's Predator: chases you and dashes, ringed by circling embers; from half HP (or after 45 s) no more
	-- dashes but slams and rings of shots in every direction
	LanternEater = {
		id = "LanternEater",
		typeId = 4,
		displayName = "The Lantern Eater",
		hp = 100000, -- Brotato 29,900
		speed = 11, -- Brotato 300, about 2/3 of the player
		contactDamage = 90, -- Brotato 30
		hpPerWave = 0,
		damagePerWave = 0,
		xp = 0, -- the run ends with it
		radius = 4.5,
		mass = 60,
		knockbackResistance = 1,
		boss = {
			phases = {
				{
					attacks = { "Dash" },
					pauseSeconds = 1.2,
					orbit = { count = 4, radius = 9, turnsPerSecond = 0.35, hitRadius = 1.3, damage = 60 },
				},
				{
					fromHp = 0.5,
					afterSeconds = 45,
					attacks = { "Slam", "Ring" },
					pauseSeconds = 0.8,
					speedMultiplier = 1.15,
					announce = "The Lantern Eater flares up!",
				},
			},
			attacks = {
				Dash = {
					kind = "Dash",
					windupSeconds = 0.8,
					recoverSeconds = 0.9,
					range = 40,
					damage = 90,
					speed = 40,
					distance = 38,
				},
				Slam = {
					kind = "Slam",
					windupSeconds = 1.2,
					recoverSeconds = 0.6,
					cooldownSeconds = 4,
					range = 10,
					damage = 105,
					radius = 14,
				},
				Ring = {
					kind = "Ring",
					windupSeconds = 0.6,
					recoverSeconds = 0.6,
					cooldownSeconds = 3,
					damage = 70, -- Brotato 23 per projectile
					count = 16,
					bursts = 2,
					burstGapSeconds = 0.4,
					projectileSpeed = 16,
					projectileRange = 60,
					projectileRadius = 0.8,
				},
			},
		},
	},
	-- like Brotato's Invoker: slow, calls red circles around every player that strike after a second; at 60 % HP (or
	-- after 30 s) more of them over a wider area; at 40 % (or after 60 s) it runs all over the arena and rings every
	-- player with shots that fly inwards
	HollowSeer = {
		id = "HollowSeer",
		typeId = 20,
		displayName = "The Hollow Seer",
		hp = 100000, -- Brotato 29,900
		speed = 7, -- Brotato 200
		contactDamage = 60, -- Brotato 19.5
		hpPerWave = 0,
		damagePerWave = 0,
		xp = 0,
		radius = 4,
		mass = 60,
		knockbackResistance = 1,
		boss = {
			phases = {
				{ attacks = { "Rain" }, pauseSeconds = 0 },
				{
					fromHp = 0.6,
					afterSeconds = 30,
					attacks = { "WideRain" },
					pauseSeconds = 0,
					announce = "The Hollow Seer's veil tears!",
				},
				{
					fromHp = 0.4,
					afterSeconds = 60,
					attacks = { "Circle" },
					pauseSeconds = 0,
					speedMultiplier = 2.5, -- Brotato: from 200 to 500
					roam = true,
					announce = "The Hollow Seer runs wild!",
				},
			},
			attacks = {
				Rain = {
					kind = "Rain",
					windupSeconds = 1,
					recoverSeconds = 0,
					cooldownSeconds = 2, -- Brotato: every two seconds
					moving = true,
					damage = 60,
					count = 5,
					spread = 10,
					radius = 3,
				},
				WideRain = {
					kind = "Rain",
					windupSeconds = 1,
					recoverSeconds = 0,
					cooldownSeconds = 2,
					moving = true,
					damage = 60,
					count = 10,
					spread = 18,
					radius = 3,
				},
				Circle = {
					kind = "Circle",
					windupSeconds = 1,
					recoverSeconds = 0,
					cooldownSeconds = 2.5,
					moving = true,
					damage = 60,
					count = 12,
					spread = 13,
					projectileSpeed = 14,
					projectileRadius = 0.8,
				},
			},
		},
	},
}

-- How the boss wave brings its bosses (BossService).
local BossWave = table.freeze({
	count = 1, -- bosses per run (B11: 2 on the highest danger level, each with hpShareWhenSeveral of its HP)
	hpShareWhenSeveral = 0.75, -- Brotato
	order = table.freeze({ "LanternEater", "HollowSeer" }), -- picked at random; "SpawnBoss" goes through them in turn
	introSeconds = 2.5, -- after the boss wave starts: red crosses show where it comes
	spawnDistance = 28, -- studs from a random living player
	stateInterval = 0.2, -- seconds between BossState updates (HP bar)
	legendaryCrate = true, -- a killed boss drops a legendary crate (matters once a run goes on after it, B11)
})

for _, boss in Bosses do
	table.freeze(boss)
end

-- WP10 part 2: the champions of the elite waves, after Brotato's eight elites (Rhino, Butcher, Monk, Croc, Colossus,
-- Mantis, Mother, Gargoyle), with our own names and looks. Like the bosses they run phases of attacks (BossService),
-- show an HP bar at the top, count as elites, ignore knockback and drop a legendary crate. Brotato: 1 HP + 750 per
-- wave (Monk 700), 1 contact damage + 1.5 per wave; scaled like our other enemies (HP x 3.4 per step, damage x 2.8)
-- and grown by Run.spawn.growth like every enemy, HP also with the player factor (Run.playerFactor). Their attacks
-- hit as hard as their contact damage (the wiki gives no projectile damage, assumption) and grow alike. Speeds:
-- Brotato's 200-350 like the bosses (300 = 13 studs/s). Attack timings follow the wiki ("charges every 2 s"); wind-up
-- times, distances, projectile speeds and counts it does not give are assumptions, counts kept within the
-- projectile budget (DESIGN.md section 15).
local CHAMPION_HP_PER_WAVE = 2550 -- Brotato 750
local CHAMPION_DAMAGE_PER_WAVE = 4.25 -- Brotato 1.5

local function champion(id: string, typeId: number, displayName: string, speed: number, plan: BossPlan): Enemy
	return {
		id = id,
		typeId = typeId,
		displayName = displayName,
		hp = 3, -- Brotato 1
		speed = speed,
		contactDamage = 3, -- Brotato 1
		hpPerWave = CHAMPION_HP_PER_WAVE,
		damagePerWave = CHAMPION_DAMAGE_PER_WAVE,
		xp = 25, -- like a Gloom Elite (Brotato: 10 materials)
		radius = 3.2,
		mass = 30,
		knockbackResistance = 1,
		boss = plan,
	}
end

-- side projectiles of the charges
local TRAIL_SHOT = { projectileSpeed = 12, projectileRange = 18, projectileRadius = 0.6 }

local function with(base: { [string]: any }, extra: { [string]: any }): BossAttack
	local attack = table.clone(base)
	for key, value in extra do
		attack[key] = value
	end
	return attack :: any
end

local Champions: { [string]: Enemy } = {
	-- Rhino: charges every 2 s, throwing projectiles to its sides; at 60 % HP (or after 25 s) every 1.3 s, shorter,
	-- with 2 more projectiles at you when it starts. Signature: its first charges bounce off walls and pillars twice,
	-- bursting a ring of projectiles at each bounce.
	BrassRam = champion("BrassRam", 21, "The Brass Ram", 11, {
		phases = {
			{ attacks = { "Charge" }, pauseSeconds = 0.6 },
			{
				fromHp = 0.6,
				afterSeconds = 25,
				attacks = { "QuickCharge" },
				pauseSeconds = 0.3,
				announce = "The Brass Ram is enraged!",
			},
		},
		attacks = {
			Charge = with(TRAIL_SHOT, {
				kind = "Dash",
				windupSeconds = 0.8,
				recoverSeconds = 0.6,
				range = 45,
				damage = 3,
				speed = 38,
				distance = 70, -- room for its bounces
				trailEvery = 6,
				bounces = 2,
				bounceShots = 8,
			}),
			QuickCharge = with(TRAIL_SHOT, {
				kind = "Dash",
				windupSeconds = 0.5,
				recoverSeconds = 0.3,
				range = 40,
				damage = 3,
				speed = 40,
				distance = 20,
				trailEvery = 5,
				startShots = 2,
				arc = 20,
			}),
		},
	}),
	-- Butcher: 4 slashes at you every 1.25 s; at 70 % HP (or 25 s) it throws (Brotato: 8 slashes all around); at 40 %
	-- (or 40 s) 3 quick slashes every 0.75 s that hurt a third less. Signature: 3 cleavers that fly out and come back.
	Flayer = champion("Flayer", 22, "The Flayer", 9, {
		phases = {
			{ attacks = { "Cleave" }, pauseSeconds = 0.3 },
			{
				fromHp = 0.7,
				afterSeconds = 25,
				attacks = { "Cleavers", "Cleave" },
				pauseSeconds = 0.3,
				announce = "The Flayer throws its cleavers!",
			},
			{ fromHp = 0.4, afterSeconds = 40, attacks = { "Cleavers", "QuickCleave" }, pauseSeconds = 0.1 },
		},
		attacks = {
			Cleave = {
				kind = "Cleave",
				windupSeconds = 0.6,
				recoverSeconds = 0.3,
				cooldownSeconds = 1.25,
				range = 18,
				damage = 3,
				count = 4,
				arc = 60,
				distance = 16,
				radius = 1.2,
			},
			Cleavers = {
				kind = "Boomerang",
				windupSeconds = 0.5,
				recoverSeconds = 0.4,
				cooldownSeconds = 2.5,
				range = 40,
				damage = 3,
				count = 3,
				arc = 50,
				projectileSpeed = 16,
				projectileRange = 26,
				projectileRadius = 1,
			},
			QuickCleave = {
				kind = "Cleave",
				windupSeconds = 0.45,
				recoverSeconds = 0.15,
				cooldownSeconds = 0.75,
				range = 18,
				damage = 2,
				count = 3,
				arc = 40,
				distance = 16,
				radius = 1.2,
			},
		},
	}),
	-- Monk: lays eggs, then (10 s) fires 5 projectiles a second at you; at 30 s it runs away for 10 s calling helpers,
	-- then shoots again. Brotato switches by time only; the HP shares are ours (assumption), so damage moves it on too.
	Abbot = (function()
		local abbot = champion("Abbot", 23, "The Abbot", 15, {
			phases = {
				{ attacks = { "Eggs" }, pauseSeconds = 1.5 },
				{ fromHp = 0.85, afterSeconds = 10, attacks = { "Bolts" }, pauseSeconds = 0 },
				{
					fromHp = 0.5,
					afterSeconds = 30,
					attacks = { "Helpers" },
					pauseSeconds = 1,
					speedMultiplier = 1.1,
					flee = true,
					announce = "The Abbot flees and calls for help!",
				},
				{ fromHp = 0.3, afterSeconds = 40, attacks = { "Bolts" }, pauseSeconds = 0 },
			},
			attacks = {
				Eggs = {
					kind = "Summon",
					windupSeconds = 1,
					recoverSeconds = 0.5,
					cooldownSeconds = 30, -- once in this phase
					damage = 0,
					enemy = "BroodEgg", -- Brotato: 15 Slasher Eggs
					count = 6,
					spread = 8,
				},
				Bolts = {
					kind = "Volley",
					windupSeconds = 0.4,
					recoverSeconds = 0.2,
					range = 60,
					damage = 3,
					count = 1,
					bursts = 5,
					burstGapSeconds = 0.2,
					projectileSpeed = 18,
					projectileRange = 55,
					projectileRadius = 0.6,
				},
				Helpers = {
					kind = "Summon",
					windupSeconds = 0.6,
					recoverSeconds = 0.3,
					cooldownSeconds = 3,
					moving = true,
					damage = 0,
					enemy = "Reaper", -- Brotato: Tentacles
					count = 2,
					spread = 6,
				},
			},
		})
		abbot.hpPerWave = 2380 -- Brotato 700
		return abbot
	end)(),
	-- Croc: lunges every second and bites around itself; at 60 % HP (or 25 s) more (Brotato: a circle of projectiles
	-- around you). Signature: a death roll that steers after you, from phase 2 leaving pools of mud behind.
	MireJaw = champion("MireJaw", 24, "The Mire Jaw", 15, {
		phases = {
			{ attacks = { "Snap", "Roll" }, pauseSeconds = 0.3 },
			{
				fromHp = 0.6,
				afterSeconds = 25,
				attacks = { "Snap", "MudRoll" },
				pauseSeconds = 0.2,
				announce = "The Mire Jaw churns the mud!",
			},
		},
		attacks = {
			Roll = {
				kind = "Dash",
				windupSeconds = 0.6,
				recoverSeconds = 0.5,
				cooldownSeconds = 1.5,
				range = 35,
				damage = 3,
				speed = 24,
				distance = 36,
				turnRate = 90,
			},
			MudRoll = {
				kind = "Dash",
				windupSeconds = 0.5,
				recoverSeconds = 0.4,
				cooldownSeconds = 1.2,
				range = 40,
				damage = 3,
				speed = 26,
				distance = 40,
				turnRate = 110,
				poolEvery = 7,
				poolRadius = 3,
				poolSeconds = 4,
			},
			Snap = {
				kind = "Slam",
				windupSeconds = 0.5,
				recoverSeconds = 0.2,
				cooldownSeconds = 2,
				range = 6,
				damage = 3,
				radius = 7,
			},
		},
	}),
	-- Colossus: chases you under a hail of projectiles every second (Brotato: 50 in a big area); at 60 % HP (or 25 s)
	-- wanders the arena and rings you with projectiles. Signature: a quake line, a row of circles that runs from it
	-- over you and beyond.
	Monolith = (function()
		local monolith = champion("Monolith", 25, "The Monolith", 13, {
			phases = {
				{ attacks = { "Quake", "Hail" }, pauseSeconds = 0.4 },
				{
					fromHp = 0.6,
					afterSeconds = 25,
					attacks = { "Quake", "Encircle" },
					pauseSeconds = 0.2,
					roam = true,
					announce = "The Monolith wanders off!",
				},
			},
			attacks = {
				Quake = {
					kind = "March",
					windupSeconds = 0.7,
					recoverSeconds = 0.3,
					cooldownSeconds = 2.5,
					range = 45,
					damage = 3,
					count = 12,
					spacing = 4,
					radius = 2.5,
					stepSeconds = 0.08,
				},
				Hail = {
					kind = "Scatter",
					windupSeconds = 0.4,
					recoverSeconds = 0,
					cooldownSeconds = 1.5,
					moving = true,
					damage = 3,
					count = 14,
					projectileSpeed = 10,
					projectileRange = 40,
					projectileRadius = 0.7,
				},
				Encircle = {
					kind = "Circle",
					windupSeconds = 1,
					recoverSeconds = 0,
					cooldownSeconds = 1.5, -- Brotato 0.5
					moving = true,
					damage = 3,
					count = 10,
					spread = 14,
					projectileSpeed = 13,
					projectileRadius = 0.7,
				},
			},
		})
		monolith.radius = 3.8
		monolith.mass = 50
		return monolith
	end)(),
	-- Mantis: chases you and slashes every 1.25 s; at 60 % HP (or 25 s) charges every 1.3 s, leaving slashes behind.
	-- Signature: a big X of two cuts right on you (step out diagonally); from phase 2 three in a row around you,
	-- between its pounces.
	SickleWraith = champion("SickleWraith", 26, "The Sickle Wraith", 11, {
		phases = {
			{ attacks = { "Cross" }, pauseSeconds = 0.4 },
			{
				fromHp = 0.6,
				afterSeconds = 25,
				attacks = { "TripleCross", "Pounce" },
				pauseSeconds = 0.2,
				announce = "The Sickle Wraith pounces!",
			},
		},
		attacks = {
			Cross = {
				kind = "Cross",
				windupSeconds = 0.8,
				recoverSeconds = 0.3,
				cooldownSeconds = 1.25,
				range = 40,
				moving = true,
				damage = 3,
				count = 1,
				distance = 22,
				radius = 1.1,
			},
			TripleCross = {
				kind = "Cross",
				windupSeconds = 0.7,
				recoverSeconds = 0.3,
				cooldownSeconds = 2.5,
				range = 40,
				damage = 3,
				count = 3,
				distance = 18,
				radius = 1,
				spread = 8,
				stepSeconds = 0.35,
			},
			Pounce = with(TRAIL_SHOT, {
				kind = "Dash",
				windupSeconds = 0.6,
				recoverSeconds = 0.3,
				cooldownSeconds = 1.3,
				range = 40,
				damage = 3,
				speed = 40,
				distance = 26,
				trailEvery = 4,
			}),
		},
	}),
	-- Mother: a four-pronged slash every 1.4 s; at 60 % HP (or 25 s) double slashes every 0.65 s and a stream of
	-- small enemies (Brotato: about 9 Fin Aliens a second; fewer here, the alive cap would stop them anyway).
	-- Signature: acid sacs it drops around itself, pools that stay and hurt; it is the only one slashing all around.
	BroodMatron = champion("BroodMatron", 27, "The Brood Matron", 11, {
		phases = {
			{ attacks = { "Prongs", "Acid" }, pauseSeconds = 0.3 },
			{
				fromHp = 0.6,
				afterSeconds = 25,
				attacks = { "Brood", "Acid", "DoubleProngs" },
				pauseSeconds = 0.1,
				announce = "The Brood Matron's young hatch!",
			},
		},
		attacks = {
			Prongs = {
				kind = "Cleave",
				windupSeconds = 0.6,
				recoverSeconds = 0.2,
				cooldownSeconds = 1.4,
				range = 16,
				damage = 3,
				count = 4,
				around = true,
				distance = 14,
				radius = 1.2,
			},
			DoubleProngs = {
				kind = "Cleave",
				windupSeconds = 0.4,
				recoverSeconds = 0.1,
				cooldownSeconds = 0.65,
				range = 16,
				damage = 3,
				count = 8,
				around = true,
				distance = 14,
				radius = 1.2,
			},
			Acid = {
				kind = "Pools",
				windupSeconds = 0.4,
				recoverSeconds = 0.2,
				cooldownSeconds = 3,
				moving = true,
				damage = 3,
				count = 3,
				spread = 10,
				poolRadius = 3.5,
				poolSeconds = 5,
			},
			Brood = {
				kind = "Summon",
				windupSeconds = 0.3,
				recoverSeconds = 0,
				cooldownSeconds = 2,
				moving = true,
				damage = 0,
				enemy = "Shadeling",
				count = 4,
				spread = 5,
			},
		},
	}),
	-- Gargoyle: wanders, a big ring of projectiles again and again; at 60 % HP (or 30 s) chases you; at 30 % (or 45 s)
	-- sprays projectiles in random directions. Signature: its rings turn into a spiral, and in phase 2 it dives onto
	-- your spot (a shadow on the floor) and bursts a ring where it lands.
	StoneSeraph = champion("StoneSeraph", 28, "The Stone Seraph", 15, {
		phases = {
			{ attacks = { "Spiral" }, pauseSeconds = 0.3, roam = true },
			{
				fromHp = 0.6,
				afterSeconds = 30,
				attacks = { "Dive", "Barrage" },
				pauseSeconds = 0.2,
				announce = "The Stone Seraph takes to the air!",
			},
			{
				fromHp = 0.3,
				afterSeconds = 45,
				attacks = { "Spray" },
				pauseSeconds = 0,
				announce = "The Stone Seraph cracks!",
			},
		},
		attacks = {
			Spiral = {
				kind = "Ring",
				windupSeconds = 0.3,
				recoverSeconds = 0.2,
				cooldownSeconds = 2.5, -- Brotato: a ring every 0.3 s
				moving = true,
				damage = 3,
				count = 6,
				bursts = 10,
				burstGapSeconds = 0.15,
				spinPerBurst = 11,
				projectileSpeed = 12,
				projectileRange = 45,
				projectileRadius = 0.7,
			},
			Dive = {
				kind = "Leap",
				windupSeconds = 1.1,
				recoverSeconds = 0.5,
				cooldownSeconds = 3,
				range = 50,
				damage = 3,
				radius = 6,
				count = 10,
				projectileSpeed = 12,
				projectileRange = 30,
				projectileRadius = 0.7,
			},
			Barrage = {
				kind = "Volley",
				windupSeconds = 0.3,
				recoverSeconds = 0,
				cooldownSeconds = 0.8, -- Brotato: 12 every 0.4 s
				moving = true,
				range = 60,
				damage = 3,
				count = 5,
				arc = 50,
				projectileSpeed = 15,
				projectileRange = 50,
				projectileRadius = 0.6,
			},
			Spray = {
				kind = "Scatter",
				windupSeconds = 0.05,
				recoverSeconds = 0,
				cooldownSeconds = 0.15, -- Brotato 0.01-0.15
				moving = true,
				damage = 3,
				count = 3,
				projectileSpeed = 13,
				projectileRange = 40,
				projectileRadius = 0.6,
			},
		},
	}),
}

-- Brotato's elite waves (DESIGN.md section 7): one champion joins the wave's normal enemies, after red crosses like
-- the boss. Brotato: danger 2-3 one challenging wave (11 or 12), danger 4-5 three (11/12, 14/15, 17/18), 60 % of
-- them elite, the rest horde waves. Until the danger levels come (B11) the first slot is on and always an elite wave.
local EliteWaves = table.freeze({
	slots = table.freeze({ table.freeze({ 11, 12 }), table.freeze({ 14, 15 }), table.freeze({ 17, 18 }) }),
	activeSlots = 1, -- B11: by danger level
	count = 1, -- champions per elite wave (Brotato; endless mode brings more)
	-- picked at random, never twice in a run; "SpawnChampion" goes through them in turn
	order = table.freeze({
		"BrassRam",
		"Flayer",
		"Abbot",
		"MireJaw",
		"Monolith",
		"SickleWraith",
		"BroodMatron",
		"StoneSeraph",
	}),
	reducedHpWaves = table.freeze({ 11, 12 }), -- Brotato: elites come with 75 % HP in waves 11 and 12
	reducedHpShare = 0.75,
	introSeconds = 2.5, -- after the wave starts: red crosses show where it comes
	debugMinWave = 11, -- "SpawnChampion" in an earlier wave grows it like this wave (else it has 3 HP in wave 1)
	legendaryCrate = true, -- a killed champion drops a legendary crate (Brotato)
})

for _, champion in Champions do
	table.freeze(champion)
end

return table.freeze({
	types = table.freeze(Enemies),
	elite = Elite,
	bosses = table.freeze(Bosses),
	bossWave = BossWave,
	champions = table.freeze(Champions), -- WP10 part 2
	eliteWaves = EliteWaves,
	boss = Bosses.LanternEater, -- the HUD's label for the old boss phase (unused since WP10)
})
