--!strict
-- Uniform grid over the x/z plane for neighbour and hit queries (DESIGN.md section 15, cell size from
-- Config.Simulation). Used by EnemySim's World. Items are plain numbers (array indices); the grid is
-- rebuilt every step with clear() and insert(), and buckets are reused so rebuilding makes no garbage.

local SpatialHash = {}
SpatialHash.__index = SpatialHash

export type SpatialHash = typeof(setmetatable(
	{} :: {
		inverseCellSize: number,
		cells: { [number]: { number } },
		used: { number }, -- keys of the cells that hold items
	},
	SpatialHash
))

-- Cell coordinates must stay within +-32767, i.e. positions within +-32767 cells of the origin.
local ROW = 65536

local function cellKey(cx: number, cz: number): number
	return cx * ROW + cz
end

function SpatialHash.new(cellSize: number): SpatialHash
	assert(cellSize > 0, "cellSize must be positive")
	return setmetatable({ inverseCellSize = 1 / cellSize, cells = {}, used = {} }, SpatialHash)
end

function SpatialHash.clear(self: SpatialHash)
	local cells = self.cells
	for _, key in self.used do
		table.clear(cells[key])
	end
	table.clear(self.used)
end

function SpatialHash.insert(self: SpatialHash, item: number, x: number, z: number)
	local inverse = self.inverseCellSize
	local key = cellKey(math.floor(x * inverse), math.floor(z * inverse))
	local bucket = self.cells[key]
	if not bucket then
		bucket = {}
		self.cells[key] = bucket
	end
	if #bucket == 0 then
		table.insert(self.used, key)
	end
	table.insert(bucket, item)
end

-- Writes every item in the cells touched by the square around (x, z) with half size `radius` into
-- out[1 .. n] and returns n. These are candidates: callers check the exact distance themselves.
function SpatialHash.query(self: SpatialHash, x: number, z: number, radius: number, out: { number }): number
	local inverse = self.inverseCellSize
	local minX, maxX = math.floor((x - radius) * inverse), math.floor((x + radius) * inverse)
	local minZ, maxZ = math.floor((z - radius) * inverse), math.floor((z + radius) * inverse)
	local cells = self.cells
	local count = 0
	for cx = minX, maxX do
		local row = cx * ROW
		for cz = minZ, maxZ do
			local bucket = cells[row + cz]
			if bucket then
				for _, item in bucket do
					count += 1
					out[count] = item
				end
			end
		end
	end
	return count
end

return SpatialHash
