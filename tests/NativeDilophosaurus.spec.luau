--!strict
-- Normal Dilophosaurus uses a scaled transformed pillar triple with every-third long cooldown.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Kinds = require(Shared.Util.EnemyKinds)
local Clock = require(Shared.Util.NativeEnemyShootingClock)
local Volley = require(Shared.Util.NativeEnemyVolley)
describe("Normal Dilophosaurus", function()
	it("binds source stats, generic following and actual scaled normal pillar attack", function()
		local k = assert(Kinds.get("Dilophosaurus"), "Dilophosaurus missing")
		expect(k.typeId).toBe(64)
		expect(k.hp).toBe(5)
		expect(k.hpPerWave).toBe(7)
		expect(k.nativeSpeedPoints.base).toBe(250)
		expect(k.nativeSpeedPoints.randomization).toBe(0)
		expect(k.damagePerWave).toBeNear(1.1)
		expect(k.xp).toBe(3)
		expect(k.wander).toBe(nil)
		expect(k.stayInRange).toBe(nil)
		local r = k.ranged
		expect(r.nativePillar).toBe(true)
		expect(r.minFireRange).toBe(5)
		expect(r.nativeVolley.count).toBe(3)
		expect(r.nativeVolley.offsetX).toBe(2)
		expect(r.nativeVolley.offsetZ).toBe(-3)
		expect(r.nativeVolley.scaleWithCount).toBe(true)
		expect(r.nativeVolley.minimumScale).toBeNear(0.7)
		expect(r.nativeTiming.fireAt).toBeNear(0.16)
		expect(r.nativeTiming.animationSeconds).toBeNear(0.2)
		expect(r.nativeTiming.initialSeconds).toBeNear(5 / 60)
		expect(r.nativeTiming.fireInterval).toBe(0)
		expect(r.nativeTiming.cooldownRandomSeconds).toBe(0)
		expect(r.nativeTiming.longEvery).toBe(3)
		expect(r.nativeTiming.longSeconds).toBeNear(2.5)
	end)
	it("resets the native shot counter only on each third long pause", function()
		local rule = assert(Kinds.get("Dilophosaurus")).ranged.nativeTiming
		for shot = 1, 3 do
			local state = Clock.new(rule, function()
				return 0.5
			end)
			state.initial = 0
			state.stage = "Animation"
			state.age = rule.animationSeconds
			state.fired = true
			state.shots = shot
			Clock.step(state, rule, 0, true, function()
				return 0.5
			end)
			expect(state.remaining).toBeNear(if shot == 3 then 2.5 else 0.5 / 60)
			expect(state.shots).toBe(if shot == 3 then 0 else shot)
		end
	end)
	it("emits mirrored source transform offsets without an unused parallel-only forward offset", function()
		local r = assert(Kinds.get("Dilophosaurus")).ranged
		for _, sign in { -1, 1 } do
			local shots = {}
			Volley.emit(r.nativeVolley, 0, 0, sign * 30, -3, r.projectileSpeed, function()
				return 0.5
			end, function(x, z, dx, dz, speed, scale)
				table.insert(shots, { x = x, z = z, dx = dx, dz = dz, speed = speed, scale = scale })
			end)
			expect(#shots).toBe(3)
			for index, shot in shots do
				expect(shot.x).toBe(sign * 2)
				expect(shot.z).toBe(-3)
				expect(shot.speed).toBe(60 - (index - 1) * 2)
				expect(shot.scale).toBeNear(if index == 2 then 1 else 0.7)
			end
		end
	end)
end)
