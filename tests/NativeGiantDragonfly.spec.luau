--!strict
-- Scene-bound Giant Dragonfly normal behavior uses generic Enemy, fixed pre-detection offset and every-third long charge cooldown.
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
	local k = assert(Kinds.get("GiantDragonfly"))
	local id = assert(w:spawn(k, 0, 0, 1000, 0, nil, 1))
	return id, w.indexOf[id], k
end
describe("Scene-bound normal Giant Dragonfly", function()
	it("uses the actual generic Enemy scene rather than the unbound same-named Pursuer script", function()
		local k = assert(Kinds.get("GiantDragonfly"))
		local f = require(Shared.Config.JungleWalkers).enemies.GiantDragonfly
		expect(k.typeId).toBe(57)
		expect(k.hp).toBe(4)
		expect(k.hpPerWave).toBe(2)
		expect(k.damagePerWave).toBeNear(0.85)
		expect(k.nativeSpeedPoints.base).toBe(200)
		expect(k.nativeSpeedPoints.randomization).toBe(100)
		expect(f.bindingAudit.effectiveScript).toBe("res://entities/units/enemies/enemy.gd")
		expect(f.bindingAudit.specialScriptBound).toBe(false)
		expect(f.bindingAudit.boostTimerConnected).toBe(false)
		expect(k.pursuer).toBe(nil)
		expect(k.wander.around).toBe("Offset")
		expect(k.wander.within).toBe(true)
		expect(k.wander.range).toBeNear(20)
		expect(k.wander.rangeJitter).toBe(0)
		expect(k.nativeDetection.radius).toBeNear(60)
		expect(k.nativeDetection.speedBonus).toBeNear(2)
		expect(k.anticipate.seconds).toBeNear(0.3)
		expect(k.nativeCharge.longEvery).toBe(3)
		expect(k.nativeCharge.longCooldown).toBeNear(55 / 60)
		expect(k.nativeCharge.speed).toBeNear(70)
		expect(k.nativeCharge.duration).toBeNear(0.35)
		expect(EnemyStats.canSpawn(k, 1, 0, 0)).toBe(false)
		expect(EnemyStats.canSpawn(k, 1, 0, 2)).toBe(true)
	end)
	it(
		"preserves its pre-detection offset when the target moves, then switches at the inclusive600px boundary",
		function()
			local w = world()
			local _, i = actor(w)
			local ox, oz = w.wanderXs[i], w.wanderZs[i]
			expect(math.abs(ox) <= 20 and math.abs(oz) <= 20).toBe(true)
			local dx, dz = 100 + ox, oz
			local length = math.sqrt(dx * dx + dz * dz)
			local speed = w.kinds[i].speed
			w:step(0.1, { 100 }, { 0 }, 1)
			expect(w.detections[i].detected).toBe(false)
			expect(w.xs[i]).toBeNear(dx / length * speed * 0.1)
			expect(w.zs[i]).toBeNear(dz / length * speed * 0.1)
			w:step(0.1, { 110 }, { 40 }, 1)
			expect(w.wanderXs[i]).toBeNear(ox)
			expect(w.wanderZs[i]).toBeNear(oz)
			local x, z = w.xs[i], w.zs[i]
			w:step(0.1, { x + 60 }, { z }, 1, nil, nil, nil, { 0 }, { 100 })
			expect(w.detections[i].detected).toBe(true)
			expect(w.speedBonuses[i]).toBeNear(2)
			expect(w.zs[i] > z).toBe(true)
		end
	)
	it("does not invent recurring boosts or a custom five-state machine from an unbound script", function()
		local w = world()
		local _, i = actor(w)
		w:step(30, {}, {}, 0)
		expect(w.pursuers[i]).toBe(nil)
		expect(w.speedBonuses[i]).toBe(0)
		w:step(0, { 50 }, { 0 }, 1)
		expect(w.speedBonuses[i]).toBeNear(2)
		for _ = 1, 10 do
			w:step(1, { 1000 }, { 1000 }, 1)
		end
		expect(w.speedBonuses[i]).toBeNear(2)
		expect(w.nativeCharges[i].stage).toBe("Walk")
	end)
	it("retains two prior shots through transfer and chooses the third-shot long cooldown", function()
		local a, b = world(), world()
		local id, i, k = actor(a)
		local charge = a.nativeCharges[i]
		for shot = 1, 2 do
			charge.remaining = 0
			a:step(k.nativeCharge.fireAt, { a.xs[i] + 10 }, { a.zs[i] }, 1)
			expect(charge.shotsTaken).toBe(shot)
			expect(charge.remaining).toBeNear(20 / 60 + 0.35)
			a:step(2, {}, {}, 0)
		end
		expect(a:transferTo(b, id)).toBe(true)
		local j = b.indexOf[id]
		expect(b.nativeCharges[j]).toBe(charge)
		b:step(k.nativeCharge.fireAt, { b.xs[j] + 10 }, { b.zs[j] }, 1)
		expect(charge.stage).toBe("Rush")
		expect(charge.shotsTaken).toBe(0)
		expect(charge.remaining).toBeNear(55 / 60 + 0.35)
	end)
end)
