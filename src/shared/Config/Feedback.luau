--!strict
-- Hit feedback (DESIGN.md section 14, since the fun package after WP9): damage numbers, death bursts and camera
-- shake, plus when big crowds drop small enemy trims (since the Deadlock look package) and the embers of burning
-- enemies (B5). Read by WeaponService
-- (which hits to send), DamageNumberController, EnemyRenderer, CameraController and FeedbackController. The switches
-- become player settings with the full HUD (WP14).

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
	-- above this many enemies on screen, plain enemies leave out small trims (claws, filters, hems) to move a third
	-- fewer parts; elites keep them (assumption, to be checked on phones in WP22)
	enemyDetail = table.freeze({
		lowAbove = 80,
		lowAboveTouch = 40,
		backBelowShare = 0.85, -- full detail again below this share of the limit
	}),
	-- embers rising from burning enemies (B5): `particles` every `interval` seconds per enemy, at most `maxPerFrame`
	-- enemies emit in one frame (assumption)
	burnEmbers = table.freeze({
		enabled = true,
		interval = 0.3,
		particles = 2,
		maxPerFrame = 6,
		maxPerFrameTouch = 3,
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
