--!strict
-- Native outgoing hit circles compose parent/child positions and sweep separately from actor origins and target hurt circles.
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
describe("Native Jungle outgoing hit geometry", function()
	it("composes hit parent/child transforms including nonzero parents", function()
		expect(Kinds.get("Enigmacursor").nativeHitOffsetX).toBeNear(0.1)
		expect(Kinds.get("Enigmacursor").nativeHitOffsetZ).toBeNear(0)
		expect(Kinds.get("DinoEgg").nativeHitOffsetZ).toBeNear(-1.4)
		expect(Kinds.get("BabyPterosaur").nativeHitOffsetZ).toBeNear(-2.7)
		expect(Kinds.get("Stintaosaurus").nativeHitOffsetZ).toBeNear(0.8)
	end)
	it("uses the outgoing hit center against compensated contact points while preserving legacy circles", function()
		local w = make({})
		w.params.contactMargin = 0
		w.params.collideTargets = false
		local k = assert(Kinds.get("BabyPterosaur"))
		local id = assert(w:spawn(k, 0, 0, 1000, 7, nil, 0))
		w:step(0, { 80 }, { 80 }, 1, { 0 }, { -2.7 - k.hitRadius + 0.1 }, { 0 })
		expect(w.contacts[1]).toBe(7)
		expect(w.contactSources[1]).toBe(id)
		w:step(0, { 80 }, { 80 }, 1, { 0 }, { k.hitRadius - 0.1 }, { 0 })
		expect(w.contacts[1]).toBe(0)
		local old = make({})
		old.params.contactMargin = 0
		old.params.collideTargets = false
		local legacy = table.clone(assert(Kinds.get("Shadeling")))
		legacy.hitRadius = 1
		assert(old:spawn(legacy, 0, 0, 1000, 7, nil, 0))
		old:step(0, { 80 }, { 80 }, 1, { 0 }, { 0.9 }, { 0 })
		expect(old.contacts[1]).toBe(7)
	end)
	it("sweeps the translated hit circle along a timed rush without moving the actor path", function()
		local w = make({})
		w.params.contactMargin = 0
		local k = table.clone(assert(Kinds.get("Triceratops")))
		k.radius, k.hurtRadius, k.hitRadius = 0.1, 0.1, 1
		k.nativeBodyOffsetX, k.nativeBodyOffsetZ = 0, 0
		k.nativeHitOffsetX, k.nativeHitOffsetZ = 0, -10
		k.speed, k.speedMax = 0, 0
		k.nativeCharge = table.clone(k.nativeCharge)
		k.nativeCharge.speed = 100
		local id = assert(w:spawn(k, -20, 10, 1000, 7, nil, 1))
		w.nativeCharges[w.indexOf[id]].remaining = 0
		w:step(0, { 80 }, { 10 }, 1, { 0 }, { 0 }, { 0 })
		w:step(k.nativeCharge.fireAt, { 80 }, { 10 }, 1, { 0 }, { 0 }, { 0 })
		w:step(0.4, { 80 }, { 10 }, 1, { 0 }, { 0 }, { 0 })
		expect(w.contacts[1]).toBe(7)
		local x, z = w:getPosition(id)
		expect(x).toBeNear(20)
		expect(z).toBeNear(10)
	end)
	it("scales only the hit child translation during native parent growth", function()
		local w = make({})
		local k = table.clone(assert(Kinds.get("BabyTrex")))
		k.nativeHitOffsetZ, k.nativeHitChildZ = 3, 2
		local id = assert(w:spawn(k, 0, 0, 1000, 7, nil, 0))
		w:step(1.1, {}, {}, 0)
		expect(w.kinds[w.indexOf[id]].nativeHitOffsetZ).toBeNear(3.05)
		expect(w.kinds[w.indexOf[id]].hitRadius).toBeNear(k.hitRadius * 1.025)
	end)
	it("matches a charmed native attack circle to the hostile hurt circle without retargeting AI origins", function()
		local Friends = require(game:GetService("ServerScriptService").Server.Services.EnemySim.CharmedWorld)
		local w = make({})
		w.params.contactMargin = 0
		local attacker = table.clone(assert(Kinds.get("BabyPterosaur")))
		attacker.hitRadius = 0.2
		local actor = assert(w:spawn(attacker, 0, 0, 1000, 7, nil, 0))
		local hits = {}
		local friends = Friends.new(w.params, {
			damage = function(id, amount)
				table.insert(hits, { id, amount })
			end,
			expired = function() end,
		})
		assert(friends:convert(w, actor, 17, 0, { contact = 7, shot = 0 }))
		local k = table.clone(assert(Kinds.get("BabyTriceratops")))
		k.hurtRadius, k.nativeHurtOffsetZ = 0.1, -2.7
		local target = assert(w:spawn(k, 0, 0, 1000, 0, nil, 0))
		friends:step(0, 0, w)
		expect(#hits).toBe(1)
		expect(hits[1][1]).toBe(target)
		expect(hits[1][2]).toBe(21)
		expect(friends.targetZs[1]).toBe(0)
	end)
end)
