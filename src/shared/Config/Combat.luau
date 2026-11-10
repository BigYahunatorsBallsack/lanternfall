--!strict
-- Combat rules beyond a single hit (DESIGN.md section 6, Brotato direction since B5): knockback, burning, slows,
-- explosions, piercing and bouncing. Per weapon values stay in Config.Weapons; this holds what every weapon and item
-- effect shares. Read by WeaponService (WeaponStats, Arsenal, Afflictions), Util/StatMath and the client texts.

return table.freeze({
	nativeBoomerang = table.freeze({
		outDurationFactor = 1.6,
		apexSeconds = 0.15,
		apexSpeedFactor = 0.25,
		backMaxSpeedFactor = 1.2,
		backAccelerationFactor = 2,
		catchDistance = 3,
		maximumFlightSeconds = 4,
		minimumSpeed = 0.1,
		radius = 4.4,
		hitOffsetX = 0.1,
		hitOffsetZ = -0.1,
		hitRotationDegreesPerSecond = 1500,
	}),
	nativeBurn = table.freeze({
		minimumTickSeconds = 0.1, -- stable Unit.init BurningTimer minimum
	}),
	nativeFirePuddles = table.freeze({
		spawnSeconds = 0.2, -- stable FirePuddle spawn_duration
		despawnSeconds = 0.3,
		backOvershoot = 1.70158, -- Godot3.5 TRANS_BACK / EASE_OUT
		minimumSizeFactor = 0.1,
	}),
	originalWeapons = table.freeze({
		spreadPerProjectile = 0.1, -- stable WeaponService._set_common_ranged_stats, radians
		sourceFrameRate = 60, -- native stable weapon cooldown frame rate
		-- WeaponService.MIN_COOLDOWN: 2 frames, applied to the base cooldown and again after Attack Speed (at most 30
		-- attacks per second)
		sourceMinimumFrames = 2,
		minCooldown = 2 / 60,
		maxCatchupAttacks = 4, -- bounds extra attacks within one 15 Hz simulation step
		-- A weapon keeps aiming at its enemy until it leaves range or another one is closer than this share of its
		-- distance, so weapons stop flicking between nearly equally near enemies (owner 08.11.2026; not a wiki value).
		targetSwitchRatio = 0.7,
		targetCandidates = 8, -- nearest enemies searched for the kept target
	}),
	-- Stable Unit.add_decaying_speed/_process: original point units, not a percentage fade over the hold duration.
	nativeSlows = table.freeze({
		stopAddingShare = 0.7,
		diminishAfterShare = 0.45,
		diminishDivisor = 20,
		maximumAdditionShare = 0.9,
		recoveryPointsPerSecond = 300,
	}),
	-- Knockback in Brotato points (a crossbow has 8, a hammer 30), pushed mostly away from the owner. The Knockback
	-- stat adds points to every weapon. Enemies keep 1 - knockbackResistance of it (Config.Enemies), elites none.
	-- Brotato 1.2.0.1 Unit.get_next_knockback_value/get_knockback_value: a hit sets the knockback vector to direction x
	-- points (direction: hitDirectionShare); every 60 Hz frame the vector shrinks to decayPerFrame of itself and moves the enemy by vector x
	-- speedPerPoint x (1 - resistance) px/s, so one point pushes about 15 px (1.5 studs) over half a second. While that
	-- push is faster than the enemy walks, its contact hitbox is off (Enemy._physics_process).
	knockback = table.freeze({
		studsPerPoint = 0.1, -- weapon stats carry points x this (0.1 studs per Brotato pixel, like Range)
		decayPerFrame = 0.9,
		speedPerPoint = 100, -- px/s per point of the current vector
		frameRate = 60,
		stopBelow = 0.01, -- points; smaller vectors are dropped
		-- Unit.take_damage: direction = 0.2 x the attack's direction + 0.8 x away from the owner (Arsenal.knockDirection)
		hitDirectionShare = 0.2,
	}),
	-- Burning (Brotato's burn): `ticks` hits of the burn damage, one every tickSeconds; Burning Speed shortens the
	-- interval by its percent (+20 % = 0.4 s, -100 % = 1 s), never below minTickSeconds. Burns do not stack: a new one
	-- keeps the higher damage and the more ticks of the two. Burns cannot crit or life steal. Spreading: on every tick a
	-- burn with `spread` passes a copy to that many of the nearest enemies within spreadRadius that do not burn yet,
	-- and copies spread on (spreadRadius is an assumption, Brotato gives no number).
	-- Brotato 1.2.0.1 unit.tscn BurningTimer 0.5 s x (1 + increase - reduction), at least 0.1 s (Unit.init); the wiki's
	-- "every second" is outdated. A burn's `ticks` are timer ticks.
	burn = table.freeze({
		tickSeconds = 0.5,
		minTickSeconds = 0.1,
		spreadRadius = 8, -- studs
	}),
	-- Explosions: a radius at 100 % size, Brotato's res://projectiles/explosion.tscn circle (147.34 px x 0.1 studs per
	-- px, file 1.2.0.1); a weapon's or item's explosion `scale` is a share of it. Explosion Size scales every radius, Explosion Damage every explosion's damage. Explosions crit like the
	-- weapon, never life steal and never knock back.
	explosion = table.freeze({
		minimumSizeFactor = 0.1, -- stable PlayerExplosion.set_area minimum
		baseRadius = 147.34 * 0.1, -- studs (Config.Stats.range.studsPerPoint)
	}),
	-- Piercing (Brotato): every enemy after the first takes `falloff` less than the one before, unless the weapon sets
	-- its own pierceFalloff; Piercing Damage gives some of it back, never above full damage.
	piercing = table.freeze({
		falloff = 0.5,
	}),
	-- Bouncing (Brotato): a projectile that would stop flies on to a random enemy within `range` studs it has not hit
	-- yet (Brotato: unlimited range; assumption), each bounce dealing `falloff` less. Bounces come before piercing and
	-- lose the knockback.
	bounce = table.freeze({
		falloff = 0.5,
		range = 25, -- studs
	}),
	-- Giant Belt: health-percent bonus is unmodifiable and weakens in endless waves.
	healthPercent = table.freeze({ endlessFactorShare = 0.2 }),
})
