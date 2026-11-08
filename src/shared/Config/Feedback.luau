--!strict
-- Hit feedback (DESIGN.md section 14, since the fun package after WP9): damage numbers, death bursts and camera
-- shake, plus when big crowds drop small enemy trims (since the Deadlock look package) and the embers of burning
-- enemies (B5). Read by WeaponService
-- (which hits to send), DamageNumberController, EnemyRenderer, CameraController and FeedbackController. Since Paket 14
-- each player can also switch shaking and damage numbers off in the settings menu (Config.Settings). Since Paket 22 the
-- *Touch values are the Low graphics values (Config.Graphics; phones get Low unless the player picks High).

return table.freeze({
	damageNumbers = table.freeze({
		enabled = true,
		maxVisible = 40, -- numbers on screen at once; the oldest makes room
		maxVisibleTouch = 20, -- with Low graphics (phones and tablets by default)
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
	-- fewer parts; elites keep them (assumption); lowAboveTouch with Low graphics (Paket 22)
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
	-- red blobs splashing from a hit enemy towards the nearest player (EnemyRenderer/HitBursts), as in the owner's Brotato
	-- screenshots (08.11.2026); color, count, size and speed estimated from them. At most `maxPerFrame` enemies splash in
	-- one frame; enemies off the screen never do.
	hitBursts = table.freeze({
		enabled = true,
		color = { 190, 30, 40 }, -- { red, green, blue }
		particles = 3, -- per hit
		particlesTouch = 2, -- with Low graphics
		maxPerFrame = 12,
		maxPerFrameTouch = 5,
		spreadDegrees = 35,
		speed = { 5, 12 }, -- studs/s, min and max
		lifetime = { 0.35, 0.6 }, -- seconds, min and max
		size = 0.8, -- studs
		drag = 6,
		height = 0.8, -- times the enemy radius above the floor
		zOffset = 2, -- studs towards the camera, so blobs show in front of the figures
	}),
})
