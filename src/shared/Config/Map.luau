--!strict
-- Map layout (DESIGN.md section 14, Map 1 "The Ruined City"): lobby platform and arena, built in code by MapService.
-- EnemySim and SpawnDirector read the arena bounds and obstacles through MapService. All values in studs.
-- `lighting` sets the daylight mood and `decor` the dressing (MapService/Decor): only looks, nothing
-- in it changes where players or enemies can walk.

local Stats = require(script.Parent.Stats)

-- Brotato 1.2.0.1 (zones/*/zone_*_data.tres, singletons/utils TILE_SIZE): every zone is 32 x 24 tiles of 64 pixels,
-- 2048 x 1536 pixels. Turned into studs with the same scale as speed, ranges and spawn distances (0.1 studs per
-- pixel, Config.Stats.range.studsPerPoint): 204.8 x 153.6 studs.
local BROTATO_TILE_PIXELS = 64
local BROTATO_ZONE_TILES = { width = 32, height = 24 }

return table.freeze({
	arena = table.freeze({
		center = Vector3.new(0, 100, 0), -- center of the floor surface
		-- Brotato's zone (since 09.11.2026; 160 x 160 from the playtest after Paket 24, 300 before): x is Brotato's
		-- width, z its height. This is the size without map-size effects; a run uses Util/MapRules.size.
		width = BROTATO_ZONE_TILES.width * BROTATO_TILE_PIXELS * Stats.range.studsPerPoint, -- along x
		depth = BROTATO_ZONE_TILES.height * BROTATO_TILE_PIXELS * Stats.range.studsPerPoint, -- along z
		-- Brotato's map-size effect (main.gd): the run's tiles are the zone's tiles x (1 + the sum of every player's
		-- map_size effect / 100), at least minTiles, cut to whole tiles. Explorer +33 %, Old -33 % (character data).
		tiles = table.freeze({
			width = BROTATO_ZONE_TILES.width,
			height = BROTATO_ZONE_TILES.height,
			studs = BROTATO_TILE_PIXELS * Stats.range.studsPerPoint,
			minTiles = 12,
		}),
		wallHeight = 40,
		spawnRadius = 8, -- participants start on a circle of this radius
		-- The open arena leaves room to dodge in every direction.
		obstacles = table.freeze({}) :: { { x: number, z: number, radius: number } },
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

	-- Neutral daylight is set on the server at start (Lighting replicates). enabled = false keeps
	-- whatever Lighting the place file has. Colors are { red, green, blue } 0..255.
	lighting = table.freeze({
		enabled = true,
		-- Flat 2D light since Paket 25: no sun, no shadows, no reflections, so floor pictures show their exact colors.
		clockTime = 14.5,
		brightness = 0,
		ambient = { 255, 255, 255 },
		outdoorAmbient = { 255, 255, 255 },
		atmosphere = table.freeze({
			density = 0,
			offset = 0,
			color = { 180, 176, 185 },
			decay = { 116, 108, 126 },
			glare = 0,
			haze = 0,
		}),
		colorCorrection = table.freeze({
			contrast = 0,
			saturation = 0,
			tint = { 255, 255, 255 },
		}),
		bloom = table.freeze({ intensity = 0, size = 18, threshold = 2 }),
	}),

	-- The floor picture carries the small stones since Paket 25, so no pebbles on top. The lobby keeps its lamps.
	decor = table.freeze({
		seed = 2112, -- the same scattered pebbles every time
		floorSlabs = 0, -- small pebbles scattered over the arena floor
		lampHeight = 12,
		-- Dark ground around arena and lobby, wide enough that the camera never sees past it; `margin` extends past the wall
		-- and `drop` lowers its top. Colors are { red, green, blue }.
		outskirts = table.freeze({ margin = 110, lobbyMargin = 90, thickness = 4, drop = 0.3, color = { 20, 18, 18 } }),
		motes = table.freeze({ rate = 6, lifetime = { 6, 10 } }), -- graphics setting compatibility
		lobbyLamps = 6, -- around the lobby
	}),
})
