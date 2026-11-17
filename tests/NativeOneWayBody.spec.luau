--!strict
-- Source one-way circle contact policy, including direction, penetration and obstacle motion allowance.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Body = require(Shared.Util.NativeBodyGeometry)
local C = require(Shared.Config)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local function world()
	local s = C.Simulation
	return World.new({
		cellSize = s.spatialHashCellSize,
		maxEnemies = 140,
		playerRadius = s.playerRadius,
		contactMargin = 0,
		separationStiffness = s.separationStiffness,
		separationPasses = s.separationPasses,
		obstacleSteerMargin = s.obstacleSteerMargin,
		keepDistanceTolerance = s.keepDistanceTolerance,
		minX = -100,
		maxX = 100,
		minZ = -100,
		maxZ = 100,
		obstacles = {},
		seed = 1,
	})
end
local function body(oneWay)
	local k = table.clone(C.Enemies.types.Shadeling)
	k.radius, k.speed, k.speedMax = 3, 10, 10
	k.nativeBodyLayer, k.nativeBodyMask = 4, 4
	if oneWay then
		k.nativeBodyOneWay = { axisX = 0, axisZ = 1, margin = 0.1 }
	end
	return k
end
describe("Native one-way body contacts", function()
	it("retains ordinary contacts and accepts only the blocking side of a one-way circle", function()
		expect(Body.blocks({}, 0, 1, 0, 0, 0, 0)).toBe(true)
		local rule = { nativeBodyOneWay = { axisX = 0, axisZ = 1, margin = 0.1 } }
		expect(Body.blocks(rule, 0, -1, 0, 0, 0, 0)).toBe(true)
		expect(Body.blocks(rule, 0, 1, 0, 0, 0, 0)).toBe(false)
		expect(Body.blocks(rule, 1, 0, 0, 0, 0, 0)).toBe(false)
	end)
	it("rotates the blocking axis with the owner instead of the approaching body", function()
		local rule = { nativeBodyOneWay = { axisX = -1, axisZ = 0, margin = 0.1 } }
		expect(Body.blocks(rule, 1, 0, 0, 0, 0, 0)).toBe(true)
		expect(Body.blocks(rule, -1, 0, 0, 0, 0, 0)).toBe(false)
	end)
	it("rejects deep recovery contacts and grows the margin only by owner movement against the axis", function()
		local rule = { nativeBodyOneWay = { axisX = 0, axisZ = 1, margin = 0.1 } }
		expect(Body.blocks(rule, 0, -1, 0.1, 0, 0, 1)).toBe(true)
		expect(Body.blocks(rule, 0, -1, 0.10001, 0, 0, 1)).toBe(false)
		expect(Body.blocks(rule, 0, -1, 0.3, 0, -2, 0.1)).toBe(true)
		expect(Body.blocks(rule, 0, -1, 0.3, 0, 2, 0.1)).toBe(false)
	end)
	it("uses the source epsilon for nearly tangent normalized contacts", function()
		local rule = { nativeBodyOneWay = { axisX = 0, axisZ = 1, margin = 0.1 } }
		expect(Body.blocks(rule, 1, -0.000001, 0, 0, 0, 0)).toBe(false)
		expect(Body.blocks(rule, 1, -0.00002, 0, 0, 0, 0)).toBe(true)
	end)
	it("keeps the Unit.test_motion minimum margin when the shape has a smaller one", function()
		local rule = { nativeBodyOneWay = { axisX = 0, axisZ = 1, margin = 0 } }
		expect(Body.blocks(rule, 0, -1, 0.008, 0, 0, 0)).toBe(true)
		expect(Body.blocks(rule, 0, -1, 0.00801, 0, 0, 0)).toBe(false)
	end)
	it("separates only the blocking side of an anchored one-way body in either spawn order", function()
		for _, reverse in { false, true } do
			for _, side in { -1, 1 } do
				local w = world()
				local platform = body(true)
				platform.anchored = true
				local mover
				if reverse then
					mover = assert(w:spawn(body(false), 0, side * 5.95, 100, 0))
					w:spawn(platform, 0, 0, 100, 0)
				else
					w:spawn(platform, 0, 0, 100, 0)
					mover = assert(w:spawn(body(false), 0, side * 5.95, 100, 0))
				end
				w:step(0, {}, {}, 0)
				local _, z = w:getPosition(mover)
				if side < 0 then
					expect(z < -5.95).toBe(true)
				else
					expect(z).toBeNear(5.95)
				end
			end
		end
	end)
	it("lets a mover pass from the back but yields approaching the front", function()
		for _, side in { -1, 1 } do
			local w = world()
			local platform = body(true)
			platform.anchored = true
			w:spawn(platform, 0, 0, 100, 0)
			local mover = assert(w:spawn(body(false), 0, side * 6.1, 100, 0))
			w:step(0.1, { 0 }, { -side * 80 }, 1)
			local _, z = w:getPosition(mover)
			if side < 0 then
				expect(z <= -6).toBe(true)
			else
				expect(z).toBeNear(5.1)
			end
		end
	end)
end)
