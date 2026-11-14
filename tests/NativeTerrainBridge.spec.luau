--!strict
-- Native hole descriptors feed actor collision and forbidden sampling separately; manual terrain staging never enables a Jungle run.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Terrain = require(f.Shared.Util.JungleTerrain)
local Source = require(f.Shared.Config.JungleHoles)
local Shapes = require(f.Shared.Util.StaticShapes)
local Zone = require(f.Shared.Util.NativeZoneSampling)
local Map = require(f.S.MapService)
local Enemy = require(f.S.EnemySim)
local Kinds = require(f.Shared.Util.EnemyKinds)
local rect = { minX = -102.4, maxX = 102.4, minZ = -76.8, maxZ = 76.8 }
describe("Native terrain bridge", function()
	it("selects exact source layouts by map-size rule without rescaling their coordinates", function()
		local function first(n)
			expect(n).toBe(5)
			return 1
		end
		local data = Terrain.build(2, 4, 0, rect, first)
		expect(#data.bodyShapes).toBe(9)
		expect(#data.forbiddenCircles).toBe(9)
		local native = Source.layouts[data.layoutSource].positionsPoints[1]
		expect(data.bodyShapes[1].x).toBeNear(rect.minX + (native[1] + 1) * 0.1)
		expect(data.bodyShapes[1].z).toBeNear(rect.minZ + (native[2] + 1) * 0.1)
		expect(data.bodyShapes[1].radius).toBeNear(7)
		expect(data.forbiddenCircles[1].radius).toBeNear(13)
		expect(#Terrain.build(2, 10, 33, rect, function(n)
			expect(n).toBe(2)
			return 1
		end).bodyShapes).toBe(14)
		expect(#Terrain.build(2, 16, 66, rect, function(n)
			expect(n).toBe(2)
			return 1
		end).bodyShapes).toBe(6)
	end)
	it("does not choose any layout outside the native hole wave/zone and clears prior state", function()
		local function unexpected()
			error("No layout draw expected")
		end
		expect(#Terrain.build(0, 4, 0, rect, unexpected).bodyShapes).toBe(0)
		expect(#Terrain.build(2, 5, 0, rect, unexpected).bodyShapes).toBe(0)
	end)
	it("updates the real actor world while keeping native forbidden circles out of legacy obstacle lists", function()
		f.start("WatchmanPistol")
		f.Weapons.setPaused(true)
		Map.setMovementCheck(false)
		for _, player in { f.me, f.peer } do
			require(f.S.CombatService).protect(player, 10000)
		end
		local before = #Map.getObstacles()
		Map.setNativeTerrain(2, 4, 0, function()
			return 1
		end)
		local data = Map.getNativeTerrain()
		expect(#Map.getNativeObstacleShapes()).toBe(9)
		expect(#Map.getForbiddenCircles()).toBe(9)
		expect(#Map.getObstacles()).toBe(before)
		local shape = data.bodyShapes[1]
		local id = assert(Enemy.spawn("Brute", shape.x, shape.z, 100, 0, nil, nil, 0))
		f.world.advance(0.1, 1 / 60)
		local at = Enemy.getPosition(id)
		local cx, cz = Shapes.closest(at.X, at.Z, shape)
		expect(math.sqrt((at.X - cx) ^ 2 + (at.Z - cz) ^ 2) >= shape.radius + Kinds.get("Brute").radius - 1e-5).toBe(
			true
		)
		Enemy.remove(id)
		f.world.advance(0.1, 1 / 60)
		local flyer = assert(Enemy.spawn("BabyPterosaur", shape.x, shape.z, 100, 0, nil, nil, 0))
		f.world.advance(0.1, 1 / 60)
		at = Enemy.getPosition(flyer)
		expect(Shapes.contains(at.X, at.Z, shape, 0)).toBe(true)
		local x, z = Map.sampleNativePoint(function()
			return 0.5
		end, function()
			return 1
		end)
		expect(Zone.inForbidden(x, z, Map.getForbiddenCircles())).toBe(false)
		expect(f.Run.getNativeZoneId()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
	it("removes staged native terrain on the next wave, resize and actual run end", function()
		local wave = f.Run.getWave()
		f.nextWave()
		expect(f.Run.getWave()).toBe(wave + 1)
		expect(#Map.getNativeTerrain().bodyShapes).toBe(0)
		Map.setNativeTerrain(2, 4, 0, function()
			return 1
		end)
		Map.setArenaMapSize(33)
		expect(#Map.getNativeTerrain().bodyShapes).toBe(0)
		Map.setNativeTerrain(2, 4, 33, function()
			return 1
		end)
		expect(#Map.getNativeTerrain().bodyShapes).toBe(14)
		f.Run.endRun("Abandoned")
		expect(#Map.getNativeTerrain().bodyShapes).toBe(0)
		expect(#Map.getForbiddenCircles()).toBe(0)
	end)

	it("passes area-group points through forbidden circles but preserves native anywhere-group behavior", function()
		local Rules = require(f.S.SpawnDirector.SpawnRules)
		local group = { edge = false, area = 100, edgeMargin = 0 }
		local bounds = { minX = 0, maxX = 100, minZ = 0, maxZ = 100 }
		local forbidden = { { x = 50, z = 50, radius = 100 } }
		local x, z = Rules.unitPoint(function()
			return 0.5
		end, bounds, group, 50, 50, forbidden)
		expect(x).toBeNear(150.8)
		expect(z).toBeNear(50)
		group.area = -1
		x, z = Rules.unitPoint(function()
			return 0.5
		end, bounds, group, 50, 50, forbidden)
		expect(x).toBeNear(50)
		expect(z).toBeNear(50)
	end)
	it("keeps friendly projectile parameters separate from changing actor capsules", function()
		local World = require(f.S.EnemySim.World)
		local Friends = require(f.S.EnemySim.CharmedWorld)
		local s = f.Config.Simulation
		local params = {
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
			obstacles = { { x = 0, z = 0, radius = 7, halfLength = 3.5, axisX = 1, axisZ = 0 } },
		}
		local hostile = World.new(params)
		local target = assert(hostile:spawn(assert(Kinds.get("Brute")), 20, 0, 1000, 0, nil, 0))
		local damage = 0
		local friends = Friends.new(params, {
			damage = function(id, amount)
				expect(id).toBe(target)
				damage += amount
			end,
		}, {})
		friends.world.params.obstacles = params.obstacles
		friends:fire({ id = 99, owner = 1 }, -20, 0, 1, 0, 100, 80, 0.1, 5)
		friends:step(0.5, 0, hostile)
		expect(damage).toBe(5)
	end)
end)
