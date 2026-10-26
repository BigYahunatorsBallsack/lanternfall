--!strict
-- Enemy engine settings and performance budgets (DESIGN.md section 15). Read by EnemySim, SpawnDirector,
-- WeaponService, EnemyRenderer and the debug stats panel. Values marked "assumption" get tuned in playtests (WP7, WP9).

return table.freeze({
	tickRate = 15, -- server simulation steps per second
	maxCatchUpSteps = 3, -- after a server hitch at most this many steps run in one frame, the rest is dropped
	spatialHashCellSize = 8, -- studs
	interpolationDelay = 0.1, -- seconds the client renders behind the newest snapshot

	playerRadius = 1.2, -- studs; enemies stop at their own radius + this (about an R15 torso)
	contactMargin = 0.3, -- studs; enemies this close to a player's circle touch them
	-- Players see enemies a little in the past (interpolationDelay + travel time) while the server sees the
	-- player a little in the past too. Contacts are therefore checked where the player is moving to:
	-- position + velocity * (contactLeadSeconds + ping), at most contactLeadMaxStuds ahead.
	contactLeadSeconds = 0.15,
	contactLeadMaxPing = 0.3, -- seconds; higher pings count as this
	contactLeadMaxStuds = 5,
	separationStiffness = 0.8, -- share of the overlap of two enemies removed per pass, 0-1 (assumption)
	separationPasses = 3, -- more passes = fewer overlaps in dense crowds, but more server time per step
	obstacleSteerMargin = 2, -- studs; enemies start sliding around an obstacle this far from it (assumption)
	keepDistanceTolerance = 2, -- studs; ranged enemies stand still within +- this of their keepDistance
	-- Weapons step right after the enemies (WeaponService). A spinning blade is checked in pieces so its tip
	-- moves at most this far per check; smaller is more exact but costs more server time.
	weaponSweepStep = 1.5, -- studs

	-- Shown in the admin stats panel; red when a value breaks its budget.
	budget = table.freeze({
		stepMilliseconds = 4, -- server time per simulation step
		clientFps = 30, -- at least, on a mid-range phone
		networkKilobytesPerSecond = 50, -- at most, per client
	}),
})
