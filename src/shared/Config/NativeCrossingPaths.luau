--!strict
-- Source crossing path and warning facts; NativeCrossing consumes these before actor registration.
return {
	version = "1.2.0.3",
	steamBuild = 26642464,
	families = {
		Oviraptor = {
			source = "res://entities/units/enemies/jungle/basic/oviraptor/oviraptor.tscn",
			sourceMd5 = "37070a438aa1f6a6d9d7fc460bdfa695",
			rootScript = "res://entities/units/enemies/jungle/basic/oviraptor/oviraptor.gd",
			movementScript = "res://entities/units/movement_behaviors/go_towards_border_opposite_movement_behavior.gd",
			warningSeconds = 0.35,
			maxYDiff = 3,
			actorRegistered = false,
		},
		Iguanodon = {
			source = "res://entities/units/enemies/jungle/basic/iguanodon/iguanodon.tscn",
			sourceMd5 = "2ef45c86848db34cf87bb386d52ea499",
			rootScript = "res://entities/units/enemies/jungle/basic/oviraptor/oviraptor.gd",
			movementScript = "res://entities/units/movement_behaviors/go_towards_border_opposite_movement_behavior.gd",
			warningSeconds = 1.5,
			maxYDiff = 3,
			actorRegistered = false,
		},
	},
	rules = {
		initialJitterStuds = 10,
		exitOvershootStuds = 15,
		warningShake = 1.2,
		timeoutEnablesBody = true,
		warningArrowCalled = false,
		warningLineCalled = false,
		genericEnemyMayEnableHiddenContact = true,
		exitUsesDespawnNotKill = true,
	},
	ruleSources = {
		{
			source = "res://entities/units/movement_behaviors/go_towards_border_opposite_movement_behavior.gdc",
			sourceMd5 = "3dba897e0c1b550635a785bbc8c6654e",
		},
		{
			source = "res://entities/units/enemies/jungle/basic/oviraptor/oviraptor.gdc",
			sourceMd5 = "d30e4a138b6937a199d967b06ab65fe0",
		},
		{
			source = "res://singletons/zone_service.gdc",
			sourceMd5 = "d16899aba618beb55e980f67a0bf10b0",
		},
		{
			source = "res://entities/units/enemies/enemy.gdc",
			sourceMd5 = "b341670f5ac667dc203f7eb778a2cda8",
		},
		{
			source = "res://entities/units/unit/unit.gdc",
			sourceMd5 = "aa94391f2d9681ac36b7f8617b82ff13",
		},
		{
			source = "res://overlap/hitbox.gdc",
			sourceMd5 = "c1b09a67ca1618f73c2e89751ab82226",
		},
	},
	worldConnected = false,
	nativePresentationAccepted = false,
}
