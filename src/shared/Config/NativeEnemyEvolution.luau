--!strict
-- Audited stable team evolution and scene boost percentages; component only, production enemy evolution remains pending.
return {
	version = "1.2.0.3",
	steamBuild = 26642464,
	sourceData = "res://effect_behaviors/scenes/evolution_scene_effect_behavior_data.tres",
	sourceDataMd5 = "ff6f15aea0b6fd33f0d9747852c74ed2",
	sourceScene = "res://effect_behaviors/scenes/evolution_scene_effect_behavior.tscn",
	sourceSceneMd5 = "24fb9ca3f4a50ded89faae17b6d9187d",
	sourceScript = "res://effect_behaviors/scenes/evolution_scene_effect_behavior.gd",
	settings = {
		hp_boost_meca = 50,
		hp_boost_per_evolution_meca = 2,
		damage_boost_meca_min = 25,
		damage_boost_meca_max = 50,
		speed_boost_meca_min = 5,
		speed_boost_meca_max = 25,
		hp_boost_mutant = 25,
		hp_boost_per_evolution_mutant = 2.4,
		damage_boost_mutant_min = 15,
		damage_boost_mutant_max = 80,
		speed_boost_mutant_min = 5,
		speed_boost_mutant_max = 25,
	},
	rules = {
		curveMaximum = 100,
		curveScale = 50,
		percent = 100,
		chanceDivisor = 2,
		endlessDivisor = 2,
		eliteMultiplier = 4,
		minimumMagnitude = 1,
		boostMagnitude = 100,
		mutantDamageMagnitude = 150,
		hpMagnitude = 300,
	},
	behaviorData = {},
	ruleSources = {
		{
			source = "res://global/team_evolution.gdc",
			sourceMd5 = "181c41245fca03a555deeb9b065f12b8",
		},
		{
			source = "res://singletons/utils.gdc",
			sourceMd5 = "2c263b6d3c2355dd71d6ad4caf0705bf",
		},
		{
			source = "res://effect_behaviors/scenes/evolution_scene_effect_behavior.gdc",
			sourceMd5 = "dc45c24ca1f29085674835e1d64879ad",
		},
	},
	productionAdapterImplemented = false,
	nativeFullParityAccepted = false,
}
