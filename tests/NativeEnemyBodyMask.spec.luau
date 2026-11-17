--!strict
-- Native Godot body-pair masks use either object's scan; World applies them to steering and separation.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Body = require(Shared.Util.NativeBodyGeometry)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local function actor(mask)
	local k = table.clone(Config.Enemies.types.Shadeling)
	k.radius, k.speed, k.speedMax = 3, 10, 10
	k.nativeBodyLayer, k.nativeBodyMask = 4, mask
	return k
end
local function world()
	local s = Config.Simulation
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
		seed = 1,
	})
end
describe("Native enemy body masks", function()
	it("connects approved source masks for every active Jungle body", function()
		local facts = require(Shared.Config.JungleWalkers)
		for _, name in facts.implemented do
			local kind = assert(Config.Enemies.types[name])
			expect(kind.nativeBodyLayer).toBe(facts.enemies[name].bodyLayer)
			expect(kind.nativeBodyMask).toBe(facts.enemies[name].bodyMask)
		end
		for _, name in facts.sourceOnly do
			expect(facts.enemies[name].bodyLayer).toBe(4)
			expect(facts.enemies[name].bodyMask).toBe(0)
			expect(Config.Enemies.types[name]).toBe(nil)
		end
	end)
	it("uses either mask/layer intersection, including a zero-mask body seen by its neighbor", function()
		local passive, normal = actor(0), actor(132)
		expect(Body.collides(passive, normal)).toBe(true)
		expect(Body.collides(normal, passive)).toBe(true)
		expect(Body.collides(passive, actor(0))).toBe(false)
		expect(Body.collides(actor(2), actor(128))).toBe(false)
	end)
	it("preserves existing physical behavior for records without approved native masks", function()
		expect(Body.collides(actor(0), Config.Enemies.types.Shadeling)).toBe(true)
		expect(Body.collides(Config.Enemies.types.Shadeling, actor(0))).toBe(true)
	end)
	it("does not separate two bodies with no mask intersection", function()
		local w = world()
		local a = assert(w:spawn(actor(0), 0, 0, 100, 0))
		local b = assert(w:spawn(actor(0), 1, 0, 100, 0))
		w:step(0, {}, {}, 0)
		local ax = w:getPosition(a)
		local bx = w:getPosition(b)
		expect(ax).toBe(0)
		expect(bx).toBe(1)
	end)
	it("lets two actual Velociraptor bodies overlap because both source masks exclude enemy layer4", function()
		local w = world()
		local k = assert(Config.Enemies.types.Velociraptor)
		expect(k.nativeBodyLayer).toBe(4)
		expect(k.nativeBodyMask).toBe(128)
		local a = assert(w:spawn(k, 0, 0, 100, 0))
		local b = assert(w:spawn(k, 1, 0, 100, 0))
		w:step(0, {}, {}, 0)
		local ax = w:getPosition(a)
		local bx = w:getPosition(b)
		expect(ax).toBeNear(0)
		expect(bx).toBeNear(1)
	end)
	it("replaces the hostile mask on Charm so two converted Velociraptors collide as pets", function()
		local Friends = require(game:GetService("ServerScriptService").Server.Services.EnemySim.CharmedWorld)
		local hostile = world()
		local friends = Friends.new(hostile.params, {})
		local k = assert(Config.Enemies.types.Velociraptor)
		local a = assert(hostile:spawn(k, 0, 0, 100, 0))
		local b = assert(hostile:spawn(k, 1, 0, 100, 0))
		assert(friends:convert(hostile, a, 17, 0, { contact = 1, shot = 0 }))
		assert(friends:convert(hostile, b, 17, 0, { contact = 1, shot = 0 }))
		local friendKind = friends.world:getKind(a)
		expect(friendKind.nativeBodyLayer).toBe(512)
		expect(friendKind.nativeBodyMask).toBe(640)
		expect(k.nativeBodyLayer).toBe(4)
		expect(k.nativeBodyMask).toBe(128)
		friends.world:step(0, {}, {}, 0)
		local ax = friends.world:getPosition(a)
		local bx = friends.world:getPosition(b)
		expect(bx - ax > 1).toBe(true)
	end)
	it("still separates a zero-mask body when the other mask includes its layer", function()
		local w = world()
		local a = assert(w:spawn(actor(0), 0, 0, 100, 0))
		local b = assert(w:spawn(actor(132), 1, 0, 100, 0))
		w:step(0, {}, {}, 0)
		local ax = w:getPosition(a)
		local bx = w:getPosition(b)
		expect(bx - ax > 1).toBe(true)
	end)
	it("does not yield forward movement to an excluded neighbor", function()
		local w = world()
		local moving, still = actor(0), actor(0)
		still.anchored = true
		local a = assert(w:spawn(moving, 0, 0, 100, 0))
		w:spawn(still, 6.1, 0, 100, 0)
		w:step(0.1, { 80 }, { 0 }, 1)
		local x = w:getPosition(a)
		expect(x).toBeNear(1)
	end)
end)
