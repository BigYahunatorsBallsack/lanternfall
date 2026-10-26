--!strict
-- Technical limits for the enemy engine (DESIGN.md section 15). Read by EnemySim and EnemyRenderer.

return table.freeze({
	tickRate = 15, -- server simulation steps per second
	spatialHashCellSize = 8, -- studs
	interpolationDelay = 0.1, -- seconds the client renders behind the newest snapshot
	maxStepMilliseconds = 4, -- budget per simulation step
})
