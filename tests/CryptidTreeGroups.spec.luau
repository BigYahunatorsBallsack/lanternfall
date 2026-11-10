--!strict
-- Cryptid's tree guarantees exercise the consolidated native SpawnRules after main's full spawn-group integration.
loadHelper("tests/helpers/RobloxMock.luau")
local Rules = require(game:GetService("ServerScriptService").Server.Services.SpawnDirector.SpawnRules)
local function treeGroup(wave)
	for _, group in Rules.groupsFor(wave, 0) do
		for _, unit in group.units do
			if unit.enemy == "Tree" then
				return group, unit
			end
		end
	end
	return nil, nil
end
describe("Cryptid consolidated native tree groups", function()
	it("applies Trees before the original 33 percent unit chance", function()
		local group, unit = treeGroup(1)
		assert(group and unit)
		local function number(trees, roll, rest)
			return Rules.unitCount(unit, group, 1, 0, trees, 1, roll, rest)
		end
		expect(number(0, 0, 0.3)).toBe(1)
		expect(number(0, 0, 0.4)).toBe(0)
		expect(number(6, 0, 0.3)).toBe(3)
		expect(number(6, 0, 0.4)).toBe(2)
		expect(number(6, 0.9, 0.6)).toBe(3)
		expect(number(-5, 0, 0) <= 0).toBe(true) -- a nonpositive loop count creates no trees
	end)
	it("starts at ten seconds, repeats at twenty and thirty, and runs through wave99 only", function()
		local group = assert(treeGroup(1))
		local timers = Rules.newTimers({ group })
		local seconds = {}
		for second = 0, 30 do
			if #Rules.due(timers, second, function()
				return 0
			end) > 0 then
				table.insert(seconds, second)
			end
		end
		expect(table.concat(seconds, ",")).toBe("10,20,30")
		expect(treeGroup(99) ~= nil).toBe(true)
		expect(treeGroup(100)).toBe(nil)
		expect(treeGroup(101)).toBe(nil)
	end)
	it("retains native Looter scheduling in the same consolidated group engine", function()
		local loot, looterUnit
		for _, group in Rules.groupsFor(1, 0) do
			for _, unit in group.units do
				if unit.enemy == "Looter" then
					loot, looterUnit = group, unit
				end
			end
		end
		assert(loot)
		expect(loot.loot).toBe(true)
		expect(loot.timing).toBe(25)
		expect(loot.interval).toBe(15)
		expect(loot.chance).toBe(1)
		expect(looterUnit.chance).toBe(0.1)
		local timers = Rules.newTimers({ loot })
		local fired = {}
		for second = 0, 60 do
			if #Rules.due(timers, second, function()
				return 0
			end) > 0 then
				table.insert(fired, second)
			end
		end
		expect(table.concat(fired, ",")).toBe("25,40,55")
	end)
end)
