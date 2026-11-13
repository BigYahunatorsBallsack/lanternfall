--!strict
-- Native hole capsules retain their center segment; exact circle/capsule collision is exercised through production World movement.
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
describe("Native capsule obstacles", function()
	it("keeps the native210 by140 pixel capsule distinct from the260-pixel forbidden circle", function()
		expect(hole.radius).toBeNear(7)
		expect(hole.halfLength).toBeNear(3.5)
		expect(Source.forbiddenRadiusPoints * pixel).toBeNear(13)
		expect(Shapes.contains(10, 0, hole, 0)).toBe(true)
		expect(Shapes.contains(0, 8, hole, 0)).toBe(false)
		expect(Shapes.contains(10, 7, hole, 0)).toBe(false)
	end)
	it("finds the first swept hit on flat sides, round ends and rotated capsules", function()
		expect(Shapes.entry(-20, 0, 1, 0, 50, hole, 1)).toBeNear(8.5)
		expect(Shapes.entry(0, -20, 0, 1, 50, hole, 1)).toBeNear(12)
		expect(Shapes.entry(8, -20, 0, 1, 50, hole, 1)).toBeNear(20 - math.sqrt(64 - 4.5 ^ 2))
		expect(Shapes.entry(20, 20, 1, 0, 10, hole, 1)).toBe(nil)
		local rotated = table.clone(hole)
		rotated.axisX = 0
		rotated.axisZ = 1
		expect(Shapes.entry(0, -20, 0, 1, 50, rotated, 1)).toBeNear(8.5)
		rotated.axisX = math.sqrt(0.5)
		rotated.axisZ = math.sqrt(0.5)
		expect(Shapes.entry(-20 * rotated.axisX, -20 * rotated.axisZ, rotated.axisX, rotated.axisZ, 50, rotated, 1)).toBeNear(
			8.5
		)
	end)
	it("pushes body circles onto the nearest capsule boundary including exact center-line starts", function()
		local x, z = Shapes.pushOut(0, 0, hole, 1, 2)
		expect(x).toBeNear(0)
		expect(math.abs(z)).toBeNear(8)
		x, z = Shapes.pushOut(10, 0, hole, 1, 2)
		expect(x).toBeNear(11.5)
		expect(z).toBeNear(0)
	end)
	it("uses capsule collision for real World push and fast charger sweeps", function()
		local w = make({ hole })
		local kind = table.clone(assert(Kinds.get("Brute")))
		kind.radius = 1
		kind.hurtRadius = 1
		kind.hitRadius = 1
		local id = assert(w:spawn(kind, 0, 0, 1000, 0, nil, 0))
		w:push(id, 0, 0)
		local x, z = w:getPosition(id)
		expect(math.abs(z)).toBeNear(8)
		local charge = table.clone(assert(Kinds.get("Charger")))
		charge.radius = 1
		charge.hurtRadius = 1
		charge.hitRadius = 1
		charge.charge = table.clone(charge.charge)
		charge.charge.speed = 100
		charge.charge.maxDistance = 100
		local rush = assert(w:spawn(charge, -20, 0, 1000, 0))
		local i = w.indexOf[rush]
		w.modes[i] = World.MODE_RUSH
		w.rushXs[i] = 1
		w.rushZs[i] = 0
		w.rushLeft[i] = 100
		w:step(0.5, { 80 }, { 0 }, 1)
		x, z = w:getPosition(rush)
		expect(x).toBeNear(-11.5)
		expect(z).toBeNear(0)
	end)

	it(
		"lets an ordinary production enemy steer around a capsule instead of remaining trapped at its round end",
		function()
			local w = make({ hole })
			local kind = table.clone(assert(Kinds.get("Brute")))
			kind.radius = 1
			kind.hurtRadius = 1
			kind.hitRadius = 1
			kind.speed = 10
			kind.speedMax = 10
			local id = assert(w:spawn(kind, -20, 0, 1000, 0))
			for _ = 1, 100 do
				w:step(0.1, { 25 }, { 0 }, 1)
			end
			local x = w:getPosition(id)
			expect(x > 12).toBe(true)
		end
	)

	it(
		"uses original body masks for flying enemies and enables obstacle collision after real Charm transfer",
		function()
			local w = make({ hole })
			local kind = table.clone(assert(Kinds.get("BabyPterosaur")))
			expect(kind.nativeObstacleCollision).toBe(false)
			kind.radius = 1
			kind.hurtRadius = 1
			kind.hitRadius = 1
			kind.speed = 10
			kind.speedMax = 10
			local id = assert(w:spawn(kind, -20, 0, 1000, 0))
			for _ = 1, 16 do
				w:step(0.1, { 25 }, { 0 }, 1)
			end
			local x, z = w:getPosition(id)
			expect(Shapes.contains(x, z, hole, 1)).toBe(true)
			local Friends = require(game:GetService("ServerScriptService").Server.Services.EnemySim.CharmedWorld)
			local friends = Friends.new(w.params, {})
			expect(friends:convert(w, id, 1, 0, { contact = 0, shot = 0 })).toBe(true)
			expect(friends.world:getKind(id).nativeObstacleCollision).toBe(true)
			friends.world:step(0, { 25 }, { 0 }, 1)
			x, z = friends.world:getPosition(id)
			local cx, cz = Shapes.closest(x, z, hole)
			expect(math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2) >= 8 - 1e-6).toBe(true)
		end
	)
	it("preserves existing circle geometry through the shared entry helper", function()
		local circle = { x = 2, z = 0, radius = 3 }
		expect(Shapes.entry(-10, 0, 1, 0, 30, circle, 1)).toBeNear(8)
		local x, z = Shapes.closest(8, 9, circle)
		expect(x).toBe(2)
		expect(z).toBe(0)
	end)
end)
