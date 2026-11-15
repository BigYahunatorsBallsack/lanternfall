--!strict
-- World adapter for the approved crossing policy; source-only families remain unregistered.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config)
local S = game:GetService("ServerScriptService").Server.Services.EnemySim
local World = require(S.World)
local Paths = require(Shared.Config.NativeCrossingPaths)
local function world()
	local s = C.Simulation
	return World.new({
		cellSize = s.spatialHashCellSize,
		maxEnemies = 140,
		playerRadius = s.playerRadius,
		contactMargin = 0,
		separationStiffness = s.separationStiffness,
		separationPasses = s.separationPasses,
		obstacleSteerMargin = s.obstacleSteerMargin,
		keepDistanceTolerance = s.keepDistanceTolerance,
		minX = -100,
		maxX = 100,
		minZ = -60,
		maxZ = 60,
		obstacles = {},
		seed = 1,
	})
end
local function kind()
	local k = table.clone(C.Enemies.types.Shadeling)
	k.speed, k.speedMax = 10, 10
	k.nativeCrossing = Paths.families.Oviraptor
	k.nativeBodyLayer, k.nativeBodyMask = 4, 0
	k.nativeObstacleCollision = false
	k.nativeMovement = { goalInsetX = 0, goalInsetZ = 0, borderClamp = false, collidePlayers = false, precision = 1 }
	return k
end
local function start(w, x)
	local id = assert(w:spawn(kind(), x or -80, 0, 100, 3))
	w:step(0, {}, {}, 0)
	return id
end
describe("Native crossing World adapter", function()
	it("keeps hidden hurt and body shapes disabled while inherited post-physics contact remains possible", function()
		local w = world()
		local id = assert(w:spawn(kind(), 0, 0, 100, 3))
		local out = {}
		expect(w:queryRadius(0, 0, 10, out)).toBe(0)
		expect(w:querySegment(-10, 0, 10, 0, 1, out)).toBe(0)
		local ordinary = table.clone(C.Enemies.types.Shadeling)
		ordinary.speed, ordinary.speedMax = 0, 0
		ordinary.anchored = true -- isolate enemy-body separation from this fixture's coincident player constraint
		local other = assert(w:spawn(ordinary, 0, 0, 100, 0))
		local hits = w:step(0, { 0 }, { 0 }, 1)
		expect(w.crossings[w.indexOf[id]].phase).toBe("Warning")
		expect(hits[1]).toBe(3)
		local x, z = w:getPosition(other)
		expect(x).toBeNear(0)
		expect(z).toBeNear(0)
	end)
	it("moves without targets after timeout and ignores new goals when already crossing", function()
		local w = world()
		local id = start(w)
		w:step(0.35, {}, {}, 0)
		local i = w.indexOf[id]
		local state = w.crossings[i]
		expect(state.phase).toBe("Moving")
		local x = w:getPosition(id)
		expect(x > -80).toBe(true)
		local dx, dz = state.dx, state.dz
		w:setGoal(id, -100, -60)
		w:step(0.1, { -100 }, { -60 }, 1)
		local after = w:getPosition(id)
		expect(after > x).toBe(true)
		expect(state.dx).toBe(dx)
		expect(state.dz).toBe(dz)
		expect(w:queryRadius(w.xs[i], w.zs[i], 10, {})).toBe(1)
	end)
	it("rotates body, hurt and hit offsets once without modifying the source kind", function()
		local w = world()
		local k = kind()
		k.nativeBodyOffsetX, k.nativeBodyOffsetZ = 0, 2
		k.nativeHurtOffsetX, k.nativeHurtOffsetZ = 0, 3
		k.nativeHitOffsetX, k.nativeHitOffsetZ = 0, 4
		local id = assert(w:spawn(k, -80, 0, 100, 3))
		w:step(0, {}, {}, 0)
		w:step(0.35, {}, {}, 0)
		local i = w.indexOf[id]
		local theta = w.crossings[i].rotation
		expect(w.kinds[i].nativeBodyOffsetX).toBeNear(-2 * math.sin(theta))
		expect(w.kinds[i].nativeHitOffsetX).toBeNear(-4 * math.sin(theta))
		local hx, hz = w:getHurtGeometry(id)
		expect(hx).toBeNear(w.xs[i] - 3 * math.sin(theta))
		expect(hz).toBeNear(w.zs[i] + 3 * math.cos(theta))
		expect(k.nativeHurtOffsetX).toBe(0)
		expect(k.nativeHurtOffsetZ).toBe(3)
		w:step(0.1, {}, {}, 0)
		expect(w.kinds[i].nativeBodyOffsetX).toBeNear(-2 * math.sin(theta))
	end)
	it("retains warning clock and fixed path through transfer and column compaction", function()
		local a, b = world(), world()
		local trash = assert(a:spawn(C.Enemies.types.Shadeling, 30, 30, 100, 0))
		local id = start(a)
		local state = a.crossings[a.indexOf[id]]
		a:remove(trash)
		a:step(0.1, {}, {}, 0)
		expect(a.indexOf[id]).toBe(1)
		expect(a.crossings[1]).toBe(state)
		assert(a:transferTo(b, id))
		b:step(0.25, {}, {}, 0)
		expect(b.crossings[b.indexOf[id]]).toBe(state)
		expect(state.phase).toBe("Moving")
		expect(a:isAlive(id)).toBe(false)
	end)
	it("removes strictly beyond the saved exit without damage or residual contacts", function()
		local w = world()
		local id = start(w)
		w:step(0.35, {}, {}, 0)
		local state = w.crossings[w.indexOf[id]]
		local edge = state.targetX + 15
		w:teleport(id, edge, 0)
		w:step(0, {}, {}, 0)
		expect(w:isAlive(id)).toBe(true)
		w:teleport(id, edge + 0.01, 0)
		w.damage = function()
			error("Despawn must not damage")
		end
		local hits = w:step(0, { edge + 0.01 }, { 0 }, 1)
		expect(w:isAlive(id)).toBe(false)
		expect(w:getAliveCount()).toBe(0)
		expect(hits[1]).toBe(0)
		w:step(0, {}, {}, 0)
		expect(w.count).toBe(0)
	end)
	it("suppresses warning contact during any real knockback, against zero movement input", function()
		local w = world()
		local id = start(w, 0)
		w:knock(id, 0.01, 0, false)
		local hits = w:step(0, { 0 }, { 0 }, 1)
		expect(hits[1]).toBe(0)
	end)
	it("preserves warning on actual Charm conversion and releases an escaping member without death rewards", function()
		local Friends = require(S.CharmedWorld)
		local hostile = world()
		local id = start(hostile)
		hostile:step(0.1, {}, {}, 0)
		local state = hostile.crossings[hostile.indexOf[id]]
		local friends = Friends.new(hostile.params, {
			expired = function()
				error("Quiet escape must not resolve a Charm death")
			end,
			damage = function()
				error("No hostile target")
			end,
		})
		assert(friends:convert(hostile, id, 17, 0, { contact = 3, shot = 0 }))
		friends:step(0.25, 0.25, hostile)
		expect(friends.world.crossings[friends.world.indexOf[id]]).toBe(state)
		expect(state.phase).toBe("Moving")
		friends.world:teleport(id, state.targetX + 15.01, 0)
		friends:step(0, 0.3, hostile)
		expect(friends:count(17)).toBe(0)
		expect(friends.members[id]).toBe(nil)
		friends:step(0, 0.4, hostile)
		expect(friends.world:isAlive(id)).toBe(false)
	end)
end)
