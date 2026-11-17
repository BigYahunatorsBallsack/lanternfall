--!strict
-- Scene-bound normal Pterosaur uses random target points and every-third long charge, not unused anticipation children.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config)
local Kinds = require(Shared.Util.EnemyKinds)
local S = game:GetService("ServerScriptService").Server.Services.EnemySim
local World = require(S.World)
local Charge = require(S.NativeStraightCharge)
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
		minX = -200,
		maxX = 200,
		minZ = -200,
		maxZ = 200,
		obstacles = {},
		seed = 1,
	})
end
describe("Normal Pterosaur", function()
	it("registers original source stats and actual bound behaviors", function()
		local k = assert(Kinds.get("Pterosaur"), "Normal Pterosaur missing")
		expect(k.typeId).toBe(61)
		expect(k.hp).toBe(8)
		expect(k.hpPerWave).toBe(6)
		expect(k.damagePerWave).toBeNear(0.85)
		expect(k.xp).toBe(2)
		expect(k.nativeSpeedPoints.base).toBe(300)
		expect(k.nativeSpeedPoints.randomization).toBe(50)
		expect(k.nativeBodyMask).toBe(4)
		expect(k.nativeObstacleCollision).toBe(false)
		expect(k.wander.around).toBe("Target")
		expect(k.wander.range).toBe(50)
		expect(k.wander.rangeJitter).toBe(10)
		expect(k.nativeDetection).toBe(nil)
		expect(k.anticipate).toBe(nil)
		expect(k.retaliate).toBe(nil)
		local audit = require(Shared.Config.JungleWalkers).enemies.Pterosaur.bindingAudit
		expect(audit.anticipationChildrenActive).toBe(false)
		expect(audit.exportedProjectileChance).toBeNear(0.25)
		expect(audit.projectileChanceUsedByBoundOverride).toBe(false)
		expect(k.nativeCharge.cooldown).toBe(0)
		expect(k.nativeCharge.jitter).toBe(0)
		expect(k.nativeCharge.duration).toBeNear(1.5)
		expect(k.nativeCharge.speed).toBe(40)
		expect(k.nativeCharge.maxRange).toBe(45)
		expect(k.nativeCharge.fireAt).toBeNear(0.8 / 1.5)
		expect(k.nativeCharge.longEvery).toBe(3)
		expect(k.nativeCharge.longCooldown).toBeNear(0.75)
	end)
	it("keeps a random target point until arrival and does not activate unused prediction children", function()
		local w = world()
		local k = assert(Kinds.get("Pterosaur"))
		local id = assert(w:spawn(k, 0, 0, 100, 0))
		local i = w.indexOf[id]
		w:step(0.1, { 150 }, { 0 }, 1, nil, nil, nil, { 100 }, { 100 })
		local gx, gz = w.wanderXs[i], w.wanderZs[i]
		expect(w.detections[i]).toBe(nil)
		expect(w.nativeCharges[i].stage).toBe("Walk")
		expect((w.xs[i] ^ 2 + w.zs[i] ^ 2) > 0).toBe(true)
		expect(math.abs(gx - 150) <= 60).toBe(true)
		w:step(0.1, { 160 }, { 30 }, 1, nil, nil, nil, { -100 }, { 100 })
		expect(w.wanderXs[i]).toBe(gx)
		expect(w.wanderZs[i]).toBe(gz)
	end)
	it("uses three long diagonal charges and retains cadence through transfer", function()
		local w = world()
		local k = assert(Kinds.get("Pterosaur"))
		local id = assert(w:spawn(k, 0, 0, 100, 0))
		local i = w.indexOf[id]
		local state = w.nativeCharges[i]
		for shot = 1, 3 do
			state.stage, state.left = "Windup", 0
			Charge.step(state, k.nativeCharge, 0, 3, 4, true, function()
				return 0.5
			end, 1)
			expect(state.remaining).toBeNear(1.5 + (if shot % 3 == 0 then 0.75 else 0.5 / 60))
			expect(state.shotsTaken).toBe(shot % 3)
		end
		state.stage, state.remaining = "Walk", 0
		Charge.step(state, k.nativeCharge, 0, 3, 4, true, function()
			return 0.5
		end, 1)
		expect(state.direction).toBeNear(0.6)
		expect(state.directionZ).toBeNear(0.8)
		local other = world()
		assert(w:transferTo(other, id))
		expect(other.nativeCharges[other.indexOf[id]]).toBe(state)
		expect(other.wanderXs[other.indexOf[id]]).toBe(w.wanderXs[i])
	end)
end)
