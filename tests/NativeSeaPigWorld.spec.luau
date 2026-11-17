--!strict
-- Registered Sea Pig reuses native edge patrol without live targets and retains its source Buffer exclusion.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local kind = assert(require(Shared.Util.EnemyKinds).get("SeaPig"))
local function world()
	return World.new({
		cellSize = 8,
		maxEnemies = 10,
		playerRadius = 1,
		contactMargin = 0,
		separationStiffness = 0,
		separationPasses = 0,
		obstacleSteerMargin = 0,
		keepDistanceTolerance = 0,
		minX = -100,
		maxX = 100,
		minZ = -100,
		maxZ = 100,
		obstacles = {},
		collideTargets = false,
	})
end
describe("Registered Sea Pig World", function()
	it("patrols the original150pxband without living players and retains its target point", function()
		local w = world()
		local id = assert(w:spawn(kind, 50, 50, 100, 0))
		w:step(0.1, {}, {}, 0)
		local x, z = w:getPosition(id)
		expect((x - 50) ^ 2 + (z - 50) ^ 2 > 0).toBe(true)
		local state = w.nativePatrols[w.indexOf[id]]
		expect(state.edge).toBe(15)
		local tx, tz = state.targetX, state.targetZ
		w:step(0.001, {}, {}, 0)
		expect(state.targetX).toBe(tx)
		expect(state.targetZ).toBe(tz)
	end)
	it("excludes the actual Sea Pig from Buffer candidates while a control body is boosted", function()
		local w = world()
		local id = assert(w:spawn(kind, 0, 0, 100, 0, nil, 0))
		local control = assert(w:spawn(Config.Enemies.types.Shadeling, 10, 0, 100, 0, nil, 0))
		assert(w:spawn(Config.Enemies.types.CorruptedBuffer, 5, 0, 1000, 0, nil, 0))
		w:step(0, { 30 }, { 0 }, 1)
		w:step(0.3, { 30 }, { 0 }, 1)
		expect(select(2, w:getHealth(id))).toBe(100)
		expect(select(2, w:getHealth(control))).toBe(250)
	end)
end)
