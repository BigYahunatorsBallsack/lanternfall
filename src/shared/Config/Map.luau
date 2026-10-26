--!strict
-- Placeholder map layout (DESIGN.md section 14): lobby platform and arena, built in code by MapService
-- until the real map arrives in WP21. EnemySim (WP3) reads the arena bounds. All values in studs.

return table.freeze({
	arena = table.freeze({
		center = Vector3.new(0, 100, 0), -- center of the floor surface
		size = 300, -- side length of the square arena
		wallHeight = 40,
		spawnRadius = 8, -- participants start on a circle of this radius
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
