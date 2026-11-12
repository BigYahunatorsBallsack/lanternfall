--!strict
-- Original Nightmare event slots: early groups, mutual exclusion, elite/horde avoidance, endless blocks and idempotency.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Rules = require(Shared.Util.NightmareRules)
local function first(minimum: number, _maximum: number): number
	return minimum
end
describe("Native Nightmare event plan", function()
	it("requires ten qualifying character/zone records, without treating Danger 4 as a qualifying win", function()
		local records = {}
		for index = 1, 9 do
			records[tostring(index)] = { [0] = 5 }
		end
		expect(Rules.unlocked(records)).toBe(false)
		records["tenth"] = { [0] = 4 }
		expect(Rules.unlocked(records)).toBe(false)
		records["tenth"][0] = 5
		expect(Rules.unlocked(records)).toBe(true)
	end)
	it("counts distinct zones of the same character while repeated wins occupy only one saved record", function()
		local records = {}
		for index = 1, 5 do
			records[tostring(index)] = { [0] = 5, [1] = 5 }
		end
		expect(Rules.unlocked(records)).toBe(true)
		records["5"][1] = nil
		expect(Rules.unlocked(records)).toBe(false)
		for _ = 1, 100 do
			records["5"][0] = 5
		end
		expect(Rules.unlocked(records)).toBe(false)
	end)
	it("does not add events or consume randomness below Nightmare 1", function()
		local plan = Rules.new()
		Rules.generate(plan, 5, 10, {}, true, function()
			error("Unexpected random draw")
		end)
		expect(#plan.events).toBe(0)
	end)
	it("matches the native initial draw order and avoids every elite or horde wave", function()
		local plan = Rules.new()
		local draws = 0
		Rules.generate(plan, 6, 10, { [11] = true, [14] = true, [17] = true }, true, function(minimum, _maximum)
			draws += 1
			return minimum
		end)
		expect(draws).toBe(10)
		expect(table.concat(plan.fog, ",")).toBe("5,12,13")
		expect(table.concat(plan.bullets, ",")).toBe("1,3,6,8,15,16,18")
		local seen = {}
		for _, event in plan.events do
			expect(seen[event.wave]).toBe(nil)
			expect(event.wave == 11 or event.wave == 14 or event.wave == 17).toBe(false)
			seen[event.wave] = true
		end
	end)
	it("preserves the projectile-off setting while still generating all three initial fog waves", function()
		local plan = Rules.new()
		Rules.generate(plan, 6, 10, {}, false, first)
		expect(table.concat(plan.fog, ",")).toBe("5,11,12")
		expect(#plan.bullets).toBe(0)
	end)
	it("keeps fog and bullets separate across every possible early fog choice", function()
		for _, offset in { 0, 1, 2 } do
			local plan, draws = Rules.new(), 0
			Rules.generate(plan, 6, 10, {}, true, function(minimum, maximum)
				draws += 1
				return if draws == 1 then minimum + offset else maximum
			end)
			for _, wave in plan.fog do
				expect(table.find(plan.bullets, wave)).toBe(nil)
			end
		end
	end)
	it(
		"appends five distinct endless events, excludes boss-wave boundaries and never rerolls a generated block",
		function()
			local plan = Rules.new()
			Rules.generate(plan, 6, 10, {}, true, first)
			Rules.generate(plan, 6, 20, { [21] = true, [24] = true, [27] = true }, true, first)
			expect(#plan.fog).toBe(5)
			expect(#plan.bullets).toBe(10)
			expect(table.find(plan.fog, 20)).toBe(nil)
			expect(table.find(plan.bullets, 30)).toBe(nil)
			Rules.generate(plan, 6, 20, {}, true, function()
				error("Block rerolled")
			end)
			expect(#plan.events).toBe(15)
		end
	)
end)
