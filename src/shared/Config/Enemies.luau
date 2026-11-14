--!strict
-- Enemy, elite, champion and boss records (DESIGN.md section 7). Read by EnemySim, SpawnDirector, BossService and
-- EnemyRenderer.
-- `typeId` is the 1-byte id sent in enemy snapshots; it must be unique and stay stable.

export type Enemy = {
	id: string,
	typeId: number,
	displayName: string,
	hp: number,
	speed: number, -- minimum studs/s; wiki speed / 450 * player base speed
	speedMax: number?,
	nativeSpeedPoints: { base: number, randomization: number }?, -- native integer random offset then final rounding -- sampled once at spawn
	firstWave: number?,
	firstWaveByDanger: { [number]: number }?,
	minDanger: number?,
	specialSpawn: boolean?, -- trees, loot encounters and lure enemies are not ordinary groups
	shotDamagePerWave: number?,
	contactDamage: number,
	-- B9, Brotato: HP and damage grow by these per growth step (damage: contact damage, or the shot damage of an
	-- enemy without contact damage); wave n uses exactly n - 1 growth steps.
	-- Growth is exactly base + per-wave increment * (wave - 1), before danger and accessibility modifiers.
	hpPerWave: number,
	damagePerWave: number,
	xp: number,
	radius: number, -- body circle, studs (assumption; walls, crowding and the picture's size)
	hurtRadius: number?, -- studs; the player's weapons hit within it (Brotato's Hurtbox; filled in below)
	hitRadius: number?, -- studs; touches the player within it (Brotato's Hitbox; 0 never touches; filled in below)
	mass: number, -- crowd weight: heavier enemies push lighter ones aside (assumption)
	-- share of a knockback the enemy ignores (0..1, Brotato's knockback resistance, B5); default 1 - 1 / mass above 1
	knockbackResistance: number?,
	nativeArtPending: boolean?, -- explicit fallback presentation; no original art acceptance
	nativeMovement: {
		goalInsetX: number,
		goalInsetZ: number,
		borderClamp: boolean,
		collidePlayers: boolean,
		precision: number,
	}?, -- native goal rectangle differs from physical origin bounds
	nativeHitOffsetX: number?,
	nativeHitOffsetZ: number?,
	nativeHitChildX: number?,
	nativeHitChildZ: number?, -- unscaled Collision position inside Hitbox, for native parent growth
	nativeHurtOffsetX: number?,
	nativeHurtOffsetZ: number?,
	nativeHurtChildX: number?,
	nativeHurtChildZ: number?, -- unscaled Collision position inside Hurtbox, for native parent growth
	nativeBodyOffsetX: number?,
	nativeBodyOffsetZ: number?, -- Collision.position in the original actor-local coordinate system
	nativeObstacleCollision: boolean?, -- original OBSTACLES_BIT in the body mask, independent of is_flying
	nativeZoneId: number?, -- an area-specific body never joins another area's ordinary random mix
	nativeHurtSlowEffects: boolean?, -- false when the source overrides Enemy._on_hurt without invoking its generic slow effects
	look: string?, -- reuses the model of this enemy id in another color (EnemyRenderer/Models); default: its own id
	ranged: Ranged?,
	charge: Charge?,
	nativeCharge: NativeCharge?,
	nativeFollowXShare: number?,
	split: Split?,
	-- set only on the variants built by Util/EnemyKinds
	elite: boolean?,
	affix: number?, -- index into elite.affixes, 1 or more
	damageTaken: number?, -- multiplier on every hit it takes (1 if nil)
	summon: Summon?,
	nativeSpawn: NativeSpawn?,
	-- since B6 (Config.Loot)
	loot: Loot?,
	flee: Flee?,
	anchored: boolean?, -- never moves, nothing pushes it (Trees); players walk through it
	removeFirst: boolean?, -- Brotato's to_be_removed_in_priority: goes first when the enemy maximum removes some
	wander: Wander?, -- walks to random spots instead of the nearest player (also instead of keepDistance)
	stayInRange: StayInRange?, -- keeps this distance from the nearest player, walking towards or away at full speed
	anticipate: { seconds: number, horizontalOnly: boolean }?, -- native anticipation uses target input; vertical-targeting keeps its current z
	-- since B9 part 2 (Brotato's enemy behaviours, DESIGN.md section 7)
	accelerate: Accelerate?,
	pursuer: Pursuer?,
	nativeDetection: NativeDetection?,
	retaliate: Retaliate?,
	pulse: Pulse?,
	hatch: Hatch?,
	slash: Slash?,
	eat: Eat?,
	-- since WP10: a boss of the boss wave (Config.Enemies.bosses) or, since WP10 part 2, a champion of an elite wave
	-- (Config.Enemies.champions); BossService runs its phases and attacks
	boss: BossPlan?,
}

-- Bosses and champions (Brotato 1.2.0.1 entities/units/enemies/bosses: boss.gd, boss_state.gd and the attack and
-- movement behaviors): a list of states. The first runs from the spawn; every second (CheckStateTimer) the boss
-- switches to the last later state whose HP share (hpStart) or seconds since its spawn (timerStart) is reached. Each
-- state has one movement and one attack; BossService/BossBrain carries them out.
export type BossPlan = {
	states: { BossState },
	orbit: BossOrbit?, -- projectiles on a turning arm around it (Predator)
}

export type BossState = {
	hpStart: number?, -- not for the first state
	timerStart: number?,
	-- "Follow" walks at the nearest player, "Roam" to random spots of the arena, "AroundPlayer" to random spots
	-- within `range` (+- rangeRandom, rolled once) of the nearest player, "KeepDistance" stays `range` away from it
	movement: string,
	range: number?, -- studs
	rangeRandom: number?,
	speedPercent: number?, -- on its base speed in this state (Brotato reset_speed_stat)
	attack: BossAttack,
	chargeShots: BossAttack?, -- a Shoot fired while it charges (Rhino, Croc, Mantis) ...
	chargeShotEvery: number?, -- ... every this many seconds, the first one when the charge starts
	extraShot: BossAttack?, -- a Shoot fired with every strike of `attack` (Mom)
	orbitTurnMultiplier: number?, -- the orbit turns this much faster from this state on
}

-- Brotato's Predator: projectiles on one arm that turns around the boss (Pivot); each slides out from its centre at
-- growSpeed until it reaches its distance. They stay when they hit.
export type BossOrbit = {
	distances: { number }, -- studs
	growSpeed: number, -- studs/s
	turnSpeed: number, -- radians/s, direction picked at random at spawn
	hitRadius: number,
	damage: number, -- plus damagePerWave for every wave after the first
	damagePerWave: number,
}

-- One attack. Every attack first plays the boss's "shoot" animation for windupSeconds (it flashes red), then:
--   Shoot: `count` projectiles (Brotato shooting_attack_behavior): each spawns at the boss or, with onTarget, at the
--     nearest player; onBorders puts them on a circle of spawnSpread/2 (evenly with constantSpread, else at random),
--     otherwise at random in a square spawnSpread wide (the first one in the middle with oneOnTarget). Each flies
--     from its spot towards the player (aim "Movement": along the boss's walk, "Away": away from the boss), turned by
--     a random angle up to `spread` (constantSpread: evenly over -spread..spread), or in a random direction.
--     `projectile`: "Bullet" (enemy bullet), "Pillar" (a circle that strikes once after a moment), "Slash" (a strip
--     through its spot that strikes once), "SlashAhead" (the same strip in front of its spot).
--   Charge: rushes at the player's position of the wind-up start for chargeSeconds at its speed + chargeSpeed, then
--     stands still for recoverSeconds. Contact hurts like touching it.
--   Spawn: `spawnCount` enemies of `enemy` at random spots in a square spawnArea wide around it.
-- A Shoot or Charge starts only while the nearest player is minRange..maxRange from its centre. Its cooldown runs
-- after the strike (a Charge's from the rush start, plus chargeSeconds).
export type BossAttack = {
	kind: string,
	windupSeconds: number,
	cooldownSeconds: number,
	cooldownRandomSeconds: number?, -- the cooldown is rolled in cooldownSeconds +- this (at least one frame)
	initialSeconds: number?, -- extra wait before its first strike in the state
	minRange: number?,
	maxRange: number?,
	-- Shoot
	projectile: string?,
	count: number?,
	projectileSpeed: number?, -- studs/s
	spread: number?, -- radians
	constantSpread: boolean?,
	randomDirection: boolean?,
	onTarget: boolean?,
	spawnSpread: number?, -- studs
	onBorders: boolean?,
	oneOnTarget: boolean?,
	aim: string?,
	damage: number?, -- per projectile, plus damagePerWave for every wave after the first
	damagePerWave: number?,
	-- Charge
	chargeSeconds: number?,
	chargeSpeed: number?, -- studs/s on top of its walking speed
	recoverSeconds: number?,
	-- Spawn
	enemy: string?, -- key in Config.Enemies.types
	spawnCount: number?,
	spawnArea: number?, -- studs
}

-- Boss projectiles: the enemy bullet, and pillars and slashes (Brotato projectiles/pillar_enemy and projectiles/slash),
-- which show on the floor from the strike and hurt each player once while their hitbox is on (hitFrom..hitUntil s).
export type BossProjectiles = {
	bullet: { radius: number, range: number },
	pillar: { radius: number, hitFrom: number, hitUntil: number },
	slash: { from: number, to: number, halfWidth: number, hitFrom: number, hitUntil: number, aheadOffset: number },
}

-- Enemies that get faster the longer they live (Stalker, B9).
-- Brotato's Pursuer: every everySeconds it gains perStep of its base speed (boost_self: +speed_on_boost), at most
-- maxSteps times; with resetOnHit it loses them all when it touches a player.
export type Accelerate = {
	everySeconds: number,
	perStep: number,
	maxSteps: number,
	resetOnHit: boolean?,
}

export type NativeDetection = { radius: number, speedBonus: number }

-- Native flat Pursuer boosts with optional player-speed cap and source contact reset.
export type Pursuer = {
	everySeconds: number,
	maxSteps: number,
	speedPerStep: number,
	damagePercentPerStep: number,
	sizePerStep: number,
	collisionScalingShare: number,
	spriteRise: number,
	changeAt: number,
	changeSpeed: number,
	playerSpeedShare: number?,
	resetOnContact: boolean?,
}

-- Enemies that shoot a ring of projectiles when hit (Thornback, B9). Shots fly like the Spitter's (EnemySim/Volleys).
export type Retaliate = {
	count: number, -- shots in the ring
	cooldownSeconds: number, -- at most one ring this often
	projectileDamage: number, -- independent projectile damage growth
	rangedOnly: boolean?,
	randomDirections: boolean?, -- Horned Fly: independent random directions instead of an evenly spaced ring
	fromCenter: boolean?,
	nativeVolley: {
		count: number,
		spread: number,
		constantSpread: boolean,
		offsetX: number,
		offsetZ: number,
		speedStep: number,
	}?,
	chance: number?,
	projectileSpeed: number,
	projectileRange: number,
	projectileRadius: number,
}

-- Enemies that help the others around them every few seconds while a player is near (Herald buffs, Mender heals; B9).
-- Clients see a ring around it for a moment when it does (Net/Snapshot mode bits).
export type Pulse = {
	radius: number, -- studs around it
	intervalSeconds: number,
	firstSeconds: number?, -- the first pulse this long after the spawn (default: part of intervalSeconds)
	onEnter: boolean?, -- heals each hurt enemy once when it comes into the radius instead of every interval
	-- Herald: up to `buffCount` enemies that are not buffed yet get stronger for good
	buffCount: number?,
	nativeResetStats: boolean?, -- Corrupted Buffer recalculates source stats and fully restores HP
	buffDamage: number?, -- multiplier on contact and shot damage
	buffSpeed: number?, -- multiplier on speed
	buffHp: number?, -- share of max HP added (to HP and max HP)
	-- Mender: every other enemy in the radius heals this share of its max HP
	heal: number?,
	healFlat: number?, -- base healing plus healPerWave * (wave - 1)
	healPerWave: number?,
	nativeEnemyEntry: boolean?, -- original enemy-mask entry healing, including bosses; retained hostile mask after Charm
}

-- Enemies that stand still and hatch into others after a while unless killed first (Brood Egg, B9).
export type Hatch = {
	nativeDeath: boolean?, -- native egg calls die() after spawning; ordinary legacy eggs keep their existing path
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

-- Brotato's StayInRangeFromPlayer movement (Buffer): the spot `distance` (+- jitter, rolled once) px from the nearest
-- player on the line through it, in studs here.
export type StayInRange = {
	distance: number,
	jitter: number,
}

-- Enemies that walk to random spots (Brotato's TargetRandPos / TargetRandPosAroundPlayer movement): a new spot once
-- they are within arriveStuds of the last one (Brotato: 10 px) or after maxSeconds (ours, so nothing gets stuck at an
-- obstacle). "Arena": anywhere in the arena. "Target": up to `range` (+- rangeJitter, rolled once per enemy) from the
-- nearest player on each axis.
export type Wander = {
	around: "Arena" | "Target" | "Offset",
	within: boolean?, -- "Offset" (Brotato's FollowRandPosAroundPlayer): anywhere in the square, else on its circle
	range: number?,
	rangeJitter: number?,
	arriveStuds: number,
	maxSeconds: number,
}

-- Enemies that hold their distance and shoot (Spitter). Projectiles fly straight, are stopped by obstacles and
-- hurt the first player they touch (EnemySim/Volleys).
export type Ranged = {
	keepDistance: number, -- studs; EnemySim keeps it there
	keepDistanceJitter: number?, -- studs either way, rolled once per enemy (Brotato's target_range_randomization)
	fireInterval: number, -- seconds between shots
	fireRange: number, -- studs; shoots only at a player this close (assumption)
	projectileDamage: number,
	projectileSpeed: number, -- studs/s
	projectileRange: number, -- studs a shot flies before it fades
	projectileRadius: number, -- studs, hit circle of a shot (Brotato: 17 px)
	nativeSlash: boolean?, -- emits source slash requests instead of ordinary bullets
	nativePillar: boolean?, -- delayed native circle projectile, distinct from an always-active bullet
	projectileCount: number?, -- independent shots per native animation method
	fromCenter: boolean?,
	nativeTiming: {
		fireInterval: number,
		cooldownRandomSeconds: number,
		initialSeconds: number,
		fireAt: number,
		animationSeconds: number,
		longEvery: number?,
		longSeconds: number?,
		minimumCooldownSeconds: number?,
	}?,
	aimLead: number, -- 0 = aims where the player is, 1 = where a player walking straight on will be (Brotato: 0)
	minFireRange: number?, -- studs; holds its shot while the target is closer (Brotato's Junkie: 200 px)
	spreadRadians: number?, -- each shot turns by a random angle within +- this (Brotato's projectile_spread)
	-- share of its speed it backs off with when a player comes closer than keepDistance (default 1). Playtest after
	-- Paket 24: shooters that ran off at full speed were impossible to catch, so they now back off slowly.
	retreatSpeedFactor: number?,
}

-- Enemies that stop, wind up (clients see it glow) and then rush in a straight line at where the player stood
-- (Charger, since the fun package after WP9). Side-stepping during the wind-up dodges it.
export type Charge = {
	triggerRange: number, -- studs; winds up when the nearest player is this close and the cooldown is over
	windupSeconds: number, -- standing still and glowing before the rush
	speed: number, -- studs/s during the rush
	projectileDamage: number?, -- optional side shots while charging (Hookfang)
	projectileSpeed: number?,
	projectileRange: number?,
	projectileRadius: number?,
	trailEvery: number?,
	trailAngle: number?, -- radians between the rush direction and each side shot (default a right angle)
	maxDistance: number, -- studs; the rush ends here, at an obstacle, the arena edge or a player
	recoverSeconds: number, -- standing still after the rush
	-- Brotato's cooldown, counted from the rush's start after the rush (so it includes the recovery) and as the whole
	-- first wait after the spawn
	cooldownSeconds: number,
	cooldownRandomSeconds: number?, -- each cooldown is rolled in cooldownSeconds +- this
}

-- Enemies that fall apart into smaller ones when killed (Splitter). The new ones keep the minute and difficulty
-- multipliers of the parent and may go above the alive cap (up to Run.spawn.cap.max).
export type Split = {
	enemy: string, -- key in types
	count: number,
	spread: number, -- studs from the parent's centre
	area: number?, -- instead: each at a random spot in a square this many studs wide around it
}

-- Elites with the Summoner affix call enemies around themselves every intervalSeconds while a player is around.
-- Native spawning attacks have animation-method timing and delayed births, unlike legacy immediate summoners.
export type NativeSpawn = {
	enemy: string,
	count: number,
	area: number,
	maxCount: number,
	dieOnRequest: boolean,
	timing: {
		fireInterval: number,
		cooldownRandomSeconds: number,
		minimumCooldownSeconds: number,
		initialSeconds: number,
		fireAt: number,
		animationSeconds: number,
	},
}
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

-- Source: https://brotato.wiki.spellsandguns.com/Enemies (Crash Zone, 2026-11-06).
-- Only distances/speeds are converted to Roblox world units; HP and damage use the original units.
local Player = require(script.Parent.Player)
local Simulation = require(script.Parent.Simulation)
local function speed(value: number): number
	return value / 450 * Player.moveSpeed
end

-- Enemy projectiles (Brotato 1.2.0.1 projectiles/bullet_enemy): hit circle 17 px; they fly until they leave the
-- zone, here until the arena edge or an obstacle stops them (SHOT_RANGE is longer than the arena is wide).
local PIXEL = Player.moveSpeed / 450 -- studs per Brotato pixel
local SHOT_RADIUS = 17 * PIXEL
local SHOT_RANGE = 300

-- Enemy and boss attacks in Brotato's units: distances and speeds in pixels (PIXEL studs each), times in frames at 60 fps.
local function px(value: number): number
	return value * PIXEL
end
local function frames(value: number): number
	return value / 60
end
-- every charging enemy, boss and elite plays the 0.4 s "enemy_charge_prep" animation, at attack_anim_speed, before it strikes
local function windup(animSpeed: number): number
	return 0.4 / animSpeed
end

-- Brotato's ChargingAttackBehavior (Charger, Bruiser, Horned Bruiser, Horned Charger): once the nearest player is
-- within maxRange px and the cooldown is over, it winds up (the 0.4 s prep animation), then rushes at the player's
-- position of the wind-up start for `duration` s at its own speed + chargeSpeed px/s (through players, they do not
-- block enemies), stands for 0.05 s (recovery_duration) and walks again. Cooldown and its randomization in frames.
local function brotatoCharge(
	walkSpeed: number,
	f: {
		maxRange: number,
		chargeSpeed: number,
		duration: number,
		cooldown: number,
		cooldownRandom: number,
		animSpeed: number?,
	}
): Charge
	local rushSpeed = walkSpeed + px(f.chargeSpeed)
	return {
		triggerRange = px(f.maxRange),
		windupSeconds = windup(f.animSpeed or 1),
		speed = rushSpeed,
		maxDistance = rushSpeed * f.duration,
		recoverSeconds = 0.05,
		cooldownSeconds = frames(f.cooldown),
		cooldownRandomSeconds = frames(f.cooldownRandom),
	}
end

local Enemies: { [string]: Enemy } = {
	Shadeling = {
		id = "Shadeling",
		typeId = 1,
		displayName = "Shadeling",
		hp = 3,
		speed = speed(200),
		contactDamage = 1,
		hpPerWave = 2,
		damagePerWave = 0.6,
		xp = 1,
		radius = 1.5,
		mass = 1,
		knockbackResistance = 0, -- B5, like Brotato's Baby Alien
		loot = { consumableChance = 0.01, crateShare = 0.01 },
		firstWave = 1,
		minDanger = 0,
		speedMax = speed(300),
	},
	Brute = {
		id = "Brute",
		typeId = 2,
		displayName = "Brute",
		hp = 20,
		speed = speed(300),
		contactDamage = 2,
		hpPerWave = 11,
		damagePerWave = 0.85,
		xp = 3,
		radius = 2.5,
		mass = 6,
		knockbackResistance = 0.9, -- B5, like Bruiser
		loot = { consumableChance = 0.03, crateShare = 0.03 },
		firstWave = 8,
		minDanger = 0,
		-- bruiser/horned_bruiser.tscn: 0-500 px, 0.75 s at +700 px/s, cooldown 60 +- 10 frames
		-- target_rand_pos_movement_behavior: walks to random spots of the zone instead of at the player
		wander = { around = "Arena", arriveStuds = 10 * PIXEL, maxSeconds = 8 },
		charge = brotatoCharge(speed(300), {
			maxRange = 500,
			chargeSpeed = 700,
			duration = 0.75,
			cooldown = 60,
			cooldownRandom = 10,
		}),
	},
	Spitter = {
		id = "Spitter",
		typeId = 3,
		displayName = "Spitter",
		hp = 8,
		speed = speed(200),
		contactDamage = 1,
		hpPerWave = 1,
		damagePerWave = 0.6,
		xp = 1,
		radius = 1.5,
		mass = 1,
		knockbackResistance = 0.95, -- B5, like Spitter
		-- Brotato 1.2.0.1 spitter.tscn: stays 300 px (+-100) away at full speed, shoots at most 700 px away straight at
		-- the player, 600 px/s; a shot comes 0.8 s into a 1 s animation, then 120 (+-10) frames cooldown.
		ranged = {
			keepDistance = 300 * PIXEL,
			keepDistanceJitter = 100 * PIXEL,
			fireInterval = 3,
			fireRange = 700 * PIXEL,
			projectileDamage = 1,
			projectileSpeed = 600 * PIXEL,
			projectileRange = SHOT_RANGE,
			projectileRadius = SHOT_RADIUS,
			aimLead = 0,
		},
		loot = { consumableChance = 0.03, crateShare = 0.1 },
		firstWave = 4,
		minDanger = 0,
		shotDamagePerWave = 0.75,
	},
	-- typeId 4 is the first boss (bosses below)
	Charger = {
		id = "Charger",
		typeId = 5,
		displayName = "Charger",
		hp = 4,
		speed = speed(400),
		contactDamage = 1,
		hpPerWave = 2.5,
		damagePerWave = 0.85,
		xp = 1,
		radius = 1.8,
		mass = 3,
		knockbackResistance = 0.8, -- B5, like Charger
		-- charger.tscn: 0-300 px, 0.75 s at +500 px/s, cooldown 40 +- 5 frames
		charge = brotatoCharge(speed(400), {
			maxRange = 300,
			chargeSpeed = 500,
			duration = 0.75,
			cooldown = 40,
			cooldownRandom = 5,
		}),
		loot = { consumableChance = 0.01, crateShare = 0.01 },
		firstWave = 3,
		minDanger = 0,
	},
	Splitter = {
		id = "Splitter",
		typeId = 6,
		displayName = "Splitter",
		hp = 10,
		speed = speed(120),
		contactDamage = 1,
		hpPerWave = 1,
		damagePerWave = 0.85,
		xp = 1,
		radius = 1.9,
		mass = 2,
		knockbackResistance = 0.7, -- B5, like Helmet Alien
		-- spawner.tscn: holds a spot 450 +- 50 px from the player (on the circle); dies into 3 Junkies at random spots of
		-- a 200 px square
		wander = {
			around = "Offset",
			within = false,
			range = px(450),
			rangeJitter = px(50),
			arriveStuds = 0,
			maxSeconds = 0,
		},
		split = { enemy = "Skulker", count = 3, spread = 0, area = px(200) },
		loot = { consumableChance = 0.01, crateShare = 0.01 },
		firstWave = 14,
		minDanger = 0,
	},
	-- only from Splitters
	Splitling = {
		id = "Splitling",
		typeId = 7,
		displayName = "Splitling",
		hp = 12,
		speed = speed(400),
		contactDamage = 1,
		hpPerWave = 2,
		damagePerWave = 1,
		xp = 1,
		radius = 1,
		mass = 0.6,
		removeFirst = true, -- fin_alien.tscn
		knockbackResistance = 0, -- B5, like Baby Alien
		loot = { consumableChance = 0.02, crateShare = 0.03 },
		firstWave = 15,
		minDanger = 0,
		firstWaveByDanger = { [1] = 9 },
	},
	-- stronger versions of the first enemies for the second half of the run
	AbyssShadeling = {
		id = "AbyssShadeling",
		typeId = 8,
		displayName = "Abyss Shadeling",
		hp = 1,
		speed = speed(380),
		contactDamage = 1,
		hpPerWave = 1,
		damagePerWave = 0.6,
		xp = 1,
		radius = 1.6,
		mass = 1.2,
		knockbackResistance = 0, -- B5, like Chaser
		look = "Shadeling",
		loot = { consumableChance = 0.02, crateShare = 0.03 },
		firstWave = 2,
		minDanger = 0,
	},
	AbyssBrute = {
		id = "AbyssBrute",
		typeId = 9,
		displayName = "Abyss Brute",
		hp = 26,
		speed = speed(300),
		contactDamage = 1,
		hpPerWave = 18,
		damagePerWave = 1.15,
		xp = 3,
		radius = 2.8,
		mass = 8,
		knockbackResistance = 0.9, -- B5, like Bruiser
		look = "Brute",
		loot = { consumableChance = 0.03, crateShare = 0.03 },
		firstWave = 13,
		minDanger = 0,
		firstWaveByDanger = { [1] = 8 },
		-- bruiser/horned_bruiser.tscn: 0-500 px, 0.75 s at +700 px/s, cooldown 60 +- 10 frames
		charge = brotatoCharge(speed(300), {
			maxRange = 500,
			chargeSpeed = 700,
			duration = 0.75,
			cooldown = 60,
			cooldownRandom = 10,
		}),
	},
	-- B6: Brotato's Loot Alien. Appears now and then (Config.Loot.looter), runs away, escapes after a while; killed
	-- it drops a guaranteed crate and eight materials. Original Looter HP and wave growth follow the wiki.
	Looter = {
		id = "Looter",
		typeId = 10,
		displayName = "Looter",
		hp = 5, -- assumption, see above
		speed = speed(300),
		contactDamage = 1,
		hpPerWave = 30,
		damagePerWave = 0.85,
		xp = 8, -- Brotato: 8 materials
		radius = 1.4,
		mass = 1,
		knockbackResistance = 0,
		flee = { edgeMargin = 12 },
		loot = { consumableChance = 1, crateShare = 1, alwaysOrbs = true, crate = true },
		firstWave = 3,
		minDanger = 0,
		speedMax = speed(400),
		specialSpawn = true,
	},
	-- B6: Brotato's Tree. Stands still and does nothing (Config.Loot.trees); killed it drops a fruit (or a crate) and
	-- an orb of 3. Owner decision (2026-11-08): double Brotato's HP (10 + 5/wave) on purpose, trees felt too fragile.
	Tree = {
		id = "Tree",
		typeId = 11,
		displayName = "Tree",
		hp = 20,
		speed = speed(0),
		contactDamage = 0,
		hpPerWave = 10,
		damagePerWave = 0,
		xp = 3, -- Brotato: 3 materials
		radius = 2.2,
		mass = 1000,
		knockbackResistance = 1,
		anchored = true,
		loot = { consumableChance = 1, crateShare = 0.2, alwaysOrbs = true },
		firstWave = 1,
		minDanger = 0,
		specialSpawn = true,
	},
	-- B9 part 2: Brotato's other enemy behaviours, each with its own silhouette or palette (EnemyRenderer/Models).
	-- Base stats and per-wave increments match the main-game wiki; attack geometry remains a Roblox adaptation.
	-- Accelerator (like Brotato's ones that speed up): starts slow, keeps getting faster.
	Stalker = {
		id = "Stalker",
		typeId = 12,
		displayName = "Stalker",
		hp = 10,
		speed = speed(150),
		contactDamage = 1,
		hpPerWave = 24,
		damagePerWave = 1.2,
		xp = 3,
		radius = 1.5,
		mass = 1,
		knockbackResistance = 0,
		look = "Shadeling",
		-- pursuer.tscn: +45 px/s every second, at most 10 times, all lost when it hits
		accelerate = { everySeconds = 1, perStep = 45 / 150, maxSteps = 10, resetOnHit = true },
		loot = { consumableChance = 0.03, crateShare = 0.03 },
		firstWave = 11,
		minDanger = 0,
	},
	-- Distant shooter: keeps far away and shoots from there; since the playtest after Paket 24 it no longer runs off
	-- when a player comes close, it only backs off slowly like the Spitter.
	Skulker = {
		id = "Skulker",
		typeId = 13,
		displayName = "Skulker",
		hp = 5,
		speed = speed(300),
		contactDamage = 1,
		hpPerWave = 4,
		damagePerWave = 1,
		xp = 1,
		radius = 1.5,
		mass = 1,
		knockbackResistance = 0.5,
		look = "Spitter",
		-- Brotato 1.2.0.1 junkie.tscn: shoots from any distance but not closer than 200 px, 500 px/s, each shot up to
		-- 1.2 rad off; 0.5 s animation (speed 2), then 120 (+-10) frames cooldown. It walks to random spots in the
		-- arena (target_rand_pos_movement_behavior), so keepDistance is not used.
		wander = { around = "Arena", arriveStuds = 10 * PIXEL, maxSeconds = 8 },
		ranged = {
			keepDistance = 36,
			fireInterval = 2.5,
			fireRange = SHOT_RANGE,
			minFireRange = 200 * PIXEL,
			spreadRadians = 1.2,
			projectileDamage = 1,
			projectileSpeed = 500 * PIXEL,
			projectileRange = SHOT_RANGE,
			projectileRadius = SHOT_RADIUS,
			aimLead = 0,
		},
		loot = { consumableChance = 0, crateShare = 0 }, -- Brotato junkie: can_drop_consumables false
		firstWave = 14,
		minDanger = 0,
		shotDamagePerWave = 1,
	},
	-- Counter-shooter: slow and tough; every hit makes it spray a ring of thorns.
	Thornback = {
		id = "Thornback",
		typeId = 14,
		displayName = "Thornback",
		hp = 15,
		speed = speed(325),
		contactDamage = 1,
		hpPerWave = 4,
		damagePerWave = 0.85,
		xp = 1,
		radius = 2.3,
		mass = 5,
		knockbackResistance = 0,
		look = "Brute",
		-- Brotato 1.2.0.1 fly.gd/fly.tscn: a hit by a ranged weapon makes it shoot one projectile in a random direction
		-- with 25 % chance, 200 px/s. It walks to random spots up to 150 (+-50) px from the player on each axis.
		wander = {
			around = "Target",
			range = 150 * PIXEL,
			rangeJitter = 50 * PIXEL,
			arriveStuds = 10 * PIXEL,
			maxSeconds = 4,
		},
		retaliate = {
			count = 1,
			cooldownSeconds = 0,
			projectileDamage = 1,
			rangedOnly = true,
			chance = 0.25,
			projectileSpeed = 200 * PIXEL,
			projectileRange = SHOT_RANGE,
			projectileRadius = SHOT_RADIUS,
		},
		loot = { consumableChance = 0.01, crateShare = 0.01 },
		firstWave = 4,
		minDanger = 1,
		speedMax = speed(375),
		shotDamagePerWave = 1,
	},
	-- Buffer: walks with the crowd and makes the enemies around it stronger for good.
	Herald = {
		id = "Herald",
		typeId = 15,
		displayName = "Herald",
		hp = 20,
		speed = speed(150),
		contactDamage = 1,
		hpPerWave = 3,
		damagePerWave = 0.6,
		xp = 2,
		radius = 1.6,
		mass = 1.5,
		knockbackResistance = 0.95,
		look = "Spitter",
		-- buffer.tscn: stays 500 +- 100 px from the player; every 4 s (the first after 0.25 s) one enemy in its 309 px
		-- zone gets +150 % max HP, +25 % damage and +50 % speed
		stayInRange = { distance = px(500), jitter = px(100) },
		pulse = {
			radius = px(309.04),
			intervalSeconds = 4,
			firstSeconds = 0.25,
			buffCount = 1,
			buffDamage = 1.25,
			buffSpeed = 1.5,
			buffHp = 1.5,
		},
		loot = { consumableChance = 0.01, crateShare = 0.01 },
		firstWave = 16,
		minDanger = 0,
	},
	-- Healer: heals the enemies around it every few seconds; kill it first.
	Mender = {
		id = "Mender",
		typeId = 16,
		displayName = "Mender",
		hp = 10,
		speed = speed(400),
		contactDamage = 1,
		hpPerWave = 8,
		damagePerWave = 0.85,
		xp = 2,
		radius = 1.6,
		mass = 1.5,
		knockbackResistance = 0,
		look = "Spitter",
		-- target_rand_pos_movement_behavior: walks to random spots of the zone instead of at the player
		wander = { around = "Arena", arriveStuds = 10 * PIXEL, maxSeconds = 8 },
		-- healer.tscn: heals 100 + 10 per wave once to each hurt enemy that comes into its 200.6 px zone
		pulse = { radius = px(200.639), intervalSeconds = 0, onEnter = true, healFlat = 100, healPerWave = 10 },
		loot = { consumableChance = 0.03, crateShare = 0.03 },
		firstWave = 7,
		minDanger = 1,
	},
	-- Egg: lies still and hatches into Shadelings unless it is broken in time.
	BroodEgg = {
		id = "BroodEgg",
		typeId = 17,
		displayName = "Brood Egg",
		hp = 5,
		speed = speed(0),
		contactDamage = 1,
		hpPerWave = 3,
		damagePerWave = 0.25,
		xp = 1,
		radius = 1.4,
		mass = 1000,
		knockbackResistance = 1,
		anchored = true,
		-- slasher_egg.tscn: after 240 frames its shoot animation plays at half speed and hatches it at 0.8 s of it
		-- (4 + 1.6 s); the Slasher appears where the egg was
		hatch = { seconds = 4 + 0.8 / 0.5, enemy = "Reaper", count = 1, spread = 0 },
		loot = { consumableChance = 0, crateShare = 0 },
		firstWave = 7,
		minDanger = 1,
	},
	-- Slasher: stops next to a player, winds up and cuts everything around it.
	Reaper = {
		id = "Reaper",
		typeId = 18,
		displayName = "Reaper",
		hp = 50,
		speed = speed(250),
		contactDamage = 1,
		hpPerWave = 25,
		damagePerWave = 1.15,
		xp = 5, -- Brotato slasher_stats value 5
		radius = 1.8,
		mass = 3,
		knockbackResistance = 0.9,
		look = "Charger",
		slash = {
			triggerRange = 7,
			windupSeconds = 0.7,
			radius = 7.5,
			damage = 1,
			recoverSeconds = 0.6,
			cooldownSeconds = 1.6,
		},
		loot = { consumableChance = 0.03, crateShare = 0.03 },
		firstWave = 4,
		minDanger = 1,
		speedMax = speed(300),
		shotDamagePerWave = 1,
	},
	-- Loot eater: goes for the orbs on the floor and swallows them; killed it drops all it ate.
	Gobbler = {
		id = "Gobbler",
		typeId = 19,
		displayName = "Gobbler",
		hp = 5,
		speed = speed(300),
		contactDamage = 1,
		hpPerWave = 30,
		damagePerWave = 0.85,
		xp = 8,
		radius = 1.6,
		mass = 1.5,
		knockbackResistance = 0.5, -- evil_mob.tres
		look = "Looter",
		eat = { seekRange = 45, reach = 0.8 },
		loot = { consumableChance = 0, crateShare = 0, alwaysOrbs = true }, -- Brotato evil_mob: no consumables
		firstWave = 1,
		minDanger = 0,
		speedMax = speed(400),
		specialSpawn = true,
	},
	IronHusk = {
		id = "IronHusk",
		typeId = 29,
		displayName = "Iron Husk",
		hp = 8,
		hpPerWave = 4,
		speed = speed(225),
		contactDamage = 1,
		damagePerWave = 1,
		xp = 1,
		radius = 1.7,
		mass = 2,
		look = "Shadeling",
		removeFirst = true, -- helmet_alien.tscn
		knockbackResistance = 0.5,
		loot = { consumableChance = 0.01, crateShare = 0.01 },
		firstWave = 13,
		minDanger = 0,
		speedMax = speed(275),
		firstWaveByDanger = { [1] = 10, [4] = 4 },
	},
	HornedRusher = {
		id = "HornedRusher",
		typeId = 30,
		displayName = "Horned Rusher",
		hp = 12,
		hpPerWave = 5,
		speed = speed(425),
		contactDamage = 1,
		damagePerWave = 1.1,
		xp = 1,
		radius = 1.4,
		mass = 1,
		look = "Shadeling",
		knockbackResistance = 0.8,
		loot = { consumableChance = 0.01, crateShare = 0.01 },
		firstWave = 18,
		minDanger = 0,
		firstWaveByDanger = { [4] = 5 },
		-- horned_charger.tscn: 0-300 px, 0.75 s at +500 px/s, cooldown 40 +- 5 frames
		charge = brotatoCharge(speed(425), {
			maxRange = 300,
			chargeSpeed = 500,
			duration = 0.75,
			cooldown = 40,
			cooldownRandom = 5,
		}),
	},
	DreadTendril = {
		id = "DreadTendril",
		typeId = 31,
		displayName = "Dread Tendril",
		hp = 100,
		hpPerWave = 20,
		speed = speed(175),
		contactDamage = 1,
		damagePerWave = 1,
		xp = 4, -- Brotato tentacle_stats value 4
		radius = 2,
		mass = 3,
		look = "Charger",
		slash = {
			triggerRange = 9,
			windupSeconds = 0.7,
			radius = 9,
			damage = 1,
			recoverSeconds = 0.6,
			cooldownSeconds = 1.6,
		},
		knockbackResistance = 0.7,
		loot = { consumableChance = 0.02, crateShare = 0.02 },
		firstWave = 13,
		minDanger = 3,
		shotDamagePerWave = 1,
	},
	Hookfang = {
		id = "Hookfang",
		typeId = 32,
		displayName = "Hookfang",
		hp = 30,
		hpPerWave = 15,
		speed = speed(350),
		contactDamage = 1,
		damagePerWave = 0.75,
		xp = 1,
		radius = 1.6,
		mass = 3,
		look = "Charger",
		-- Brotato 1.2.0.1 lamprey.tscn: charges within 400 px at 500 px/s for 0.75 s, 90 (+-15) frames cooldown; while
		-- charging it shoots 2 projectiles 1 rad to either side of its way every 30 frames, 600 px/s.
		charge = {
			triggerRange = 400 * PIXEL,
			windupSeconds = 0.2,
			speed = 500 * PIXEL,
			maxDistance = 500 * PIXEL * 0.75,
			recoverSeconds = 0.2,
			cooldownSeconds = 1.5,
			projectileDamage = 1,
			projectileSpeed = 600 * PIXEL,
			projectileRange = SHOT_RANGE,
			projectileRadius = SHOT_RADIUS,
			trailEvery = 500 * PIXEL * 0.5,
			trailAngle = 1,
		},
		knockbackResistance = 0.95,
		loot = { consumableChance = 0.01, crateShare = 0.01 },
		firstWave = 1,
		minDanger = 0,
		specialSpawn = true,
		shotDamagePerWave = 0.75,
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

local BossProjectiles: BossProjectiles = table.freeze({
	bullet = table.freeze({ radius = SHOT_RADIUS, range = SHOT_RANGE }), -- like every enemy bullet
	-- pillar_projectile: a 23 px circle whose hitbox is on 0.54-0.68 s after it appears
	pillar = table.freeze({ radius = px(23), hitFrom = 0.54, hitUntil = 0.68 }),
	-- slash_projectile: the hitbox sweeps along the slash from -152 to 154 px (12-17 px half wide) 0.48-0.6 s after it
	-- appears; drawn and checked here as the whole strip during that time. slash_projectile_2 sits 165 px further on.
	slash = table.freeze({
		from = px(-152),
		to = px(154),
		halfWidth = px(15),
		hitFrom = 0.48,
		hitUntil = 0.6,
		aheadOffset = px(165),
	}),
})

local function attack(fields: { [string]: any }): BossAttack
	return table.freeze(fields) :: any
end

-- WP10: the bosses of the boss wave (the last wave, Run.spawn.waves), after Brotato's two (wave 20, 90 s). One of
-- them comes, picked at random (B11: both on the highest danger level). The wave ends with a victory when every
-- boss is dead or when its time runs out (Brotato). HP and contact damage are Brotato's at wave 20 (15000 + 750 and
-- 1 + 1.5 per wave); they then get the difficulty and the team's enemy stats, HP also the player factor
-- (EnemyWaves.coop, SpawnRules.coopHealth). Bosses count as elites for Damage vs Elites and ignore knockback; Heralds
-- and Menders skip them. States and attacks: Brotato 1.2.0.1 bosses/predator and bosses/invoker (.tscn).
local Bosses: { [string]: Enemy } = {
	-- Predator: chases you and charges (0.5 s at +750 px/s) about every 3.3 s, an arm of 9 projectiles turning around it; from half HP (or 45 s)
	-- it walks to random spots near you and shoots 16 bullets in random directions, the arm turning faster
	LanternEater = {
		id = "LanternEater",
		typeId = 4,
		displayName = "The Lantern Eater",
		hp = 15000, -- predator_stats.tres: 15000 + 750 per wave (29,250 in wave 20)
		speed = speed(300),
		contactDamage = 1, -- + 1.5 per wave (29.5 in wave 20)
		hpPerWave = 750,
		damagePerWave = 1.5,
		xp = 0, -- the run ends with it
		radius = 4.5,
		mass = 60,
		knockbackResistance = 1,
		boss = {
			orbit = {
				distances = { px(250), px(300), px(350), px(600), px(650), px(700), px(950), px(1000), px(1050) },
				growSpeed = px(100),
				turnSpeed = 1.2,
				hitRadius = SHOT_RADIUS,
				damage = 1,
				damagePerWave = 1.15,
			},
			states = {
				{
					movement = "Follow",
					attack = attack({
						kind = "Charge",
						windupSeconds = windup(0.5),
						cooldownSeconds = frames(120),
						maxRange = px(500),
						chargeSeconds = 0.5,
						chargeSpeed = px(750),
						recoverSeconds = 0.05,
					}),
				},
				{
					hpStart = 0.5,
					timerStart = 45,
					movement = "AroundPlayer",
					range = px(300),
					orbitTurnMultiplier = 1.25,
					attack = attack({
						kind = "Shoot",
						windupSeconds = windup(0.5),
						cooldownSeconds = frames(90),
						cooldownRandomSeconds = frames(10),
						maxRange = px(2000),
						projectile = "Bullet",
						count = 16,
						randomDirection = true,
						projectileSpeed = px(500),
						damage = 1,
						damagePerWave = 1.15,
					}),
				},
			},
		},
	},
	-- Invoker: follows you; 10 pillars around you (one on you); from 75 % HP (or 30 s) 30 in a wider square; from 40 %
	-- (or 60 s) it runs to random spots 150 % faster and rings you with 24 pillars
	HollowSeer = {
		id = "HollowSeer",
		typeId = 20,
		displayName = "The Hollow Seer",
		hp = 15000, -- invoker_stats.tres: 15000 + 750 per wave (29,250 in wave 20)
		speed = speed(200),
		contactDamage = 1, -- + 1.5 per wave (29.5 in wave 20)
		hpPerWave = 750,
		damagePerWave = 1.5,
		xp = 0,
		radius = 4,
		mass = 60,
		knockbackResistance = 1,
		boss = {
			states = {
				{
					movement = "Follow",
					attack = attack({
						kind = "Shoot",
						windupSeconds = windup(1),
						cooldownSeconds = frames(50),
						cooldownRandomSeconds = frames(10),
						initialSeconds = frames(120),
						maxRange = px(2000),
						projectile = "Pillar",
						count = 10,
						onTarget = true,
						spawnSpread = px(500),
						oneOnTarget = true,
						damage = 1,
						damagePerWave = 1.15,
					}),
				},
				{
					hpStart = 0.75,
					timerStart = 30,
					movement = "Follow",
					attack = attack({
						kind = "Shoot",
						windupSeconds = windup(1),
						cooldownSeconds = frames(60),
						cooldownRandomSeconds = frames(10),
						maxRange = px(2000),
						projectile = "Pillar",
						count = 30,
						onTarget = true,
						spawnSpread = px(800),
						oneOnTarget = true,
						damage = 1,
						damagePerWave = 1.15,
					}),
				},
				{
					hpStart = 0.4,
					timerStart = 60,
					movement = "Roam",
					speedPercent = 150,
					attack = attack({
						kind = "Shoot",
						windupSeconds = windup(1),
						cooldownSeconds = frames(60),
						cooldownRandomSeconds = frames(10),
						maxRange = px(2000),
						projectile = "Pillar",
						count = 24,
						onTarget = true,
						spawnSpread = px(600),
						onBorders = true,
						constantSpread = true,
						damage = 1,
						damagePerWave = 1.15,
					}),
				},
			},
		},
	},
}

-- How the boss wave brings its bosses (BossService).
local BossWave = table.freeze({
	-- bosses per boss wave: Config.Difficulty (B11: 2 on danger 5, every boss in endless boss waves), each with
	-- this share of its HP when more than one comes (Brotato)
	hpShareWhenSeveral = 0.75,
	order = table.freeze({ "LanternEater", "HollowSeer" }), -- picked at random; "SpawnBoss" goes through them in turn
	introSeconds = 2.5, -- after the boss wave starts: red crosses show where it comes
	spawnDistance = 28, -- studs from a random living player
	stateInterval = 0.2, -- seconds between BossState updates (HP bar)
	legendaryCrate = true, -- a killed boss drops a legendary crate (matters once a run goes on after it, B11)
})

-- Brotato 1.2.0.1's own circles in pixels (entities/units/enemies/**/<scene>.tscn on top of enemy.tscn): `hurt` is the
-- Hurtbox the player's weapons hit, `hit` the Hitbox that touches the player (0: it never touches). Mapping of the
-- scenes as in tools/build-enemy-waves.py. Kinds without an entry use their radius for both.
local BROTATO_CIRCLES: { [string]: { hurt: number, hit: number } } = {
	AbyssBrute = { hurt = 40.01, hit = 27.0 },
	-- Bosses (crash_zone/bosses/<scene>.tscn) and champions (crash_zone/elites/<scene>.tscn)
	LanternEater = { hurt = 40.0, hit = 40.0 }, -- predator
	HollowSeer = { hurt = 40.0, hit = 40.0 }, -- invoker
	BrassRam = { hurt = 40.0, hit = 40.0 }, -- rhino
	Flayer = { hurt = 40.0, hit = 40.0 }, -- butcher
	Abbot = { hurt = 40.0, hit = 40.0 }, -- monk
	MireJaw = { hurt = 40.0, hit = 40.0 }, -- croc
	Monolith = { hurt = 48.0, hit = 48.0 }, -- colossus
	SickleWraith = { hurt = 40.0, hit = 40.0 }, -- mantis
	BroodMatron = { hurt = 64.0, hit = 56.0 }, -- mom
	StoneSeraph = { hurt = 40.0, hit = 40.0 }, -- gargoyle
	AbyssShadeling = { hurt = 32.0, hit = 16.0 },
	BroodEgg = { hurt = 32.0, hit = 18.0 },
	Brute = { hurt = 40.01, hit = 27.02 },
	Charger = { hurt = 48.01, hit = 25.0 },
	DreadTendril = { hurt = 24.0, hit = 21.02 },
	Gobbler = { hurt = 32.0, hit = 21.02 },
	Herald = { hurt = 32.0, hit = 22.0 },
	Hookfang = { hurt = 48.01, hit = 29.02 },
	HornedRusher = { hurt = 48.01, hit = 25.0 },
	IronHusk = { hurt = 32.0, hit = 21.0 },
	Looter = { hurt = 32.0, hit = 21.02 },
	Mender = { hurt = 32.0, hit = 20.02 },
	Reaper = { hurt = 40.01, hit = 31.0 },
	Shadeling = { hurt = 32.0, hit = 16.03 },
	Skulker = { hurt = 32.0, hit = 20.0 },
	Spitter = { hurt = 32.0, hit = 22.0 },
	Splitling = { hurt = 32.0, hit = 16.0 },
	Splitter = { hurt = 48.51, hit = 34.0 },
	Stalker = { hurt = 64.38, hit = 26.0 },
	Thornback = { hurt = 70.06, hit = 14.0 },
	Tree = { hurt = 48.66, hit = 0 },
}

-- Bodies were drawn for 5.4-stud figures; Brotato's bodies are Simulation.bodyScale larger (09.11.2026). `radius` stays
-- the body (walls, crowding, picture size); hurtRadius and hitRadius come from Brotato where known (09.11.2026).
local function scaleBodies(list: { [string]: Enemy })
	for id, enemy in list do
		enemy.radius *= Simulation.bodyScale
		local circles = BROTATO_CIRCLES[id]
		enemy.hurtRadius = if circles then circles.hurt * PIXEL else enemy.radius
		enemy.hitRadius = if circles then circles.hit * PIXEL else enemy.radius
	end
end
scaleBodies(Enemies)
-- These source-backed bodies/circles are already expressed in the enemy engine's world units.
for id, kind in require(script.Parent.NightmareEnemyKinds).build(PIXEL) do
	Enemies[id] = kind
end
for id, kind in require(script.Parent.JungleEnemyKinds).build(PIXEL) do
	Enemies[id] = kind
end
scaleBodies(Bosses)

for _, boss in Bosses do
	table.freeze(boss)
end

-- WP10 part 2: the champions of the elite waves, after Brotato's eight elites (Rhino, Butcher, Monk, Croc, Colossus,
-- Mantis, Mom, Gargoyle), with our own names and looks. Like the bosses they switch states (BossService), show an HP
-- bar at the top, count as elites, ignore knockback and drop a legendary crate. Brotato: 1 HP + 750 per wave after
-- wave 1 (Monk 700), 1 contact damage + 1.5 per wave after wave 1, grown by Run.spawn.growth like every enemy, HP
-- also with the player factor (EnemyWaves.coop, SpawnRules.coopHealth). States and attacks: Brotato 1.2.0.1
-- crash_zone/elites/<name>/<name>.tscn and .gd; their projectiles grow by their own damagePerWave.
local CHAMPION_HP_PER_WAVE = 750
local CHAMPION_DAMAGE_PER_WAVE = 1.5

local function champion(id: string, typeId: number, displayName: string, speed: number, plan: BossPlan): Enemy
	return {
		id = id,
		typeId = typeId,
		displayName = displayName,
		hp = 1,
		speed = speed,
		contactDamage = 1,
		hpPerWave = CHAMPION_HP_PER_WAVE,
		damagePerWave = CHAMPION_DAMAGE_PER_WAVE,
		xp = 10,
		radius = 3.2,
		mass = 30,
		knockbackResistance = 1,
		boss = plan,
	}
end

local Champions: { [string]: Enemy } = {
	-- Rhino: charges you (1 s at +900 px/s) about every 3 s, firing a bullet to each side every 0.25 s; from 60 % HP
	-- (or 25 s) shorter charges (0.4 s at +1000, only from 300 px) about every 1.8 s with 4 bullets every 0.25 s
	BrassRam = champion("BrassRam", 21, "The Brass Ram", speed(250), {
		states = {
			{
				movement = "Follow",
				attack = attack({
					kind = "Charge",
					windupSeconds = windup(1),
					cooldownSeconds = frames(100),
					maxRange = px(800),
					chargeSeconds = 1,
					chargeSpeed = px(900),
					recoverSeconds = 0.05,
				}),
				chargeShotEvery = frames(15),
				chargeShots = attack({
					kind = "Shoot",
					windupSeconds = 0,
					cooldownSeconds = 0,
					projectile = "Bullet",
					count = 2,
					spread = 1,
					constantSpread = true,
					aim = "Movement",
					projectileSpeed = px(600),
					damage = 1,
					damagePerWave = 1.15,
				}),
			},
			{
				hpStart = 0.6,
				timerStart = 25,
				movement = "Follow",
				attack = attack({
					kind = "Charge",
					windupSeconds = windup(1),
					cooldownSeconds = frames(60),
					maxRange = px(300),
					chargeSeconds = 0.4,
					chargeSpeed = px(1000),
					recoverSeconds = 0.05,
				}),
				chargeShotEvery = frames(15),
				chargeShots = attack({
					kind = "Shoot",
					windupSeconds = 0,
					cooldownSeconds = 0,
					projectile = "Bullet",
					count = 4,
					spread = 2,
					constantSpread = true,
					aim = "Movement",
					projectileSpeed = px(600),
					damage = 1,
					damagePerWave = 1.15,
				}),
			},
		},
	}),
	-- Butcher: 4 slashes through you from 4 sides; from 70 % HP (or 20 s) 9 slashes in random directions around you
	-- (one on you); from 40 % (or 40 s) it walks to spots near you and slashes 3 times in quick succession
	Flayer = champion("Flayer", 22, "The Flayer", speed(200), {
		states = {
			{
				movement = "Follow",
				attack = attack({
					kind = "Shoot",
					windupSeconds = windup(1),
					cooldownSeconds = frames(60),
					initialSeconds = frames(45),
					maxRange = px(1000),
					projectile = "Slash",
					count = 4,
					onTarget = true,
					spawnSpread = px(350),
					onBorders = true,
					constantSpread = true,
					damage = 1,
					damagePerWave = 1.15,
				}),
			},
			{
				hpStart = 0.7,
				timerStart = 20,
				movement = "Follow",
				attack = attack({
					kind = "Shoot",
					windupSeconds = windup(1),
					cooldownSeconds = frames(60),
					maxRange = px(1200),
					projectile = "Slash",
					count = 9,
					randomDirection = true,
					onTarget = true,
					spawnSpread = px(1000),
					oneOnTarget = true,
					damage = 1,
					damagePerWave = 1.15,
				}),
			},
			{
				hpStart = 0.4,
				timerStart = 40,
				movement = "AroundPlayer",
				range = px(300),
				attack = attack({
					kind = "Shoot",
					windupSeconds = windup(3),
					cooldownSeconds = frames(35),
					cooldownRandomSeconds = frames(10),
					maxRange = px(2000),
					projectile = "Slash",
					count = 3,
					randomDirection = true,
					onTarget = true,
					spawnSpread = px(500),
					damage = 1,
					damagePerWave = 0.75,
				}),
			},
		},
	}),
	-- Monk: walks to random spots laying 3 eggs every 1.8 s; from 75 % HP (or 10 s) half as fast, 6 bullets at you;
	-- from 50 % (or 30 s) 25 % faster, 2 tentacles every 2.4 s; from 30 % (or 40 s) half as fast, rings you with 10
	-- pillars
	Abbot = (function()
		local abbot = champion("Abbot", 23, "The Abbot", speed(350), {
			states = {
				{
					movement = "Roam",
					attack = attack({
						kind = "Spawn",
						windupSeconds = windup(0.5),
						cooldownSeconds = frames(60),
						cooldownRandomSeconds = frames(5),
						enemy = "BroodEgg", -- Slasher Egg
						spawnCount = 3,
						spawnArea = px(300),
					}),
				},
				{
					hpStart = 0.75,
					timerStart = 10,
					movement = "Roam",
					speedPercent = -50,
					attack = attack({
						kind = "Shoot",
						windupSeconds = windup(1),
						cooldownSeconds = frames(75),
						cooldownRandomSeconds = frames(10),
						maxRange = px(2000),
						projectile = "Bullet",
						count = 6,
						spread = 1,
						projectileSpeed = px(400),
						damage = 1,
						damagePerWave = 1.15,
					}),
				},
				{
					hpStart = 0.5,
					timerStart = 30,
					movement = "Roam",
					speedPercent = 25,
					attack = attack({
						kind = "Spawn",
						windupSeconds = windup(1),
						cooldownSeconds = frames(120),
						enemy = "DreadTendril", -- Tentacle
						spawnCount = 2,
						spawnArea = px(500),
					}),
				},
				{
					hpStart = 0.3,
					timerStart = 40,
					movement = "Roam",
					speedPercent = -50,
					attack = attack({
						kind = "Shoot",
						windupSeconds = windup(1),
						cooldownSeconds = frames(60),
						cooldownRandomSeconds = frames(10),
						maxRange = px(2000),
						projectile = "Pillar",
						count = 10,
						spread = 1,
						onTarget = true,
						spawnSpread = px(500),
						onBorders = true,
						constantSpread = true,
						damage = 1,
						damagePerWave = 1.15,
					}),
				},
			},
		})
		abbot.hpPerWave = 700
		return abbot
	end)(),
	-- Croc: charges you about every second (0.6 s at +600 px/s), 2 slashes ahead at you every 0.75 s of charging;
	-- from 60 % HP (or 25 s) it keeps 200 px away and charges about every 1.65 s (0.5 s at +1000), ringing you with
	-- 10 pillars
	MireJaw = champion("MireJaw", 24, "The Mire Jaw", speed(350), {
		states = {
			{
				movement = "Follow",
				attack = attack({
					kind = "Charge",
					windupSeconds = windup(2),
					cooldownSeconds = frames(15),
					cooldownRandomSeconds = frames(3),
					maxRange = px(500),
					chargeSeconds = 0.6,
					chargeSpeed = px(600),
					recoverSeconds = 0.05,
				}),
				chargeShotEvery = frames(45),
				chargeShots = attack({
					kind = "Shoot",
					windupSeconds = 0,
					cooldownSeconds = 0,
					projectile = "SlashAhead",
					count = 2,
					spread = 0.6,
					constantSpread = true,
					projectileSpeed = px(700),
					damage = 1,
					damagePerWave = 1.15,
				}),
			},
			{
				hpStart = 0.6,
				timerStart = 25,
				movement = "KeepDistance",
				range = px(200),
				attack = attack({
					kind = "Charge",
					windupSeconds = windup(1),
					cooldownSeconds = frames(45),
					cooldownRandomSeconds = frames(15),
					maxRange = px(800),
					chargeSeconds = 0.5,
					chargeSpeed = px(1000),
					recoverSeconds = 0.05,
				}),
				chargeShotEvery = frames(45),
				chargeShots = attack({
					kind = "Shoot",
					windupSeconds = 0,
					cooldownSeconds = 0,
					projectile = "Pillar",
					count = 10,
					randomDirection = true,
					onTarget = true,
					spawnSpread = px(500),
					onBorders = true,
					constantSpread = true,
					damage = 1,
					damagePerWave = 1.15,
				}),
			},
		},
	}),
	-- Colossus: chases you, every second 50 drifting pillars in a big square around it; from 60 % HP (or 25 s) it
	-- walks to random spots and closes a ring of 18 pillars on you every 0.5 s
	Monolith = (function()
		local monolith = champion("Monolith", 25, "The Monolith", speed(300), {
			states = {
				{
					movement = "Follow",
					attack = attack({
						kind = "Shoot",
						windupSeconds = windup(1),
						cooldownSeconds = frames(60),
						cooldownRandomSeconds = frames(10),
						initialSeconds = frames(120),
						maxRange = px(3000),
						projectile = "Pillar",
						count = 50,
						randomDirection = true,
						spawnSpread = px(1000),
						oneOnTarget = true,
						aim = "Movement",
						projectileSpeed = px(150),
						damage = 1,
						damagePerWave = 1,
					}),
				},
				{
					hpStart = 0.6,
					timerStart = 25,
					movement = "Roam",
					attack = attack({
						kind = "Shoot",
						windupSeconds = windup(1),
						cooldownSeconds = frames(30),
						initialSeconds = frames(30),
						maxRange = px(3000),
						projectile = "Pillar",
						count = 18,
						onTarget = true,
						spawnSpread = px(400),
						onBorders = true,
						constantSpread = true,
						projectileSpeed = px(300),
						damage = 1,
						damagePerWave = 1,
					}),
				},
			},
		})
		monolith.radius = 3.8
		monolith.mass = 50
		return monolith
	end)(),
	-- Mantis: chases you, 6 slashes flying out from a ring around it in random directions; from 60 % HP (or 25 s)
	-- charges you about every 2.4 s (0.7 s at +800 px/s), 3 slashes at you every 0.25 s of charging
	SickleWraith = champion("SickleWraith", 26, "The Sickle Wraith", speed(250), {
		states = {
			{
				movement = "Follow",
				attack = attack({
					kind = "Shoot",
					windupSeconds = windup(1),
					cooldownSeconds = frames(75),
					cooldownRandomSeconds = frames(10),
					initialSeconds = frames(45),
					maxRange = px(1000),
					projectile = "Slash",
					count = 6,
					spread = 1.1,
					randomDirection = true,
					spawnSpread = px(500),
					onBorders = true,
					constantSpread = true,
					projectileSpeed = px(600),
					damage = 1,
					damagePerWave = 1.15,
				}),
			},
			{
				hpStart = 0.6,
				timerStart = 25,
				movement = "Follow",
				attack = attack({
					kind = "Charge",
					windupSeconds = windup(1),
					cooldownSeconds = frames(80),
					maxRange = px(2000),
					chargeSeconds = 0.7,
					chargeSpeed = px(800),
					recoverSeconds = 0.05,
				}),
				chargeShotEvery = frames(15),
				chargeShots = attack({
					kind = "Shoot",
					windupSeconds = 0,
					cooldownSeconds = 0,
					projectile = "Slash",
					count = 3,
					spread = 1.5,
					constantSpread = true,
					spawnSpread = px(300),
					onBorders = true,
					projectileSpeed = px(600),
					damage = 1,
					damagePerWave = 1.15,
				}),
			},
		},
	}),
	-- Mom: chases you, 4 slashes flying at you; from 60 % HP (or 25 s) it keeps 500 px away and every 0.73 s calls 5
	-- small enemies around it and drops a slash next to you
	BroodMatron = champion("BroodMatron", 27, "The Brood Matron", speed(250), {
		states = {
			{
				movement = "Follow",
				attack = attack({
					kind = "Shoot",
					windupSeconds = windup(1),
					cooldownSeconds = frames(60),
					cooldownRandomSeconds = frames(10),
					initialSeconds = frames(120),
					maxRange = px(1000),
					projectile = "SlashAhead",
					count = 4,
					spread = 0.9,
					projectileSpeed = px(650),
					damage = 1,
					damagePerWave = 1.15,
				}),
			},
			{
				hpStart = 0.6,
				timerStart = 25,
				movement = "KeepDistance",
				range = px(500),
				attack = attack({
					kind = "Spawn",
					windupSeconds = windup(1),
					cooldownSeconds = frames(20),
					enemy = "Splitling", -- Fin Alien
					spawnCount = 5,
					spawnArea = px(800),
				}),
				extraShot = attack({
					kind = "Shoot",
					windupSeconds = 0,
					cooldownSeconds = 0,
					projectile = "SlashAhead",
					count = 1,
					randomDirection = true,
					onTarget = true,
					spawnSpread = px(75),
					damage = 1,
					damagePerWave = 1,
				}),
			},
		},
	}),
	-- Gargoyle: walks to random spots, every 0.75 s a ring of 20 pillars rushing outwards; from 60 % HP (or 30 s)
	-- 25 % slower, follows you, 25 pillars in a square around it; from 30 % (or 45 s) 40 % slower, walks to spots near
	-- you and sprays 5 bullets in random directions every 0.4-0.6 s
	StoneSeraph = champion("StoneSeraph", 28, "The Stone Seraph", speed(350), {
		states = {
			{
				movement = "Roam",
				attack = attack({
					kind = "Shoot",
					windupSeconds = windup(1),
					cooldownSeconds = frames(25),
					cooldownRandomSeconds = frames(10),
					initialSeconds = frames(120),
					maxRange = px(2000),
					projectile = "Pillar",
					count = 20,
					spawnSpread = px(300),
					onBorders = true,
					constantSpread = true,
					aim = "Away",
					projectileSpeed = px(375),
					damage = 1,
					damagePerWave = 1.15,
				}),
			},
			{
				hpStart = 0.6,
				timerStart = 30,
				movement = "Follow",
				speedPercent = -25,
				attack = attack({
					kind = "Shoot",
					windupSeconds = windup(1),
					cooldownSeconds = frames(25),
					cooldownRandomSeconds = frames(10),
					maxRange = px(2000),
					projectile = "Pillar",
					count = 25,
					spawnSpread = px(700),
					constantSpread = true,
					damage = 1,
					damagePerWave = 1.15,
				}),
			},
			{
				hpStart = 0.3,
				timerStart = 45,
				movement = "AroundPlayer",
				range = px(300),
				rangeRandom = px(100),
				speedPercent = -40,
				attack = attack({
					kind = "Shoot",
					windupSeconds = windup(1),
					cooldownSeconds = frames(1),
					cooldownRandomSeconds = frames(10),
					maxRange = px(2000),
					projectile = "Bullet",
					count = 5,
					spread = 0.8,
					randomDirection = true,
					projectileSpeed = px(350),
					damage = 1,
					damagePerWave = 1.15,
				}),
			},
		},
	}),
}

-- Brotato's elite waves (DESIGN.md section 7): one champion joins the wave's normal enemies, after red crosses like
-- the boss. Brotato: danger 2-3 one challenging wave (11 or 12), danger 4-5 three (11/12, 14/15, 17/18), 60 % of
-- them elite, the rest horde waves. Since B11 Config.Difficulty decides how many slots a run has and which become
-- horde waves (Util/DangerRules.planBlock); endless mode repeats the slots every 10 waves.
local EliteWaves = table.freeze({
	slots = table.freeze({ table.freeze({ 11, 12 }), table.freeze({ 14, 15 }), table.freeze({ 17, 18 }) }),
	count = 1, -- champions per elite wave (Brotato; endless mode adds Difficulty.endless.championsPerBlock per block)
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
	-- Brotato boss.gd: a boss or elite spawned up to wave 8 has half its HP, up to wave 12 75 % HP and 25 % less
	-- damage (contact and projectiles); first matching entry
	early = table.freeze({
		table.freeze({ untilWave = 8, hpShare = 0.5, damageShare = 1 }),
		table.freeze({ untilWave = 12, hpShare = 0.75, damageShare = 0.75 }),
	}),
	introSeconds = 2.5, -- after the wave starts: red crosses show where it comes
	debugMinWave = 11, -- "SpawnChampion" in an earlier wave grows it like this wave (else it has 3 HP in wave 1)
	legendaryCrate = true, -- a killed champion drops a legendary crate (Brotato)
})

scaleBodies(Champions)
for _, champion in Champions do
	table.freeze(champion)
end

export type NativeCharge = {
	cooldown: number,
	deflectStopBeforeCooldown: number?, -- charging_attack_deflect_bullet_behavior: stop when remaining cooldown <= this duration
	jitter: number,
	minimumCooldown: number,
	fireAt: number,
	duration: number,
	recovery: number,
	speed: number,
	rangeZ: number,
	rangeX: number?,
	minRange: number?,
	maxRange: number?,
	target: {
		atShoot: boolean,
		radius: number,
		coneHalfAngle: number,
		minimumRadiusShare: number,
		inMovementDirection: boolean,
	}?, -- absent retains the original straight-to-player START_SHOOT branch
	massMultiplier: number,
}

return table.freeze({
	types = table.freeze(Enemies),
	elite = Elite,
	bosses = table.freeze(Bosses),
	bossWave = BossWave,
	champions = table.freeze(Champions), -- WP10 part 2
	eliteWaves = EliteWaves,
	bossProjectiles = BossProjectiles,
	boss = Bosses.LanternEater, -- the HUD's label for the old boss phase (unused since WP10)
})
