--!strict
-- Actual Velociraptor source body, detection latch, independent boosts, contact reset and faction transfer.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config)
local Kinds = require(Shared.Util.EnemyKinds)
local EnemyStats = require(Shared.Util.EnemyStats)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local function world()
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
		minX = -200,
		maxX = 200,
		minZ = -200,
		maxZ = 200,
		obstacles = {},
		seed = 1,
		referencePlayerSpeed = function()
			return 0
		end,
	})
end
local function actor(w)
	local k = assert(Kinds.get("Velociraptor"))
	local id = assert(w:spawn(k, 0, 0, 1000, 1, nil, 1))
	return id, w.indexOf[id]
end
describe("Native normal Velociraptor", function()
	it("preserves source stats, zone isolation and geometry without inheriting the ++ warning charge", function()
		local k = assert(Kinds.get("Velociraptor"))
		expect(k.typeId).toBe(55)
		expect(k.hp).toBe(6)
		expect(k.hpPerWave).toBe(8)
		expect(k.damagePerWave).toBeNear(0.6)
		expect(k.nativeCharge).toBe(nil)
		expect(k.nativeDetection.radius).toBeNear(65)
		expect(k.nativeDetection.speedBonus).toBeNear(9)
		expect(k.pursuer.resetOnContact).toBe(true)
		expect(k.pursuer.playerSpeedShare).toBe(nil)
		expect(k.wander.around).toBe("Target")
		expect(k.wander.range).toBeNear(50)
		expect(k.nativeMovement.borderClamp).toBe(false)
		expect(k.nativeMovement.collidePlayers).toBe(false)
		expect(k.nativeObstacleCollision).toBe(true)
		expect(EnemyStats.canSpawn(k, 1, 0, 0)).toBe(false)
		expect(EnemyStats.canSpawn(k, 1, 0, 2)).toBe(true)
	end)
	it(
		"wanders before detection, switches to direct pursuit at the inclusive boundary and never adds detection twice",
		function()
			local w = world()
			local _, i = actor(w)
			w:step(0, { 100 }, { 0 }, 1)
			expect(w.detections[i].detected).toBe(false)
			local x, z = w.xs[i], w.zs[i]
			w:step(0, { x + 65 }, { z }, 1)
			expect(w.detections[i].detected).toBe(true)
			expect(w.speedBonuses[i]).toBeNear(9)
			local speed = w.kinds[i].speed
			w:step(0.1, { x + 100 }, { z }, 1)
			expect(w.xs[i] - x).toBeNear((speed + 9) * 0.1)
			expect(w.zs[i]).toBeNear(z)
			expect(w.speedBonuses[i]).toBeNear(9)
		end
	)
	it(
		"boosts without targets and resets accumulated speed plus detection bonus on contact without resetting timer phase",
		function()
			local w = world()
			local _, i = actor(w)
			w:step(2.75, {}, {}, 0)
			expect(w.pursuers[i].stage).toBe(2)
			expect(w.speedBonuses[i]).toBeNear(9)
			w:step(0, { w.xs[i] + 40 }, { w.zs[i] }, 1)
			expect(w.speedBonuses[i]).toBeNear(18)
			local k = w.kinds[i]
			w:step(0, { w.xs[i] + (k.nativeHitOffsetX or 0) }, { w.zs[i] + (k.nativeHitOffsetZ or 0) }, 1)
			expect(w.pursuers[i].stage).toBe(0)
			expect(w.speedBonuses[i]).toBe(0)
			expect(w.pursuers[i].clock).toBeNear(0.75)
			w:step(0.25, {}, {}, 0)
			expect(w.speedBonuses[i]).toBeNear(4.5)
			expect(w.detections[i].detected).toBe(true)
		end
	)
	it("preserves detection and timer state across faction transfer and clears recycled columns", function()
		local a, b = world(), world()
		local id, i = actor(a)
		a:step(0.25, { 60 }, { 0 }, 1)
		local detection, state = a.detections[i], a.pursuers[i]
		expect(a:transferTo(b, id)).toBe(true)
		expect(b.detections[b.indexOf[id]]).toBe(detection)
		expect(b.pursuers[b.indexOf[id]]).toBe(state)
		expect(detection.detected).toBe(true)
		b:clear()
		local _, j = actor(b)
		expect(b.detections[j].detected).toBe(false)
		expect(b.pursuers[j].stage).toBe(0)
	end)
	it("resets only on a new contact identity, including when target slots change", function()
		local w = world()
		local _, i = actor(w)
		local function touch(dt, xs, zs, keys)
			w:step(dt, xs, zs, #keys, nil, nil, nil, nil, nil, nil, nil, keys)
		end
		local k = w.kinds[i]
		local hx, hz = w.xs[i] + (k.nativeHitOffsetX or 0), w.zs[i] + (k.nativeHitOffsetZ or 0)
		touch(0, { hx }, { hz }, { "Player:101" })
		w.speedBonuses[i] = 4.5
		touch(0, { hx + 100, hx }, { hz, hz }, { 202, "Player:101" })
		expect(w.speedBonuses[i]).toBeNear(4.5)
		touch(0, { hx }, { hz }, { 101 })
		expect(w.speedBonuses[i]).toBe(0)
		w.speedBonuses[i] = 4.5
		touch(0, { hx + 100 }, { hz }, { 202 })
		touch(0, { hx }, { hz }, { 202 })
		expect(w.speedBonuses[i]).toBe(0)
	end)
	it("applies the source accessibility factor to detection and repeating flat boosts", function()
		local w = world()
		w.params.nativeChargeAccessibility = function()
			return 0.5
		end
		local _, i = actor(w)
		w:step(0, { 60 }, { 0 }, 1)
		expect(w.speedBonuses[i]).toBeNear(4.5)
		w:step(2.25, {}, {}, 0)
		expect(w.speedBonuses[i]).toBeNear(9)
	end)
end)
