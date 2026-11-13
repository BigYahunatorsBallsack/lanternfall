--!strict
-- Native body centers differ from actor origins; World push, sweeps and crowd constraints retain source offsets.
local Shared = game:GetService("ReplicatedStorage").Shared
local Shapes = require(Shared.Util.StaticShapes)
local C = require(Shared.Config)
local Source = require(Shared.Config.JungleHoles)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local Kinds = require(Shared.Util.EnemyKinds)
local p = Source.physical
local pixel = C.Stats.range.studsPerPoint
local hole =
	{ x = 0, z = 0, radius = p.radiusPoints * pixel, halfLength = p.halfLengthPoints * pixel, axisX = 1, axisZ = 0 }
local function make(obstacles)
	local s = C.Simulation
	return World.new({
		cellSize = s.spatialHashCellSize,
		maxEnemies = 140,
		playerRadius = s.playerRadius,
		contactMargin = s.contactMargin,
		separationStiffness = s.separationStiffness,
		separationPasses = s.separationPasses,
		obstacleSteerMargin = s.obstacleSteerMargin,
		keepDistanceTolerance = s.keepDistanceTolerance,
		minX = -100,
		maxX = 100,
		minZ = -100,
		maxZ = 100,
		obstacles = obstacles,
	})
end
describe("Native physical body offsets", function()
	it("restores origin-hash queries for legacy hurt geometry after body-center separation", function()
		local w = make({})
		local k = table.clone(assert(Kinds.get("Shadeling")))
		k.radius, k.hurtRadius, k.hitRadius, k.nativeBodyOffsetZ = 1, 20, 0, -10
		local id = assert(w:spawn(k, 0, 0, 1000, 0, nil, 0))
		w:step(0, {}, {}, 0)
		local found = {}
		expect(w:queryRadius(0, 20, 0, found)).toBe(1)
		expect(found[1]).toBe(id)
		expect(w:querySegment(-1, 20, 1, 20, 0, found)).toBe(1)
		expect(found[1]).toBe(id)
	end)
	it("steers ordinary movement using the shifted body rather than a clear origin path", function()
		local w = make({ { x = 0, z = 0, radius = 2 } })
		local k = table.clone(assert(Kinds.get("BabyTriceratops")))
		k.radius, k.speed, k.speedMax = 1, 10, 10
		k.nativeBodyOffsetZ = -4
		local id = assert(w:spawn(k, -4.5, 5, 1000, 0, nil, 1))
		w:step(0.1, { 30 }, { 5 }, 1)
		local _, z = w:getPosition(id)
		expect(z > 5.5).toBe(true)
	end)
	it("gives way to a heavier shifted body before touching it", function()
		local w = make({})
		w.params.separationPasses = 0
		local a = table.clone(assert(Kinds.get("Shadeling")))
		local b = table.clone(assert(Kinds.get("BabyTriceratops")))
		a.radius, a.hitRadius, a.speed, a.speedMax, a.mass = 1, 1, 10, 10, 1
		b.radius, b.mass, b.nativeBodyOffsetZ = 1, 100, -30
		local first = assert(w:spawn(a, 0, 0, 1000, 0, nil, 1))
		assert(w:spawn(b, 3, 30, 1000, 0, nil, 0))
		w:step(0.5, { 30 }, { 0 }, 1)
		expect(w:getPosition(first)).toBeNear(1)
	end)
	it("loads source body offsets without changing actor positions or legacy kinds", function()
		local k = assert(Kinds.get("BabyTriceratops"))
		expect(k.nativeBodyOffsetX).toBeNear(0)
		expect(k.nativeBodyOffsetZ).toBeNear(-0.3)
		expect(Kinds.get("Brute").nativeBodyOffsetZ).toBe(nil)
		local w = make({})
		local id = assert(w:spawn(k, 10, 20, 1000, 0, nil, 0))
		local x, z = w:getPosition(id)
		expect(x).toBe(10)
		expect(z).toBe(20)
	end)
	it("pushes the original body circle rather than the actor origin out of a round obstacle", function()
		local w = make({ { x = 0, z = 0, radius = 1 } })
		local k = assert(Kinds.get("BabyTriceratops"))
		local id = assert(w:spawn(k, 0, 3.3, 1000, 0, nil, 0))
		w:push(id, 0, 0)
		local x, z = w:getPosition(id)
		expect(x).toBeNear(0)
		expect(z).toBeNear(3.5)
	end)
	it("uses the same shifted body in final capsule constraints", function()
		local w = make({ hole })
		local k = assert(Kinds.get("BabyTriceratops"))
		local id = assert(w:spawn(k, 0, 9.3, 1000, 0, nil, 0))
		w:step(0, {}, {}, 0)
		local _, z = w:getPosition(id)
		expect(z).toBeNear(9.5)
	end)
	it("sweeps shifted body circles during native timed charges", function()
		for _, shape in
			{ { x = 0, z = 0, radius = 2 }, { x = 0, z = 0, radius = 2, halfLength = 3.5, axisX = 1, axisZ = 0 } }
		do
			local w = make({ shape })
			local k = table.clone(assert(Kinds.get("Triceratops")))
			k.radius, k.hurtRadius, k.hitRadius = 1, 1, 0
			k.nativeBodyOffsetX, k.nativeBodyOffsetZ = 0, -4
			k.speed, k.speedMax = 0, 0
			k.nativeCharge = table.clone(k.nativeCharge)
			k.nativeCharge.speed = 100
			local id = assert(w:spawn(k, -20, 5, 1000, 0, nil, 1))
			w.nativeCharges[w.indexOf[id]].remaining = 0
			w:step(0, { 80 }, { 5 }, 1)
			w:step(k.nativeCharge.fireAt + 0.4, { 80 }, { 5 }, 1)
			local x, z = w:getPosition(id)
			expect(x).toBeNear(-math.sqrt(8) - (shape.halfLength or 0))
			expect(z).toBeNear(5)
			expect(w.modes[w.indexOf[id]]).toBe(World.MODE_RUSH)
		end
	end)
	it("does not separate coincident origins whose physical bodies do not overlap", function()
		local w = make({})
		local a = table.clone(assert(Kinds.get("Brute")))
		local b = table.clone(assert(Kinds.get("BabyTriceratops")))
		a.radius, b.radius = 1, 1
		b.nativeBodyOffsetZ = -10
		local first = assert(w:spawn(a, 0, 0, 1000, 0, nil, 0))
		local second = assert(w:spawn(b, 0, 0, 1000, 0, nil, 0))
		w:step(0, {}, {}, 0)
		local x, z = w:getPosition(first)
		expect(x).toBeNear(0)
		expect(z).toBeNear(0)
		x, z = w:getPosition(second)
		expect(x).toBeNear(0)
		expect(z).toBeNear(0)
	end)
	it("includes far actor origins in broad-phase searches when their shifted bodies overlap", function()
		local w = make({})
		local a = table.clone(assert(Kinds.get("Brute")))
		local b = table.clone(assert(Kinds.get("BabyTriceratops")))
		a.radius, a.hurtRadius, a.hitRadius = 1, 1, 0
		b.radius, b.hurtRadius, b.hitRadius = 1, 1, 0
		b.nativeBodyOffsetZ = -10
		local first = assert(w:spawn(a, 0, 0, 1000, 0, nil, 0))
		local second = assert(w:spawn(b, 0, 10, 1000, 0, nil, 0))
		w:step(0, {}, {}, 0)
		local ax, az = w:getPosition(first)
		local bx, bz = w:getPosition(second)
		expect((ax - bx) ^ 2 + (az - (bz - 10)) ^ 2 > 1).toBe(true)
	end)
	it("retains a fixed local Collision position while Baby T-Rex grows its shape", function()
		local w = make({})
		local k = assert(Kinds.get("BabyTrex"))
		expect(type(k.nativeBodyOffsetZ)).toBe("number")
		local id = assert(w:spawn(k, 0, 0, 1000, 0, nil, 0))
		w:step(1.1, {}, {}, 0)
		local grown = w.kinds[w.indexOf[id]]
		expect(grown.radius > k.radius).toBe(true)
		expect(grown.nativeBodyOffsetZ).toBe(k.nativeBodyOffsetZ)
	end)
end)
