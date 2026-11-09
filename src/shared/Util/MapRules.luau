--!strict
-- Arena size rules like Brotato's main.gd (map-size effect). Pure; read by MapService and tests.

local Config = require(script.Parent.Parent.Config)

local MapRules = {}

-- Width (x) and depth (z) in studs for the summed map_size effect of all players, in percent.
function MapRules.size(mapSizePercent: number): (number, number)
	local tiles = Config.Map.arena.tiles
	local factor = 1 + mapSizePercent / 100
	-- Brotato: int(max(MIN_MAP_SIZE, tiles * coef)), the cast cuts towards zero
	local width = math.floor(math.max(tiles.minTiles, tiles.width * factor))
	local depth = math.floor(math.max(tiles.minTiles, tiles.height * factor))
	return width * tiles.studs, depth * tiles.studs
end

return MapRules
