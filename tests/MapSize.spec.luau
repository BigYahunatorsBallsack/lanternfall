-- Brotato's arena size (zone 32 x 24 tiles of 64 px) and its map-size effect (Explorer +33 %, Old -33 %, at least 12
-- tiles): Util/MapRules, MapService.setArenaMapSize (walls, floor, bounds, ArenaResized) and the character data.

local world = loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local CharacterRules = require(ReplicatedStorage.Shared.Util.CharacterRules)
local MapRules = require(ReplicatedStorage.Shared.Util.MapRules)

runScript(ServerScriptService.Server, "init.server.luau")
local MapService = require(ServerScriptService.Server.Services.MapService)
world.step()

local function arenaPart(name: string): any
	return workspace:FindFirstChild("LanternfallMap"):FindFirstChild("Arena"):FindFirstChild(name)
end

describe("arena size", function()
	it("is Brotato's zone: 2048 x 1536 px at 0.1 studs per pixel", function()
		expect(Config.Map.arena.width).toBeNear(204.8, 1e-6)
		expect(Config.Map.arena.depth).toBeNear(153.6, 1e-6)
		local width, depth = MapRules.size(0)
		expect(width).toBeNear(204.8, 1e-6)
		expect(depth).toBeNear(153.6, 1e-6)
	end)

	it("grows and shrinks in whole tiles with the map-size effect, at least 12 tiles", function()
		local width, depth = MapRules.size(33) -- Explorer: int(32 * 1.33) = 42, int(24 * 1.33) = 31
		expect(width).toBeNear(42 * 6.4, 1e-6)
		expect(depth).toBeNear(31 * 6.4, 1e-6)
		width, depth = MapRules.size(-33) -- Old: int(32 * 0.67) = 21, int(24 * 0.67) = 16
		expect(width).toBeNear(21 * 6.4, 1e-6)
		expect(depth).toBeNear(16 * 6.4, 1e-6)
		width, depth = MapRules.size(-99)
		expect(width).toBeNear(12 * 6.4, 1e-6)
		expect(depth).toBeNear(12 * 6.4, 1e-6)
	end)

	it("reads the map-size effect of Explorer and Old from the character data", function()
		expect(CharacterRules.nativeAmount("Explorer", "map_size")).toBe(33)
		expect(CharacterRules.nativeAmount("Old", "map_size")).toBe(-33)
		expect(CharacterRules.nativeAmount("SparkMage", "map_size")).toBe(0)
	end)

	it("builds the arena at its normal size", function()
		expect(arenaPart("Floor").Size.X).toBeNear(204.8, 1e-6)
		expect(arenaPart("Floor").Size.Z).toBeNear(153.6, 1e-6)
		local bounds = MapService.getArenaBounds()
		expect(bounds.halfX).toBeNear(102.4, 1e-6)
		expect(bounds.halfZ).toBeNear(76.8, 1e-6)
	end)

	it("resizes floor, walls and bounds for a run and tells the services", function()
		local told = nil
		local connection = MapService.ArenaResized:Connect(function(bounds)
			told = bounds
		end)
		MapService.setArenaMapSize(33)
		local width, depth = MapRules.size(33)
		expect(arenaPart("Floor").Size.X).toBeNear(width, 1e-6)
		expect(arenaPart("Floor").Size.Z).toBeNear(depth, 1e-6)
		local center = Config.Map.arena.center
		local wall = Config.Map.wallThickness
		expect(arenaPart("WallEast").CFrame.Position.X).toBeNear(center.X + width / 2 + wall / 2, 1e-6)
		expect(arenaPart("WallNorth").CFrame.Position.Z).toBeNear(center.Z - depth / 2 - wall / 2, 1e-6)
		expect(told ~= nil).toBe(true)
		expect(told.halfX).toBeNear(width / 2, 1e-6)
		local inside = center + Vector3.new(width / 2 - 1, 1, 0)
		expect(MapService.isInZone(inside, "Arena")).toBe(true)
		MapService.setArenaMapSize(0)
		expect(MapService.isInZone(inside, "Arena")).toBe(false)
		expect(arenaPart("Floor").Size.X).toBeNear(204.8, 1e-6)
		connection:Disconnect()
	end)
end)
