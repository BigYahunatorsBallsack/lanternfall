--!strict
-- Approved saved normal Ankylosaurus charge rules for NativeStraightCharge; full actor family remains pending.
local pixel = require(script.Parent.Stats).range.studsPerPoint
local source = {
	version = "1.2.0.3",
	steamBuild = 26642464,
	source = "res://entities/units/enemies/attack_behaviors/charging_attack_behavior.gdc",
	sourceMd5 = "fcf2901832ca42a4e69e98c60629397e",
	variant = {
		source = "res://entities/units/enemies/jungle/basic/ankylosaurus/ankylosaurus.tscn",
		sourceMd5 = "326c86b0680d2e079dc475a96564e7bd",
		behavior = "res://entities/units/enemies/attack_behaviors/charging_attack_behavior.gd",
		behaviorMd5 = "fcf2901832ca42a4e69e98c60629397e",
		effective = {
			cooldown = 40,
			long_cooldown_every_x_shoots = 0,
			long_cooldown = 0,
			max_cd_randomization = 20,
			min_range = 0,
			max_range = 600,
			range_X = -1,
			range_Y = -1,
			attack_anim_speed = 1.5,
			charge_duration = 0.75,
			charge_speed = 450,
			target_calculation_timing = 1,
			target = 1,
			rand_target_size = -1,
			only_positions_in_target_direction = true,
			scale_charge_duration_with_range = false,
			recovery_duration = 0.05,
		},
	},
	animation = {
		source = "res://entities/units/enemies/attack_behaviors/shoot.tres",
		sourceMd5 = "2cb1eabb59abc712266d8e6cb496ab3f",
		fireAt = 0.8,
		seconds = 1,
	},
	frameRate = 60,
	minimumCooldownFrames = 1,
	massMultiplier = 5,
	around = {
		maximumDefaultRadiusPoints = 600,
		rangeDivisor = 5,
		coneDegrees = 180,
		minimumDistanceDivisor = 4,
	},
	familyActivated = false,
	scope = "Normal Ankylosaurus charge target selection and timer integration only; no full actor family, image/goal geometry or area activation.",
	rangeHelper = {
		source = "res://singletons/utils.gdc",
		sourceMd5 = "2c263b6d3c2355dd71d6ad4caf0705bf",
		distanceArgumentType = "int",
		inclusive = true,
		distanceConversion = "truncate nonnegative distance in original pixel units before inclusive comparison",
	},
	previousSourceVersion = "1.2.0.2",
	previousResourcesRevalidatedIdentical = true,
}
local rule = {
	cooldown = 0.666666666666667,
	jitter = 0.333333333333333,
	minimumCooldown = 0.0166666666666667,
	fireAt = 0.533333333333333,
	duration = 0.75,
	recovery = 0.05,
	massMultiplier = 5,
	target = {
		atShoot = true,
		radius = 120,
		coneHalfAngle = 1.5707963267949,
		minimumRadiusShare = 0.25,
		inMovementDirection = true,
	},
	speed = 450,
	rangeX = -1,
	rangeZ = -1,
	minRange = 0,
	maxRange = 600,
}
rule.speed *= pixel
rule.rangeX *= pixel
rule.rangeZ *= pixel
rule.minRange *= pixel
rule.maxRange *= pixel
rule.target.radius *= pixel
return { source = source, rule = rule }
