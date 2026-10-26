--!strict
-- Placeholder map layout (DESIGN.md section 14): lobby platform and arena, built in code by MapService
-- until the real map arrives in WP21. EnemySim and SpawnDirector read the arena bounds and obstacles
-- through MapService. All values in studs.

return table.freeze({
	arena = table.freeze({
		center = Vector3.new(0, 100, 0), -- center of the floor surface
		size = 300, -- side length of the square arena
		wallHeight = 40,
		spawnRadius = 8, -- participants start on a circle of this radius
		-- Placeholder ruins: round pillars that enemies walk around (circles for EnemySim).
		-- x/z are offsets from the arena center.
		obstacles = table.freeze({
			table.freeze({ x = 0, z = 35, radius = 4 }),
			table.freeze({ x = -70, z = -50, radius = 8 }),
			table.freeze({ x = 65, z = -75, radius = 6 }),
			table.freeze({ x = -60, z = 70, radius = 7 }),
			table.freeze({ x = 75, z = 55, radius = 10 }),
		}) :: { { x: number, z: number, radius: number } },
		obstacleHeight = 14,
	}),
	lobby = table.freeze({
		center = Vector3.new(0, 100, -400),
		size = 80,
		wallHeight = 20,
		spawnRadius = 10, -- players returning from a run land within this radius
	}),
	floorThickness = 4,
	wallThickness = 2,
})
