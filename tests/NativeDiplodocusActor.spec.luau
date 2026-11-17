--!strict
-- Native Diplodocus uses its original finite spawn clock and independent source slash child on HP/time boundaries.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Actor = require(game:GetService("ServerScriptService").Server.Services.EnemySim.NativeBossActor)
local S = require(Shared.Util.NativeBossShooting)
local C = require(Shared.Config.NativeDiplodocus).controller
local function fixed()
	return 0.5
end
describe("Native Diplodocus actor", function()
	it("fires the root method on source frame212 after165cooldown and48animation frames", function()
		local state = Actor.new(C, fixed)
		local requests = 0
		local function step(dt)
			Actor.step(
				state,
				dt,
				function()
					return 1
				end,
				math.huge,
				fixed,
				function(index)
					expect(index).toBe(1)
					requests += 1
					S.recordSpawns(state.shooting, index, 1)
				end
			)
		end
		step(211 / 60)
		expect(requests).toBe(0)
		step(1 / 60)
		expect(requests).toBe(1)
	end)
	it("switches at25seconds at full health and preserves the child's45frame initial clock", function()
		local state = Actor.new(C, fixed)
		Actor.step(state, 24.9, function()
			return 1
		end, 10, fixed, function() end)
		expect(state.shooting.current).toBe(1)
		Actor.step(state, 0.1, function()
			return 1
		end, 10, fixed, function() end)
		expect(state.shooting.current).toBe(2)
		expect(state.shooting.clocks[2].initial).toBeNear(44)
	end)
	it("keeps two slash-method calls per long pause and source per-origin random spread", function()
		local state = S.new(C.shooting, fixed)
		S.select(state, 2)
		expect(state.clocks[2].initial).toBe(45)
		S.physics(state, 45 / 60, 10)
		for _ = 1, 2 do
			assert(S.physics(state, 10 / 60, 10))
			local fired = S.advanceAnimation(state, 0.5, fixed)
			expect(fired[1]).toBe(2)
		end
		expect(state.clocks[2].remaining).toBe(120)
		local rule = C.attacks[2].volley
		expect(rule.count).toBe(8)
		expect(rule.baseAimFromSpawn).toBe(true)
		expect(rule.constantSpread).toBe(false)
		expect(rule.spread).toBe(0.3)
	end)
end)
