--!strict
-- Native direct-player targeting and every-N long cooldown use original charge rules without changing existing horizontal charges.
loadHelper("tests/helpers/RobloxMock.luau")
local S = game:GetService("ServerScriptService").Server.Services.EnemySim
local Charge = require(S.NativeStraightCharge)
local Target = require(S.NativeChargeTarget)
local function rule()
	return {
		cooldown = 15 / 60,
		jitter = 0,
		minimumCooldown = 1 / 60,
		fireAt = (0.533333 / 4),
		duration = 0.3,
		recovery = 0.05,
		speed = 40,
		rangeZ = -0.1,
		rangeX = -0.1,
		minRange = 0,
		maxRange = 35,
		massMultiplier = 5,
		longEvery = 2,
		longCooldown = 45 / 60,
		target = { player = true, atShoot = false },
	}
end
describe("Native direct charge cadence", function()
	it("samples current player position in both axes without anticipation or random draws", function()
		local x, z = Target.direction(rule(), 3, 4, 100, 100, function()
			error("direct player target consumes no RNG")
		end)
		expect(x).toBeNear(0.6)
		expect(z).toBeNear(0.8)
		x, z = Target.direction(rule(), 0, 0, 0, 0, function()
			error("no RNG")
		end)
		expect(x).toBe(0)
		expect(z).toBe(0)
	end)
	it("uses the exact nonrandom long cooldown after every second shot and restarts the count", function()
		local draws = 0
		local function random()
			draws += 1
			return 0.5
		end
		local r = rule()
		local state = Charge.new(r, 1, random)
		expect(draws).toBe(1)
		for shot = 1, 4 do
			state.stage, state.left = "Windup", 0
			Charge.step(state, r, 0, 3, 4, true, random, 1)
			expect(state.remaining).toBeNear((if shot % 2 == 0 then 0.75 else 0.25) + 0.3)
			expect(state.shotsTaken).toBe(shot % 2)
		end
		expect(draws).toBe(3)
	end)
	it("locks the direct player vector at START_SHOOT rather than retargeting at SHOOT", function()
		local r = rule()
		local state = Charge.new(r, 1, function()
			return 0.5
		end)
		state.remaining = 0
		Charge.step(state, r, 0, 3, 4, true, function()
			return 0.5
		end, 1)
		expect(state.stage).toBe("Windup")
		Charge.step(state, r, r.fireAt, 4, -3, true, function()
			return 0.5
		end, 1)
		expect(state.stage).toBe("Rush")
		expect(state.direction).toBeNear(0.6)
		expect(state.directionZ).toBeNear(0.8)
	end)
end)
