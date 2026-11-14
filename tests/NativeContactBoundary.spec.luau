--!strict
-- Original Area2D overlap has no gameplay padding: actual World contact and rush paths must miss disjoint circles.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config)
local Kinds = require(Shared.Util.EnemyKinds)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local function make()
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
		obstacles = {},
	})
end
describe("Native contact boundary", function()
	it("misses disjoint circles just beyond their summed radii and hits inside", function()
		local w = make()
		local kind = table.clone(assert(Kinds.get("BabyTriceratops")))
		kind.hitRadius = 1
		assert(w:spawn(kind, 0, 0, 1000, 7, nil, 0))
		w:step(0, { 80 }, { 0 }, 1, { 3.25 }, { 0 })
		expect(w.contacts[1]).toBe(0)
		w:step(0, { 80 }, { 0 }, 1, { 3.05 }, { 0 })
		expect(w.contacts[1]).toBe(7)
	end)
	it("uses a supplied faction hurt radius without padding", function()
		local w = make()
		local kind = table.clone(assert(Kinds.get("BabyTriceratops")))
		kind.hitRadius = 1
		assert(w:spawn(kind, 0, 0, 1000, 7, nil, 0))
		w:step(0, { 80 }, { 0 }, 1, { 1.65 }, { 0 }, { 0.5 })
		expect(w.contacts[1]).toBe(0)
		w:step(0, { 80 }, { 0 }, 1, { 1.45 }, { 0 }, { 0.5 })
		expect(w.contacts[1]).toBe(7)
	end)
	it("does not widen a fast swept charge path beyond the actual circles", function()
		for _, entry in { { 3.25, 0 }, { 3.05, 7 } } do
			local w = make()
			local kind = table.clone(assert(Kinds.get("Triceratops")))
			kind.radius, kind.hurtRadius, kind.hitRadius = 0.1, 0.1, 1
			kind.nativeBodyOffsetX, kind.nativeBodyOffsetZ = 0, 0
			kind.nativeHitOffsetX, kind.nativeHitOffsetZ = 0, 0
			kind.speed, kind.speedMax = 0, 0
			kind.nativeCharge = table.clone(kind.nativeCharge)
			kind.nativeCharge.speed = 100
			local id = assert(w:spawn(kind, -20, 0, 1000, 7, nil, 1))
			w.nativeCharges[w.indexOf[id]].remaining = 0
			w:step(0, { 80 }, { 0 }, 1, { 0 }, { entry[1] })
			w:step(kind.nativeCharge.fireAt, { 80 }, { 0 }, 1, { 0 }, { entry[1] })
			w:step(0.4, { 80 }, { 0 }, 1, { 0 }, { entry[1] })
			expect(w.contacts[1]).toBe(entry[2])
		end
	end)
end)
