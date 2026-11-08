--!strict
-- Native additive speed acts in the actual dense world and cleans up by id after compaction/reset.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local Sim = Config.Simulation
local HALF = 1000
local function newWorld(obstacles)
	return World.new({
		cellSize = Sim.spatialHashCellSize,
		maxEnemies = Config.Run.spawn.cap.max,
		playerRadius = Sim.playerRadius,
		contactMargin = Sim.contactMargin,
		separationStiffness = Sim.separationStiffness,
		separationPasses = Sim.separationPasses,
		obstacleSteerMargin = Sim.obstacleSteerMargin,
		keepDistanceTolerance = Sim.keepDistanceTolerance,
		minX = -HALF,
		maxX = HALF,
		minZ = -HALF,
		maxZ = HALF,
		obstacles = obstacles or {},
	})
end

describe("Native decaying speed in World", function()
	it("slows real movement and marks snapshot status", function()
		local w = newWorld()
		local kind = table.clone(Config.Enemies.types.Shadeling)
		kind.speed = 100
		local id = assert(w:spawn(kind, 0, 0, 10000, 0))
		w:nativeSlow(id, -50, true, 2)
		w:step(0.1, { 400 }, { 0 }, 1, {}, {})
		local x = w:getPosition(id)
		expect(x).toBeNear(5)
		local slowed = w:getStatus(id)
		expect(slowed).toBe(true)
	end)
	it("clears per-id effects when a target is removed and when a world is reset", function()
		local w = newWorld()
		local kind = Config.Enemies.types.Shadeling
		local id = assert(w:spawn(kind, 0, 0, 10000, 0))
		w:nativeSlow(id, -400, false, 0)
		w:remove(id)
		expect(w.nativeSlows:active(id)).toBe(false)
		local other = assert(w:spawn(kind, 50, 0, 10000, 0))
		w:nativeSlow(other, -400, false, 0)
		w:clear()
		expect(w.nativeSlows:active(other)).toBe(false)
	end)
end)
