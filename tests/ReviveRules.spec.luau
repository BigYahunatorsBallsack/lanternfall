-- Unit tests for the down timer and revive rules (src/shared/Util/ReviveRules.luau, WP11).

local ReviveRules = require(game:GetService("ReplicatedStorage").Shared.Util.ReviveRules)

local SETTINGS = {
	downTimerSeconds = 30,
	reviveSeconds = 3,
	reviveDecaySeconds = 3,
	downTimerPausesWhileReviving = true,
}

describe("ReviveRules", function()
	it("starts with the full timer and no progress", function()
		local entry = ReviveRules.new(SETTINGS)
		expect(entry.timeLeft).toBe(30)
		expect(entry.progress).toBe(0)
	end)

	it("is out once the timer runs out", function()
		local entry = ReviveRules.new(SETTINGS)
		expect(ReviveRules.step(entry, 29, false, SETTINGS)).toBe(nil)
		expect(entry.timeLeft).toBeNear(1)
		expect(ReviveRules.step(entry, 1, false, SETTINGS)).toBe("Out")
	end)

	it("revives after reviveSeconds with a teammate next to them, timer paused", function()
		local entry = ReviveRules.new(SETTINGS)
		expect(ReviveRules.step(entry, 2, true, SETTINGS)).toBe(nil)
		expect(entry.progress).toBeNear(2 / 3)
		expect(entry.timeLeft).toBe(30)
		expect(ReviveRules.step(entry, 1, true, SETTINGS)).toBe("Revived")
	end)

	it("drains a started revive when the teammate walks away", function()
		local entry = ReviveRules.new(SETTINGS)
		ReviveRules.step(entry, 1.5, true, SETTINGS)
		ReviveRules.step(entry, 1, false, SETTINGS)
		expect(entry.progress).toBeNear(1 / 6)
		expect(entry.timeLeft).toBeNear(29)
		ReviveRules.step(entry, 5, false, SETTINGS)
		expect(entry.progress).toBe(0)
	end)

	it("lets the timer run on while reviving when the switch is off", function()
		local settings = table.clone(SETTINGS)
		settings.downTimerPausesWhileReviving = false
		local entry = ReviveRules.new(settings)
		entry.timeLeft = 2
		expect(ReviveRules.step(entry, 2, true, settings)).toBe("Out")
	end)

	it("a full revive beats the timer in the same step", function()
		local settings = table.clone(SETTINGS)
		settings.downTimerPausesWhileReviving = false
		local entry = ReviveRules.new(settings)
		entry.timeLeft = 1
		entry.progress = 0.9
		expect(ReviveRules.step(entry, 1, true, settings)).toBe("Revived")
	end)

	it("projects an entry forward without changing it", function()
		local entry = ReviveRules.new(SETTINGS)
		local later = ReviveRules.project(entry, 10, false, SETTINGS)
		expect(later.timeLeft).toBeNear(20)
		expect(entry.timeLeft).toBe(30)
		expect(ReviveRules.project(entry, -1, false, SETTINGS).timeLeft).toBe(30)
	end)
end)
