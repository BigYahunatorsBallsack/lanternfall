--!strict
-- Source centered infinite enemy laser geometry and clocks; NativeLaserService owns hostile instances.
local data = {
	version = "1.2.0.3",
	steamBuild = 26642464,
	source = "res://projectiles/laser_enemy/enemy_laser_infinite.tscn",
	sourceMd5 = "4cce0f7717b6f3f2645ffd063abdd14f",
	scriptSource = "res://projectiles/laser_enemy/enemy_laser.gdc",
	scriptMd5 = "d7910eed6ea19d16fa089013dd4baff1",
	halfExtentsPoints = {
		2000,
		15,
	},
	offsetPoints = {
		0,
		0,
	},
	frameRate = 60,
	delaySeconds = 0.75,
	afterSeconds = 0.4,
	audit = {
		sourceFollowsTranslation = true,
		rotationFixedAtBirth = true,
		stopAfterFirstHit = true,
		deleteWithSource = false,
		basePhysicsNotCalled = true,
		afterDecrementsOnEnablingFrame = true,
	},
	originalVisualAccepted = false,
}
return data
