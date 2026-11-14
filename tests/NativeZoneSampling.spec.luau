--!strict
-- Native ZoneService sampling distinguishes forbidden circles from physical hole capsules and preserves retry/fallback rules.
local Shared = game:GetService("ReplicatedStorage").Shared
local Zone = require(Shared.Util.NativeZoneSampling)
local bounds = { minX = 0, maxX = 100, minZ = 0, maxZ = 100 }
describe("Native zone sampling", function()
	it("tries five square candidates then pushes the center outside forbidden circles without reclamping", function()
		local calls = 0
		local x, z = Zone.inArea(function()
			calls += 1
			return 0.5
		end, bounds, 50, 50, 20, { { x = 50, z = 50, radius = 100 } })
		expect(calls).toBe(10)
		expect(x).toBeNear(150.8)
		expect(z).toBeNear(50)
	end)
	it("limits the default edge margin to a truncated twenty percent of the smaller side", function()
		local x, z = Zone.inArea(function()
			return 0.5
		end, { minX = 0, maxX = 100, minZ = 0, maxZ = 10.09 }, -100, -100, 0, {})
		expect(x).toBeNear(2)
		expect(z).toBeNear(2)
	end)
	it("uses inclusive circle membership and a single sequential push-out pass", function()
		expect(Zone.inForbidden(3, 4, { { x = 0, z = 0, radius = 5 } })).toBe(true)
		local circles = { { x = 0, z = 0, radius = 5 }, { x = 6, z = 0, radius = 5 } }
		local x, z = Zone.pushOut(0, 0, circles)
		expect(x).toBeNear(0.2)
		expect(z).toBeNear(0)
		expect(Zone.inForbidden(x, z, { circles[1] })).toBe(true)
	end)
	it("samples only cells whose centers are valid and rebuilds when circles change", function()
		local grid = Zone.new({ minX = 0, maxX = 12.8, minZ = 0, maxZ = 6.4 }, { { x = 3.2, z = 3.2, radius = 1 } })
		local count = 0
		local function pick(n)
			count = n
			return 1
		end
		local x, z = grid:sample(function()
			return 0.5
		end, pick)
		expect(count).toBe(1)
		expect(x).toBeNear(9.6)
		expect(z).toBeNear(3.2)
		grid:setCircles({})
		x, z = grid:sample(function()
			return 0.5
		end, pick)
		expect(count).toBe(2)
		expect(x).toBeNear(3.2)
		expect(z).toBeNear(3.2)
	end)

	it("retains exactly one sampling cell per original tile across map sizes and translated rectangles", function()
		for _, dims in { { 32, 24 }, { 21, 16 }, { 42, 31 }, { 12, 12 } } do
			local width, depth = dims[1] * 6.4, dims[2] * 6.4
			local grid = Zone.new(
				{ minX = 37 - width / 2, maxX = 37 + width / 2, minZ = -11 - depth / 2, maxZ = -11 + depth / 2 },
				{}
			)
			grid:sample(function()
				return 0.5
			end, function(count)
				expect(count).toBe(dims[1] * dims[2])
				return 1
			end)
		end
	end)
	it("resamples an invalid point three times then uses the already valid cell center", function()
		local grid = Zone.new({ minX = 0, maxX = 6.4, minZ = 0, maxZ = 6.4 }, { { x = 0, z = 0, radius = 1 } })
		local calls = 0
		local x, z = grid:sample(function()
			calls += 1
			return 0
		end, function()
			return 1
		end)
		expect(calls).toBe(8)
		expect(x).toBeNear(3.2)
		expect(z).toBeNear(3.2)
	end)
	it("returns the map center without random draws when all cell centers are forbidden", function()
		local grid = Zone.new({ minX = 0, maxX = 6.4, minZ = 0, maxZ = 6.4 }, { { x = 3.2, z = 3.2, radius = 10 } })
		local function unexpected()
			error("Native empty-cell fallback must not draw randomness")
		end
		local x, z = grid:sample(unexpected, unexpected)
		expect(x).toBeNear(3.2)
		expect(z).toBeNear(3.2)
	end)
	it("routes real native spawning requests through forbidden-area retry rules", function()
		local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
		local Native = require(game:GetService("ServerScriptService").Server.Services.EnemySim.NativeSummons)
		local C = require(Shared.Config)
		local Kinds = require(Shared.Util.EnemyKinds)
		local s = C.Simulation
		local w = World.new({
			cellSize = s.spatialHashCellSize,
			maxEnemies = 140,
			playerRadius = s.playerRadius,
			contactMargin = s.contactMargin,
			separationStiffness = s.separationStiffness,
			separationPasses = s.separationPasses,
			obstacleSteerMargin = s.obstacleSteerMargin,
			keepDistanceTolerance = s.keepDistanceTolerance,
			minX = 0,
			maxX = 100,
			minZ = 0,
			maxZ = 100,
			obstacles = {},
			forbiddenCircles = { { x = 50, z = 50, radius = 100 } },
		})
		local k = assert(Kinds.get("Alamosaurus"))
		local id = assert(w:spawn(k, 50, 50, 1000, 0, nil, 0))
		local count = 0
		Native.emit(w, id, k.nativeSpawn, nil, function()
			return 0.5
		end, function(child, x, z)
			expect(child).toBe("DinoEgg")
			expect(x).toBeNear(150.8)
			expect(z).toBeNear(50)
			count += 1
		end)
		expect(count).toBe(3)
	end)
end)
