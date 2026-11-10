--!strict
-- Friendly and hostile worlds share IDs while preserving transferred actors and reporting exact contact ownership.
loadHelper("tests/helpers/RobloxMock.luau")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local S = game:GetService("ServerScriptService").Server.Services.EnemySim
local World = require(S.World)
local function params(allocate)
	local sim = Config.Simulation
	return {
		cellSize = sim.spatialHashCellSize,
		maxEnemies = 140,
		playerRadius = 0.5,
		contactMargin = 0,
		separationStiffness = sim.separationStiffness,
		separationPasses = sim.separationPasses,
		obstacleSteerMargin = sim.obstacleSteerMargin,
		keepDistanceTolerance = sim.keepDistanceTolerance,
		minX = -100,
		maxX = 100,
		minZ = -100,
		maxZ = 100,
		obstacles = {},
		allocateId = allocate,
	}
end
describe("Enemy faction composition", function()
	it("uses the same allocator across worlds and transfers live state without changing the snapshot id", function()
		local serial = 10
		local function allocate()
			serial += 1
			return serial
		end
		local a, b = World.new(params(allocate)), World.new(params(allocate))
		local id = assert(a:spawn(Config.Enemies.types.Shadeling, 4, 5, 100, 12))
		expect(id).toBe(11)
		a:damage(id, 30)
		a:nativeSlow(id, -10, false, 0.5)
		expect(a:transferTo(b, id)).toBe(true)
		expect(a:isAlive(id)).toBe(false)
		expect(b:isAlive(id)).toBe(true)
		local hp, maxHp = b:getHealth(id)
		expect(hp).toBe(70)
		expect(maxHp).toBe(100)
		expect(b.nativeSlows:active(id)).toBe(true)
		local another = assert(a:spawn(Config.Enemies.types.Shadeling, 0, 0, 10, 1))
		expect(another == id).toBe(false)
		a:step(0.1, {}, {}, 0)
		expect(b:isAlive(id)).toBe(true)
	end)
	it("collides against each enemy target's radius and reports the attacking actor id", function()
		local w = World.new(params(nil))
		local kind = table.clone(Config.Enemies.types.Shadeling)
		kind.radius = 0.25
		kind.hitRadius = 1 -- attack circle is distinct from the body
		kind.anchored = true
		local id = assert(w:spawn(kind, 0, 0, 100, 12))
		local contacts = w:step(0.1, { 4 }, { 0 }, 1, nil, nil, { 3 })
		expect(contacts[1]).toBe(12)
		expect(w.contactSources[1]).toBe(id)
		expect(w:step(0.1, { 4 }, { 0 }, 1)[1]).toBe(0)
	end)
end)
