--!strict
-- Native shooting waits its initial cooldown, fires at the animation method key, then starts a new cooldown at animation end.
loadHelper("tests/helpers/RobloxMock.luau")
local Clock = require(game:GetService("ReplicatedStorage").Shared.Util.NativeEnemyShootingClock)
local rule = { fireInterval = 2, cooldownRandomSeconds = 0, initialSeconds = 0, fireAt = 0.4, animationSeconds = 0.5 }
local function random()
	return 0.5
end
describe("Native enemy shooting clock", function()
	it("retains the source's reversed zero-cooldown bounds instead of replacing them with a fixed delay", function()
		local zero = table.clone(rule)
		zero.fireInterval, zero.minimumCooldownSeconds = 0, 1 / 60
		expect(Clock.new(zero, function()
			return 0
		end).remaining).toBeNear(1 / 60)
		expect(Clock.new(zero, function()
			return 1
		end).remaining).toBeNear(0)
		expect(Clock.new(zero, function()
			return 0.5
		end).remaining).toBeNear(1 / 120)
	end)
	it("uses the long cooldown only after the configured number of complete volleys", function()
		local burst = table.clone(rule)
		burst.fireInterval, burst.longEvery, burst.longSeconds = 0, 2, 3
		local clock = Clock.new(burst, random)
		expect(Clock.step(clock, burst, 0.4, true, random)).toBe(true)
		expect(Clock.step(clock, burst, 0.1, true, random)).toBe(false)
		expect(Clock.step(clock, burst, 0.4, true, random)).toBe(true)
		expect(Clock.step(clock, burst, 0.1, true, random)).toBe(false)
		expect(clock.remaining).toBe(3)
		local transferred = table.clone(clock)
		expect(Clock.step(transferred, burst, 3.39, true, random)).toBe(false)
		expect(Clock.step(transferred, burst, 0.01, true, random)).toBe(true)
	end)
	it("waits a full first cooldown and fires only at the animation method", function()
		local clock = Clock.new(rule, random)
		expect(Clock.step(clock, rule, 1.9, true, random)).toBe(false)
		expect(Clock.step(clock, rule, 0.1, true, random)).toBe(false)
		expect(Clock.step(clock, rule, 0.39, true, random)).toBe(false)
		expect(Clock.step(clock, rule, 0.01, true, random)).toBe(true)
		expect(Clock.step(clock, rule, 0.1, true, random)).toBe(false)
		expect(Clock.step(clock, rule, 2.39, true, random)).toBe(false)
		expect(Clock.step(clock, rule, 0.01, true, random)).toBe(true)
	end)
	it("counts cooldown outside range and finishes an already started animation after leaving range", function()
		local clock = Clock.new(rule, random)
		expect(Clock.step(clock, rule, 3, false, random)).toBe(false)
		expect(Clock.step(clock, rule, 0, true, random)).toBe(false)
		expect(Clock.step(clock, rule, 0.4, false, random)).toBe(true)
	end)
	it("applies initial delay before the cooldown and samples the source cooldown bounds", function()
		local copy = table.clone(rule)
		copy.initialSeconds = 0.5
		copy.cooldownRandomSeconds = 1 / 6
		local clock = Clock.new(copy, function()
			return 0
		end)
		expect(clock.remaining).toBeNear(2 - 1 / 6, 0.000001)
		expect(Clock.step(clock, copy, 0.5, true, random)).toBe(false)
		expect(clock.remaining).toBeNear(2 - 1 / 6, 0.000001)
		expect(Clock.step(clock, copy, 2 - 1 / 6 + 0.4, true, random)).toBe(true)
	end)
end)
