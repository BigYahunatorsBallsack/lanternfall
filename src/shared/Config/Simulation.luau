--!strict
-- Enemy engine settings and performance budgets (DESIGN.md section 15). Read by EnemySim, SpawnDirector,
-- EnemyRenderer and the debug stats panel. Values marked "assumption" get tuned in playtests (WP7, WP9).

return table.freeze({
	tickRate = 15, -- server simulation steps per second
	maxCatchUpSteps = 3, -- after a server hitch at most this many steps run in one frame, the rest is dropped
	spatialHashCellSize = 8, -- studs
	interpolationDelay = 0.1, -- seconds the client renders behind the newest snapshot

	playerRadius = 1.5, -- studs; enemies stop at their own radius + this (assumption)
	contactMargin = 0.5, -- studs; enemies this close to a player's circle touch them (assumption)
	separationStiffness = 0.8, -- share of the overlap of two enemies removed per pass, 0-1 (assumption)
	separationPasses = 3, -- more passes = fewer overlaps in dense crowds, but more server time per step
	obstacleSteerMargin = 2, -- studs; enemies start sliding around an obstacle this far from it (assumption)
	keepDistanceTolerance = 2, -- studs; ranged enemies stand still within +- this of their keepDistance

	-- Shown in the admin stats panel; red when a value breaks its budget.
	budget = table.freeze({
		stepMilliseconds = 4, -- server time per simulation step
		clientFps = 30, -- at least, on a mid-range phone
		networkKilobytesPerSecond = 50, -- at most, per client
	}),
})
