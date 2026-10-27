--!strict
-- Hit feedback (DESIGN.md section 14, since the fun package after WP9): damage numbers, death bursts and camera
-- shake. Read by WeaponService (which hits to send), DamageNumberController, EnemyRenderer, CameraController and
-- FeedbackController. The switches become player settings with the full HUD (WP14).

return table.freeze({
	damageNumbers = table.freeze({
		enabled = true,
		maxVisible = 40, -- numbers on screen at once; the oldest makes room
		maxVisibleTouch = 20, -- on phones and tablets
		seconds = 0.7, -- each number rises and fades this long
		riseStuds = 2.5,
	}),
	deathBursts = table.freeze({
		enabled = true,
		particles = 6, -- per killed enemy
		particlesTouch = 3,
		eliteParticles = 30,
	}),
	-- strength 0-1 of a camera shake; several shakes add up to at most 1
	shake = table.freeze({
		enabled = true,
		maxStuds = 0.9, -- camera offset at strength 1
		decayPerSecond = 2.5, -- strength lost per second
		playerHit = 0.35,
		eliteKill = 0.8,
		chestOpen = 0.5,
	}),
})
