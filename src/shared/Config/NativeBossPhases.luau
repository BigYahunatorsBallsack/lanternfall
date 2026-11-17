--!strict
-- Source Jungle boss phase thresholds and explicit Therizinosaurus phase projectile binding; production boss controllers remain pending.
local data = {
	version = "1.2.0.3",
	steamBuild = 26642464,
	elapsedPerTimeout = 1,
	initialState = -1,
	timerScene = "res://entities/units/enemies/bosses/boss.tscn",
	timerSceneMd5 = "6018962cd6605773a1e63165e73a4dbc",
	ruleSources = {
		{
			source = "res://entities/units/enemies/bosses/boss.gdc",
			sourceMd5 = "a3cc583e1e8521d2899b6b7c56734685",
		},
		{
			source = "res://entities/units/enemies/bosses/boss_state.gdc",
			sourceMd5 = "7f6f65ae801262a06b954dbe7daaeddc",
		},
		{
			source = "res://entities/units/enemies/jungle/bosses/brachiosaurus/brachiosaurus.gdc",
			sourceMd5 = "c6e796b45d913450339d57f1997d3cdf",
		},
		{
			source = "res://entities/units/enemies/jungle/bosses/tyrannosaurus/tyranosaurus.gdc",
			sourceMd5 = "f44f413a22a26308968fd4575860cabf",
		},
		{
			source = "res://entities/units/enemies/jungle/elites/carnotaurus/carnotaurus.gdc",
			sourceMd5 = "372e3bb1b2aa3bd24d0bea3c65ee6fbc",
		},
		{
			source = "res://entities/units/enemies/jungle/elites/silesaurus/silesaurus.gdc",
			sourceMd5 = "3dc7ae8b914cefbc9cc1c0174cbda70c",
		},
		{
			source = "res://entities/units/enemies/jungle/elites/therizinosaurus/therizinosaurus.gdc",
			sourceMd5 = "53e588213796a45ee4727f7a9205ea07",
		},
		{
			source = "res://entities/units/enemies/jungle/elites/diplodocus/diplodocus.gdc",
			sourceMd5 = "af84fabc22f46610936179144ddf33bf",
		},
		{
			source = "res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gdc",
			sourceMd5 = "43d5ebd849396509ff38632915c988a2",
		},
		{
			source = "res://entities/units/enemies/enemy.gdc",
			sourceMd5 = "b341670f5ac667dc203f7eb778a2cda8",
		},
	},
	actors = {
		Brachiosaurus = {
			source = "res://entities/units/enemies/jungle/bosses/brachiosaurus/brachiosaurus.tscn",
			sourceMd5 = "6c4e272aa68f9a47d91ee6fe7234ea3e",
			usesBasePhaseTimer = false,
			states = {
				{
					node = "State1",
					hpStart = 0.7,
					timerStart = 15,
				},
				{
					node = "State2",
					hpStart = 0.3,
					timerStart = 75,
				},
			},
		},
		Tyranosaurus = {
			source = "res://entities/units/enemies/jungle/bosses/tyrannosaurus/tyranosaurus.tscn",
			sourceMd5 = "99756375db500a4b0d146a6b08671342",
			usesBasePhaseTimer = true,
			states = {
				{
					node = "State1",
					hpStart = 0.7,
					timerStart = 15,
				},
			},
		},
		Baryonyx = {
			source = "res://entities/units/enemies/jungle/elites/baryonyx/baryonyx_neutral.tscn",
			sourceMd5 = "7b3be98c6ad6ad9dc390073f6dcba71b",
			usesBasePhaseTimer = true,
			states = {
				{
					node = "State1",
					hpStart = 0.5,
					timerStart = 30,
				},
			},
		},
		Carnotaurus = {
			source = "res://entities/units/enemies/jungle/elites/carnotaurus/carnotaurus_neutral.tscn",
			sourceMd5 = "e2baaa04dabeb191234049ac1bd32681",
			usesBasePhaseTimer = false,
			states = {
				{
					node = "State1",
					hpStart = 0.5,
					timerStart = 40,
				},
			},
		},
		Diplodocus = {
			source = "res://entities/units/enemies/jungle/elites/diplodocus/diplodocus.tscn",
			sourceMd5 = "d0805671ab5fe90cb3359c9fa9f56843",
			usesBasePhaseTimer = true,
			states = {
				{
					node = "State1",
					hpStart = 0.5,
					timerStart = 25,
				},
			},
		},
		Silesaurus = {
			source = "res://entities/units/enemies/jungle/elites/silesaurus/silesaurus.tscn",
			sourceMd5 = "7c0b1ed5c7b0596267d328dde443ac4b",
			usesBasePhaseTimer = true,
			states = {
				{
					node = "State1",
					hpStart = 0.85,
					timerStart = 10,
				},
				{
					node = "State2",
					hpStart = 0.5,
					timerStart = 35,
				},
			},
		},
		Therizinosaurus = {
			source = "res://entities/units/enemies/jungle/elites/therizinosaurus/therizinosaurus.tscn",
			sourceMd5 = "526ab1bac95d7acc87a9fa5f701de07f",
			usesBasePhaseTimer = true,
			states = {
				{
					node = "State1",
					hpStart = 0.45,
					timerStart = 30,
				},
			},
			shooting = {
				root = {
					projectileSource = "res://projectiles/slash/slash_projectile.tscn",
					scriptSource = "res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gd",
					properties = {
						projectile_speed = 500,
						projectile_speed_randomization = 0,
						speed_change_after_each_projectile = 0,
						cooldown = 5,
						initial_cooldown = 10,
						max_cd_randomization = 0,
						long_cooldown_every_x_shoots = 6,
						long_cooldown = 120,
						damage = 1,
						damage_increase_each_wave = 1.15,
						min_range = 0,
						max_range = 850,
						attack_anim_speed = 3,
						base_direction_randomization = 0,
						base_direction_constant_spread = false,
						alternate_between_base_direction_spread = false,
						random_direction = false,
						number_projectiles = 1,
						projectile_spread = 0,
						spawn_projectiles_on_target = false,
						projectile_spawn_spread = 350,
						projectile_spawn_only_on_borders = false,
						use_specific_angle = false,
						constant_spread = false,
						constant_spread_rand_base_pos = 0,
						atleast_one_projectile_on_target = false,
						shoot_towards_unit = false,
						shoot_in_unit_direction = true,
						shoot_away_from_unit = false,
						shoot_from_proj_pos_towards_player = false,
						random_rotation = 0.3,
						rotate_projectile = true,
						delete_projectile_on_death = false,
						parallel_slashes = false,
						parallel_spacing = 40,
						parallel_angle_offset = 0,
						scale_projectiles_with_count = false,
						min_projectile_scale = 0.5,
						forward_spawn_offset = 150,
						use_transform_offset = false,
						move_locked = false,
						autoturn_on_shoot = false,
						recovery_cooldown = 0,
					},
				},
				phaseOne = {
					projectileSource = "res://projectiles/bullet_enemy/enemy_projectile.tscn",
					scriptSource = "res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gd",
					baseScene = "res://entities/units/enemies/bosses/boss_state.tscn",
					baseSceneMd5 = "7886b7a4624fecebf13d2a4c15caad93",
					projectileBinding = "Default of the independently instanced boss_state AttackBehavior; no root-attack inheritance.",
					properties = {
						number_projectiles = 12,
						projectile_spread = 0,
						spawn_projectiles_on_target = false,
						projectile_spawn_spread = 200,
						projectile_spawn_only_on_borders = true,
						constant_spread = true,
						constant_spread_rand_base_pos = 3.14,
						shoot_from_proj_pos_towards_player = true,
						random_rotation = 1.2,
						speed_change_after_each_projectile = 0,
						projectile_speed = 600,
						cooldown = 12,
						initial_cooldown = 30,
						max_cd_randomization = 0,
						long_cooldown_every_x_shoots = 3,
						long_cooldown = 150,
						damage_increase_each_wave = 1.15,
						max_range = 1000,
						attack_anim_speed = 1.5,
					},
				},
			},
		},
	},
	shootingClockRules = {
		frameRate = 60,
		minimumCooldownFrames = 1,
		animationFireAt = 0.8,
		animationSeconds = 1,
		animations = {
			{
				source = "res://entities/units/enemies/attack_behaviors/shoot.tres",
				sourceMd5 = "2cb1eabb59abc712266d8e6cb496ab3f",
				fireAt = 0.8,
				seconds = 1,
			},
			{
				source = "res://entities/units/enemies/attack_behaviors/shoot_charmed.tres",
				sourceMd5 = "9559f5748dbbfbf70a8e3e803002fd47",
				fireAt = 0.8,
				seconds = 1,
			},
		},
	},
	productionAdapterImplemented = false,
	nativeFullParityAccepted = false,
	audit = {
		elapsedBeforeSelection = true,
		hpInclusive = true,
		timeInclusive = true,
		everyEligibleLaterChildInOrder = true,
		synchronousCallbackBeforeNextChild = true,
		sourceIndicesStartAtZero = true,
		Carnotaurus = "Timer requests a deferred phase switch after the current jump has landed; not the base HP/time loop.",
		Brachiosaurus = "Timer directly calls on_state_changed(current_state) and increments that custom index; not the base HP/time loop.",
	},
}
local POINT = require(script.Parent.Stats).range.studsPerPoint
local a = data.actors.Therizinosaurus.shooting.phaseOne.properties
data.therizinosaurusPhaseOneVolley = {
	count = a.number_projectiles,
	spread = a.projectile_spread,
	constantSpread = a.constant_spread,
	offsetX = 0,
	offsetZ = 0,
	speedStep = a.speed_change_after_each_projectile * POINT,
	spawnRing = {
		radius = a.projectile_spawn_spread / 2 * POINT,
		away = false,
		baseRandomization = a.constant_spread_rand_base_pos,
	},
	aimFromSpawn = { targetRotation = a.random_rotation },
}
local function profile(a)
	return {
		cooldown = a.cooldown,
		randomization = a.max_cd_randomization,
		initial = a.initial_cooldown,
		longEvery = a.long_cooldown_every_x_shoots,
		longFrames = a.long_cooldown,
		animationSpeed = a.attack_anim_speed,
		minRange = (a.min_range or 0) * POINT,
		maxRange = a.max_range * POINT,
	}
end
data.therizinosaurusShooting = {
	frameRate = data.shootingClockRules.frameRate,
	minimumCooldownFrames = data.shootingClockRules.minimumCooldownFrames,
	fireAt = data.shootingClockRules.animationFireAt,
	animationSeconds = data.shootingClockRules.animationSeconds,
	profiles = { profile(data.actors.Therizinosaurus.shooting.root.properties), profile(a) },
}
return data
