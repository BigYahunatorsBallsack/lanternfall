--!strict
-- Approved native player body and hurt-circle facts; PlayerHurtGeometry and Simulation read these independently.
return {
	version = "1.2.0.3",
	steamBuild = 26642464,
	source = "res://entities/units/player/player.tscn",
	sourceMd5 = "58724d77253dd2ff1a91a8409a809193",
	sceneChain = {
		"res://entities/units/player/player.tscn",
		"res://entities/units/unit/unit.tscn",
		"res://entities/entity.tscn",
	},
	scenes = {
		["res://entities/units/player/player.tscn"] = {
			sourceMd5 = "58724d77253dd2ff1a91a8409a809193",
			baseScene = "res://entities/units/unit/unit.tscn",
		},
		["res://entities/units/unit/unit.tscn"] = {
			sourceMd5 = "f003f2b96779960bc06b2d9c7a1557dd",
			baseScene = "res://entities/entity.tscn",
		},
		["res://entities/entity.tscn"] = {
			sourceMd5 = "6b70440bccd50ac49048d848ff29c669",
		},
	},
	body = {
		radiusPoints = 24,
		parentPoints = {
			0,
			0,
		},
		childPoints = {
			0,
			-12,
		},
		totalPoints = {
			0,
			-12,
		},
		initialParentScale = {
			1,
			1,
		},
		initialChildScale = {
			1,
			1,
		},
		initialParentRotation = 0,
		initialChildRotation = 0,
		collisionLayer = 2,
		collisionMask = 130,
	},
	hurt = {
		radiusPoints = 21,
		parentPoints = {
			0,
			-25,
		},
		childPoints = {
			0,
			13,
		},
		totalPoints = {
			0,
			-12,
		},
		initialParentScale = {
			1,
			1,
		},
		initialChildScale = {
			1,
			1,
		},
		initialParentRotation = 0,
		initialChildRotation = 0,
		collisionMask = 20,
	},
	previousSourceVersion = "1.2.0.2",
	previousResourcesRevalidatedIdentical = true,
}
