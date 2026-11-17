--!strict
-- Concrete normal Silesaurus source rules; independent child attacks, square summons and original second-child speed reset.
local POINT = require(script.Parent.Stats).range.studsPerPoint
local C = require(script.Parent.NativeBossPhases)
local J = require(script.Parent.JungleWalkers)
local data = {
	version = "1.2.0.3",
	steamBuild = 26642464,
	source = "res://entities/units/enemies/jungle/elites/silesaurus/silesaurus.tscn",
	sourceMd5 = "7c0b1ed5c7b0596267d328dde443ac4b",
	ruleSources = {
		{
			source = "res://entities/units/enemies/jungle/elites/silesaurus/silesaurus.gdc",
			sourceMd5 = "3dc7ae8b914cefbc9cc1c0174cbda70c",
		},
		{
			source = "res://entities/units/enemies/attack_behaviors/spawning_attack_behavior.gdc",
			sourceMd5 = "cbddd1b76bf3363315729d319a34798d",
		},
		{
			source = "res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gdc",
			sourceMd5 = "43d5ebd849396509ff38632915c988a2",
		},
		{
			source = "res://entities/units/movement_behaviors/target_rand_pos_around_player_movement_behavior.gdc",
			sourceMd5 = "faa12faf0ccf2d3d86cc56d8dee2f21f",
		},
		{
			source = "res://entities/units/movement_behaviors/movement_behavior.gdc",
			sourceMd5 = "545124c6bbc946d5a542876cd568078b",
		},
	},
	sceneChain = {
		{
			source = "res://entities/units/enemies/jungle/elites/silesaurus/silesaurus.tscn",
			sourceMd5 = "7c0b1ed5c7b0596267d328dde443ac4b",
		},
		{
			source = "res://entities/units/enemies/bosses/boss.tscn",
			sourceMd5 = "6018962cd6605773a1e63165e73a4dbc",
		},
		{
			source = "res://entities/units/enemies/enemy.tscn",
			sourceMd5 = "38e442588073219bb217a4b484a6d8a7",
		},
		{
			source = "res://entities/units/unit/unit.tscn",
			sourceMd5 = "f003f2b96779960bc06b2d9c7a1557dd",
		},
		{
			source = "res://entities/entity.tscn",
			sourceMd5 = "6b70440bccd50ac49048d848ff29c669",
		},
		{
			source = "res://projectiles/bullet_enemy/enemy_projectile.tscn",
			sourceMd5 = "936fb8e19c1a3dbccb65ad6f21725002",
		},
		{
			source = "res://projectiles/projectile.tscn",
			sourceMd5 = "812858f38125afcd1b80afb57cffed70",
		},
	},
	phaseBaseScene = "res://entities/units/enemies/bosses/boss_state.tscn",
	phaseBaseSceneMd5 = "7886b7a4624fecebf13d2a4c15caad93",
	statsSource = "res://entities/units/enemies/jungle/elites/silesaurus/silesaurus_stats.tres",
	statsMd5 = "e222b8077b84e1211b59e517eada536e",
	stats = {
		health = 1,
		health_increase_each_wave = 750,
		speed = 200,
		speed_randomization = 0,
		damage = 1,
		damage_increase_each_wave = 1.5,
		attack_cd = 30,
		value = 10,
		knockback_resistance = 1,
		gold_spread = 0,
		can_drop_consumables = true,
		always_drop_consumables = true,
		base_drop_chance = 1,
		item_drop_chance = 1,
		min_consumable_tier = 0,
		max_consumable_tier = 0,
		armor = 0,
		armor_increase_each_wave = 0,
		generate_blood = true,
	},
	body = {
		radiusPoints = 50,
		offsetPoints = {
			0,
			-15,
		},
	},
	hurt = {
		radiusPoints = 40.0125,
		offsetPoints = {
			0,
			-9,
		},
	},
	hit = {
		radiusPoints = 40,
		offsetPoints = {
			0,
			-8,
		},
	},
	mass = 100,
	bodyLayer = 4,
	bodyMask = 132,
	bodyBorders = true,
	sprite = {
		source = "res://entities/units/enemies/jungle/elites/silesaurus/silesaurus.png",
		textureSource = "res://.import/silesaurus.png-4faa98aba3aa57165f268431a1fc15fc.stex",
		textureMd5 = "d2ab5cdd8c7a49d3de19282ce9d79b27",
		widthPoints = 200,
		heightPoints = 200,
	},
	movements = {
		{
			range_around_player = 300,
			range_randomization = 0,
			update_every_x_frames = -1,
		},
		{
			range_around_player = 300,
			range_randomization = 0,
			update_every_x_frames = 120,
		},
		{
			range_around_player = 300,
			range_randomization = 0,
			update_every_x_frames = 60,
		},
	},
	spawn = {
		source = "res://entities/units/enemies/jungle/basic/enigmacursor/enigmacursor.tscn",
		count = 2,
		minimumCount = 1,
		areaPoints = 600,
		properties = {
			cooldown = 60,
			max_cd_randomization = 0,
			attack_anim_speed = 1,
			nb_to_spawn = 2,
			spawn_random_pos_area = -1,
			spawn_at_random_pos = false,
			spawn_at_player_range = false,
			spawn_at_player_radius = 250,
			spawn_in_radius_around_unit = 600,
			max_nb_of_spawns = -1,
		},
	},
	shooting = {
		{
			cooldown = 12,
			max_cd_randomization = 0,
			initial_cooldown = 0,
			long_cooldown_every_x_shoots = 10,
			long_cooldown = 120,
			attack_anim_speed = 4,
			min_range = 0,
			max_range = 1500,
			damage = 1,
			damage_increase_each_wave = 1.15,
			number_projectiles = 3,
			projectile_spread = 0,
			constant_spread = false,
			projectile_spawn_spread = 55,
			speed_change_after_each_projectile = 0,
			shoot_from_proj_pos_towards_player = true,
			random_rotation = 0,
			use_transform_offset = true,
			projectile_speed_randomization = 0,
			move_locked = false,
			recovery_cooldown = 0,
			projectile_spawn_only_on_borders = false,
			spawn_projectiles_on_target = false,
			script = {
				resource = "res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gd",
				resourceType = "Script",
			},
			position = {
				variantType = "Vector2",
				values = {
					45,
					-100,
				},
			},
			projectile_speed = 850,
		},
		{
			cooldown = 10,
			max_cd_randomization = 0,
			initial_cooldown = 60,
			long_cooldown_every_x_shoots = 2,
			long_cooldown = 60,
			attack_anim_speed = 3,
			min_range = 0,
			max_range = 600,
			damage = 1,
			damage_increase_each_wave = 1.15,
			number_projectiles = 4,
			projectile_spread = 0.1,
			constant_spread = true,
			projectile_spawn_spread = 75,
			speed_change_after_each_projectile = 0,
			shoot_from_proj_pos_towards_player = false,
			random_rotation = 0.3,
			use_transform_offset = true,
			projectile_speed_randomization = 0,
			move_locked = false,
			recovery_cooldown = 0,
			projectile_spawn_only_on_borders = false,
			spawn_projectiles_on_target = false,
			script = {
				resource = "res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gd",
				resourceType = "Script",
			},
			position = {
				variantType = "Vector2",
				values = {
					45,
					-100,
				},
			},
			projectile_speed = 650,
			constant_spread_rand_base_pos = 3.14,
		},
	},
	bullet = {
		source = "res://projectiles/bullet_enemy/enemy_projectile.tscn",
		sourceMd5 = "936fb8e19c1a3dbccb65ad6f21725002",
		radiusPoints = 17.0294,
		offsetPoints = {
			0,
			0,
		},
	},
	speedReset = {
		sourceChildIndex = 1,
		percent = 75,
	},
	normalActorRegistered = true,
	evolutionProfilesImplemented = false,
	nativeFullParityAccepted = false,
}
local clock = C.shootingClockRules
local spawn = data.spawn.properties
data.shootingRules = {
	frameRate = clock.frameRate,
	minimumCooldownFrames = clock.minimumCooldownFrames,
	fireAt = clock.animationFireAt,
	animationSeconds = clock.animationSeconds,
	profiles = {
		{
			cooldown = spawn.cooldown,
			randomization = spawn.max_cd_randomization,
			initial = 0,
			longEvery = 0,
			longFrames = 0,
			animationSpeed = spawn.attack_anim_speed,
			minRange = 0,
			maxRange = 0,
			unrestricted = true,
		},
	},
}
data.volleys = {}
for index, a in data.shooting do
	table.insert(data.shootingRules.profiles, {
		cooldown = a.cooldown,
		randomization = a.max_cd_randomization,
		initial = a.initial_cooldown,
		longEvery = a.long_cooldown_every_x_shoots,
		longFrames = a.long_cooldown,
		animationSpeed = a.attack_anim_speed,
		minRange = a.min_range * POINT,
		maxRange = a.max_range * POINT,
	})
	data.volleys[index] = {
		count = a.number_projectiles,
		spread = a.projectile_spread,
		constantSpread = a.constant_spread,
		offsetX = a.position.values[1] * POINT,
		offsetZ = a.position.values[2] * POINT,
		speedStep = a.speed_change_after_each_projectile * POINT,
		spawnSquare = a.projectile_spawn_spread * POINT,
		baseAimFromSpawn = true,
		aimFromSpawn = if a.shoot_from_proj_pos_towards_player then { targetRotation = a.random_rotation } else nil,
	}
end
local init = require(script.Parent.NativeTherizinosaurus).bossInit
data.controller = {
	family = "Silesaurus",
	shooting = data.shootingRules,
	phases = C.actors.Silesaurus,
	init = init,
	projectileDamage = data.shooting[1].damage,
	projectileRange = J.shootingRules.projectileRangeStuds,
	projectileRadius = data.bullet.radiusPoints * POINT,
	attacks = {
		{
			kind = "Spawn",
			summon = { enemy = "Enigmacursor", count = data.spawn.count, area = data.spawn.areaPoints * POINT },
			minimumCount = data.spawn.minimumCount,
		},
	},
	movements = {},
	speedReset = { profile = data.speedReset.sourceChildIndex + 2, percent = data.speedReset.percent },
}
for index, a in data.shooting do
	table.insert(
		data.controller.attacks,
		{ kind = "Bullet", speed = a.projectile_speed * POINT, volley = data.volleys[index] }
	)
end
for index, m in data.movements do
	data.controller.movements[index] = {
		around = "Target",
		range = m.range_around_player * POINT,
		rangeJitter = 0,
		arriveStuds = J.spawningRules.goalPrecisionPoints * POINT,
		maxSeconds = if m.update_every_x_frames == -1 then math.huge else m.update_every_x_frames / clock.frameRate,
	}
end
local s = data.stats
data.kind = {
	id = "Silesaurus",
	typeId = 73,
	displayName = "Silesaurus",
	look = "Brute",
	nativeArtPending = true,
	nativeZoneId = J.zoneId,
	nativeScene = data.source,
	specialSpawn = true,
	nativeBoss = data.controller,
	wander = data.controller.movements[1],
	hp = s.health,
	hpPerWave = s.health_increase_each_wave,
	contactDamage = s.damage,
	damagePerWave = s.damage_increase_each_wave,
	speed = s.speed * POINT,
	nativeSpeedPoints = { base = s.speed, randomization = s.speed_randomization },
	xp = s.value,
	shotDamagePerWave = data.shooting[1].damage_increase_each_wave,
	radius = data.body.radiusPoints * POINT,
	hurtRadius = data.hurt.radiusPoints * POINT,
	hitRadius = data.hit.radiusPoints * POINT,
	nativeBodyOffsetX = data.body.offsetPoints[1] * POINT,
	nativeBodyOffsetZ = data.body.offsetPoints[2] * POINT,
	nativeHurtOffsetX = data.hurt.offsetPoints[1] * POINT,
	nativeHurtOffsetZ = data.hurt.offsetPoints[2] * POINT,
	nativeHitOffsetX = data.hit.offsetPoints[1] * POINT,
	nativeHitOffsetZ = data.hit.offsetPoints[2] * POINT,
	nativeBodyLayer = data.bodyLayer,
	nativeBodyMask = data.bodyMask,
	nativeObstacleCollision = bit32.band(data.bodyMask, 128) ~= 0,
	nativeMovement = {
		borderClamp = data.bodyBorders,
		goalInsetX = data.sprite.widthPoints * POINT / 2,
		goalInsetZ = data.sprite.heightPoints * POINT / 2,
		precision = J.spawningRules.goalPrecisionPoints * POINT,
		collidePlayers = bit32.band(data.bodyMask, 2) ~= 0,
	},
	mass = data.mass,
	knockbackResistance = s.knockback_resistance,
	nativeArmor = { base = s.armor, perWave = s.armor_increase_each_wave },
	nativeHealthRounding = true,
	nativeDamageRounding = true,
	nativeCanBeBoosted = false,
	nativeCanBeCharmed = false,
	loot = { consumableChance = s.base_drop_chance, crateShare = s.item_drop_chance, crate = true, alwaysOrbs = true },
}
return data
