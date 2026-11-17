--!strict
-- Normal Jeholopterus detection/anticipation and direct charge cadence run in the production World.
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
	local k = assert(Kinds.get("Jeholopterus"))
	local id = assert(w:spawn(k, 0, 0, 1000, 1, nil, 1))
	return id, w.indexOf[id], k
end
describe("Native normal Jeholopterus", function()
	it("connects the original normal body, source growth, radial charge and detection policies", function()
		local k = assert(Kinds.get("Jeholopterus"))
		expect(k.typeId).toBe(56)
		expect(k.hp).toBe(3)
		expect(k.hpPerWave).toBe(2)
		expect(k.damagePerWave).toBeNear(0.85)
		expect(k.nativeSpeedPoints.base).toBe(150)
		expect(k.nativeSpeedPoints.randomization).toBe(20)
		expect(k.nativeDetection.radius).toBeNear(45)
		expect(k.nativeDetection.speedBonus).toBeNear(15)
		expect(k.wander).toBe(nil)
		expect(k.anticipate.seconds).toBeNear(0.2)
		expect(k.nativeCharge.target.player).toBe(true)
		expect(k.nativeCharge.target.atShoot).toBe(false)
		expect(k.nativeCharge.longEvery).toBe(2)
		expect(k.nativeCharge.longCooldown).toBeNear(0.75)
		expect(k.nativeCharge.speed).toBeNear(40)
		expect(k.nativeCharge.duration).toBeNear(0.3)
		expect(EnemyStats.canSpawn(k, 1, 0, 0)).toBe(false)
		expect(EnemyStats.canSpawn(k, 1, 0, 2)).toBe(true)
	end)
	it("follows without prediction before detection and anticipates only after the inclusive450px threshold", function()
		local w = world()
		local _, i = actor(w)
		w:step(0.1, { 100 }, { 0 }, 1, nil, nil, nil, { 0 }, { 100 })
		expect(w.detections[i].detected).toBe(false)
		expect(w.zs[i]).toBeNear(0)
		local x, z = w.xs[i], w.zs[i]
		w:step(0.1, { x + 45 }, { z }, 1, nil, nil, nil, { 0 }, { 100 })
		expect(w.detections[i].detected).toBe(true)
		expect(w.speedBonuses[i]).toBeNear(15)
		expect(w.zs[i] > z).toBe(true)
	end)
	it(
		"charges at the sampled unanticipated player position and clears the earlier detection bonus after rush",
		function()
			local w = world()
			local _, i, k = actor(w)
			local charge = w.nativeCharges[i]
			charge.remaining = 0
			w:step(0, { 20 }, { 0 }, 1, nil, nil, nil, { 0 }, { 100 })
			expect(charge.stage).toBe("Windup")
			expect(charge.direction).toBeNear(1)
			expect(charge.directionZ).toBeNear(0)
			w:step(k.nativeCharge.fireAt, { 0 }, { 20 }, 1, nil, nil, nil, { 100 }, { 0 })
			expect(charge.stage).toBe("Rush")
			expect(charge.directionZ).toBeNear(0)
			expect(w.speedBonuses[i]).toBeNear(40)
			expect(w:isProjectileDeflecting(w.ids[i])).toBe(false)
			w:step(k.nativeCharge.duration, {}, {}, 0)
			expect(charge.stage).toBe("Recover")
			expect(w.speedBonuses[i]).toBe(0)
		end
	)
	it(
		"preserves the shot counter through World transfer and applies the long pause on the next second shot",
		function()
			local a, b = world(), world()
			local id, i, k = actor(a)
			local charge = a.nativeCharges[i]
			charge.remaining = 0
			a:step(k.nativeCharge.fireAt, { 20 }, { 0 }, 1)
			expect(charge.shotsTaken).toBe(1)
			expect(a:transferTo(b, id)).toBe(true)
			expect(b.nativeCharges[b.indexOf[id]]).toBe(charge)
			b:step(1, {}, {}, 0)
			expect(charge.stage).toBe("Walk")
			local j = b.indexOf[id]
			b:step(k.nativeCharge.fireAt, { b.xs[j] + 20 }, { b.zs[j] }, 1)
			expect(charge.stage).toBe("Rush")
			expect(charge.shotsTaken).toBe(0)
			expect(charge.remaining).toBeNear(0.75 + 0.3)
		end
	)
end)
