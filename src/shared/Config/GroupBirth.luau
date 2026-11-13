--!strict
-- Native grouped edge births: source geometry and timing consumed by SpawnRules and SpawnDirector; no area availability changes.
return {
	version = "1.2.0.2",
	steamBuild = 26615634,
	source = "res://entities/birth/entity_group_birth.tscn",
	sourceMd5 = "c6bb7837b8bff002a2e13d5ff3317183",
	frameRate = 60,
	markerSeconds = 1.41666666666667,
	jitterXPoints = 25,
	jitterZPoints = 50,
	radiusPoints = 72,
	playerBody = {
		source = "res://entities/units/player/player.tscn",
		sourceMd5 = "58724d77253dd2ff1a91a8409a809193",
		radiusPoints = 24,
		offsetPoints = {
			0,
			-12,
		},
	},
	ruleSources = {
		{
			source = "res://global/entity_spawner.gdc",
			sourceMd5 = "ba0576c27ac5b889c5688decda3dd838",
		},
		{
			source = "res://entities/birth/entity_group_birth.gdc",
			sourceMd5 = "854e9b4ffa77bc6a79d3d28c9985af8e",
		},
		{
			source = "res://entities/birth/entity_birth.gdc",
			sourceMd5 = "bd11ca4adf9f253b288bcb655a7785f2",
		},
	},
	areaPlayable = false,
	normal = {
		source = "res://entities/birth/entity_birth.tscn",
		sourceMd5 = "5d51f77c75b5b04e0893174697d0d40f",
		markerSeconds = 1,
		radiusPoints = 72,
	},
}
