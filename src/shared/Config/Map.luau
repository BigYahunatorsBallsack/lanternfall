--!strict
-- Map layout (DESIGN.md section 14, Map 1 "The Ruined City"): lobby platform and arena, built in code by MapService.
-- EnemySim and SpawnDirector read the arena bounds and obstacles through MapService. All values in studs.
-- Since Paket 21 `lighting` sets the evening mood and `decor` the dressing (MapService/Decor): only looks, nothing
-- in it changes where players or enemies can walk.

return table.freeze({
	arena = table.freeze({
		center = Vector3.new(0, 100, 0), -- center of the floor surface
		-- 300 until the playtest after Paket 24; now about Brotato's arena: a bit more than one screen wide (the camera
		-- shows about 130 x 95 studs), so enemies stay close and walking away does not solve every wave
		size = 160, -- side length of the square arena
		wallHeight = 40,
		spawnRadius = 8, -- participants start on a circle of this radius
		-- Placeholder ruins: round pillars that enemies walk around (circles for EnemySim).
		-- x/z are offsets from the arena center (halved with the smaller arena).
		obstacles = table.freeze({
			table.freeze({ x = 0, z = 22, radius = 3 }),
			table.freeze({ x = -38, z = -28, radius = 5 }),
			table.freeze({ x = 36, z = -40, radius = 4 }),
			table.freeze({ x = -34, z = 40, radius = 4.5 }),
			table.freeze({ x = 42, z = 32, radius = 6 }),
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

	-- Paket 21: dusk over the ruins. Set on the server at start (Lighting replicates). enabled = false keeps
	-- whatever Lighting the place file has. Colors are { red, green, blue } 0..255.
	lighting = table.freeze({
		enabled = true,
		clockTime = 18.3, -- low warm sun, long shadows
		brightness = 2,
		ambient = { 58, 48, 78 },
		outdoorAmbient = { 92, 78, 112 },
		atmosphere = table.freeze({
			density = 0.28,
			offset = 0.15,
			color = { 150, 120, 170 },
			decay = { 92, 60, 110 },
			glare = 0.15,
			haze = 1.2,
		}),
		colorCorrection = table.freeze({
			contrast = 0.08,
			saturation = 0.08,
			tint = { 255, 244, 232 },
		}),
		bloom = table.freeze({ intensity = 0.35, size = 24, threshold = 1.8 }),
	}),

	-- Paket 21: the dressing. Everything inside the arena is flat and walk-through; lamps and ruins stand outside the
	-- fog wall. Lights are few and cast no shadows (phones, Paket 22).
	decor = table.freeze({
		seed = 2112, -- the same scattered slabs and ruins every time
		sunburstRays = 16, -- brass rays around the start circle
		sunburstLength = 26,
		floorSlabs = 16, -- cracked lighter slabs scattered over the arena floor
		lampsPerSide = 3, -- lamp posts outside each arena wall
		lampDistance = 7, -- from the wall
		lampHeight = 12,
		lampLightRange = 26,
		backdropRuins = 18, -- broken walls and blocks beyond the fog wall
		backdropDepth = { 10, 45 }, -- how far beyond the wall
		obelisks = true, -- a glowing obelisk at each arena corner
		motes = table.freeze({ rate = 6, lifetime = { 6, 10 } }), -- floating embers over the arena, per second
		lobbyLamps = 6, -- around the lobby
	}),
})
