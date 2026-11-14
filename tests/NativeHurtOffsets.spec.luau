--!strict
-- Native hurt circles compose parent/child positions while actor origins and physical bodies retain separate contracts.
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
describe("Native Jungle hurt geometry", function()
	it("composes parent and child positions from approved scenes", function()
		expect(Kinds.get("BabyPterosaur").nativeHurtOffsetZ).toBeNear(-3.4)
		expect(Kinds.get("Enigmacursor").nativeHurtOffsetZ).toBeNear(-1.2)
		expect(Kinds.get("DinoEgg").nativeHurtOffsetZ).toBeNear(-1.9)
		expect(Kinds.get("Brute").nativeHurtOffsetZ).toBe(nil)
	end)
	it("uses translated hurt circles in radius and swept-segment queries with conservative root bounds", function()
		local w = make({})
		local k = table.clone(assert(Kinds.get("BabyTriceratops")))
		k.radius, k.hurtRadius, k.hitRadius, k.nativeHurtOffsetZ = 1, 1, 0, -30
		local id = assert(w:spawn(k, 0, 0, 1000, 0, nil, 0))
		w:step(0, {}, {}, 0)
		local found = {}
		expect(w:queryRadius(0, -30, 0, found)).toBe(1)
		expect(found[1]).toBe(id)
		expect(w:queryRadius(0, 0, 0, found)).toBe(0)
		expect(w:querySegment(-5, -30, 5, -30, 0, found)).toBe(1)
		expect(found[1]).toBe(id)
		expect(w:querySegment(-5, 0, 5, 0, 0, found)).toBe(0)
		local x, z = w:getPosition(id)
		expect(x).toBe(0)
		expect(z).toBe(0)
	end)
	it("distinguishes real Baby Pterosaur hurt edges from actor-origin circles", function()
		local w = make({})
		local k = assert(Kinds.get("BabyPterosaur"))
		local id = assert(w:spawn(k, 0, 0, 1000, 0, nil, 0))
		local found = {}
		expect(w:queryRadius(0, -3.4 - k.hurtRadius + 0.1, 0, found)).toBe(1)
		expect(found[1]).toBe(id)
		expect(w:queryRadius(0, k.hurtRadius - 0.1, 0, found)).toBe(0)
	end)
	it("grows the Hurtbox child offset while retaining parent and body positions", function()
		local w = make({})
		local k = assert(Kinds.get("BabyTrex"))
		local id = assert(w:spawn(k, 0, 0, 1000, 0, nil, 0))
		w:step(1.1, {}, {}, 0)
		local grown = w.kinds[w.indexOf[id]]
		expect(grown.nativeHurtOffsetZ).toBeNear(-0.8825)
		expect(grown.nativeBodyOffsetZ).toBe(k.nativeBodyOffsetZ)
		expect(grown.hurtRadius).toBeNear(k.hurtRadius * 1.025)
		local x, z, radius = w:getHurtGeometry(id)
		expect(x).toBeNear(0)
		expect(z).toBeNear(-0.8825)
		expect(radius).toBeNear(grown.hurtRadius)
		expect(w.maxRadius >= grown.hurtRadius + math.abs(grown.nativeHurtOffsetZ)).toBe(true)
	end)
	it("preserves translated geometry across world transfer", function()
		local w, other = make({}), make({})
		local id = assert(w:spawn(assert(Kinds.get("DinoEgg")), 5, 10, 1000, 0, nil, 0))
		expect(w:transferTo(other, id)).toBe(true)
		local x, z = other:getHurtGeometry(id)
		expect(x).toBeNear(5)
		expect(z).toBeNear(8.1)
	end)
	it("keeps charmed AI origins separate from hostile hurt centers used for projectiles", function()
		local Friends = require(game:GetService("ServerScriptService").Server.Services.EnemySim.CharmedWorld)
		local w = make({})
		local actor = assert(w:spawn(assert(Kinds.get("Shadeling")), -20, -30, 1000, 0, nil, 0))
		local hits = {}
		local friends = Friends.new(w.params, {
			damage = function(id, amount)
				table.insert(hits, { id, amount })
			end,
			expired = function() end,
		})
		assert(friends:convert(w, actor, 17, 0, { contact = 0, shot = 0 }))
		local k = table.clone(assert(Kinds.get("BabyTriceratops")))
		k.radius, k.hurtRadius, k.hitRadius, k.nativeHurtOffsetZ = 1, 1, 0, -30
		local target = assert(w:spawn(k, 0, 0, 1000, 0, nil, 0))
		friends:fire(friends.members[actor], -10, -30, 1, 0, 20, 40, 0.1, 7)
		friends:step(1, 1, w)
		expect(#hits).toBe(1)
		expect(hits[1][1]).toBe(target)
		expect(hits[1][2]).toBe(7)
		expect(friends.targetZs[1]).toBe(0)
	end)
end)
