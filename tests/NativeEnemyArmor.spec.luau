--!strict
-- Source Unit armor rounds wave growth, subtracts flat damage and supports explicitly unarmored direct effects.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local Config = require(Shared.Config)
local function actor(wave, growth)
	local world = World.new({
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
	})
	local kind = table.clone(Config.Enemies.types.Shadeling)
	kind.nativeArmor = { base = 0, perWave = growth }
	return world, assert(world:spawn(kind, 0, 0, 100, 1, 1, 1, wave))
end
describe("Native flat enemy armor", function()
	it("rounds original per-wave armor before subtracting rather than applying percent reduction", function()
		local world, id = actor(3, 0.25)
		local _, dealt, applied = world:damage(id, 10)
		expect(dealt).toBe(9)
		expect(applied).toBe(9)
		expect(world:getHealth(id)).toBe(91)
	end)
	it("keeps the source minimum one damage and allows an explicit armor bypass", function()
		local world, id = actor(20, 0.5)
		local _, dealt = world:damage(id, 2)
		expect(dealt).toBe(1)
		local _, direct = world:damage(id, 2, false)
		expect(direct).toBe(2)
		expect(world:getHealth(id)).toBe(97)
	end)
end)
