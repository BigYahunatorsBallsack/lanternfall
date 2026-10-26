-- Unit tests for Util/SpatialHash: queries must return every item a brute-force search finds.

local SpatialHash = require(game:GetService("ReplicatedStorage").Shared.Util.SpatialHash)

local seed = 99
local function random()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

describe("SpatialHash", function()
	it("finds every item within the radius, including negative coordinates and cell borders", function()
		local hash = SpatialHash.new(8)
		local xs, zs = {}, {}
		for i = 1, 300 do
			xs[i], zs[i] = (random() - 0.5) * 300, (random() - 0.5) * 300
			hash:insert(i, xs[i], zs[i])
		end
		-- exactly on cell borders
		xs[301], zs[301] = 16, -8
		hash:insert(301, 16, -8)
		local out = {}
		for _ = 1, 200 do
			local x, z, radius = (random() - 0.5) * 300, (random() - 0.5) * 300, random() * 25
			local found = hash:query(x, z, radius, out)
			local candidates = {}
			for k = 1, found do
				candidates[out[k]] = true
			end
			for i = 1, 301 do
				if (xs[i] - x) ^ 2 + (zs[i] - z) ^ 2 <= radius * radius then
					expect(candidates[i]).toBe(true)
				end
			end
		end
		local found = hash:query(16, -8, 0, out)
		local seen = false
		for k = 1, found do
			seen = seen or out[k] == 301
		end
		expect(seen).toBe(true)
	end)

	it("forgets everything on clear and can be refilled", function()
		local hash = SpatialHash.new(8)
		hash:insert(1, 0, 0)
		hash:insert(2, 3, 3)
		hash:clear()
		expect(hash:query(0, 0, 50, {})).toBe(0)
		hash:insert(3, 1, 1)
		local out = {}
		expect(hash:query(0, 0, 5, out)).toBe(1)
		expect(out[1]).toBe(3)
	end)
end)
