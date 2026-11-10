--!strict
-- Native upgraded bait groups recur independently of acquisition encounters and preserve native count/timing geometry.
loadHelper("tests/helpers/RobloxMock.luau")
local S = game:GetService("ServerScriptService").Server.Services.SpawnDirector
local Fishing = require(S.FishingGroups)
local Rules = require(S.SpawnRules)
describe("Native upgraded Baits", function()
	it("generates a minimum one recurring group and uses10/15bait integer milestones", function()
		expect(#Fishing.groups(0, function()
			return 0
		end)).toBe(0)
		local a = Fishing.groups(1, function()
			return 0
		end)
		expect(#a).toBe(1)
		expect(a[1].timing).toBe(15)
		expect(a[1].interval).toBe(6)
		expect(a[1].units[1].min).toBe(1)
		expect(a[1].units[1].max).toBe(1)
		local b = Fishing.groups(30, function()
			return 0.99
		end)
		expect(#b).toBe(3)
		expect(b[1].units[1].min).toBe(3)
		expect(b[1].units[1].max).toBe(6)
		expect(b[1].edge).toBe(true)
		expect(b[1].area).toBe(-1)
		expect(b[2].timing).toBe(17)
		expect(b[3].timing).toBe(34)
	end)
	it("runs the first group at15seconds and repeats it after its chosen interval", function()
		local timers = Rules.newTimers(Fishing.groups(1, function()
			return 0
		end))
		expect(#Rules.due(timers, 14, function()
			return 0
		end)).toBe(0)
		expect(#Rules.due(timers, 15, function()
			return 0
		end)).toBe(1)
		expect(#Rules.due(timers, 20, function()
			return 0
		end)).toBe(0)
		expect(#Rules.due(timers, 21, function()
			return 0
		end)).toBe(1)
	end)
	it("starts Explorer's neutral group within five seconds and preserves its original repeat clock", function()
		local group = table.clone(Fishing.groups(1, function()
			return 0
		end)[1])
		group.neutral = true
		group.timing = 20
		local normal = Rules.newTimers({ group })
		expect(#Rules.due(normal, 0, function()
			return 0
		end, false)).toBe(0)
		local explorer = Rules.newTimers({ group })
		expect(#Rules.due(explorer, 0, function()
			return 0
		end, true)).toBe(1)
		expect(#Rules.due(explorer, 25, function()
			return 0
		end, true)).toBe(0)
		expect(#Rules.due(explorer, 26, function()
			return 0
		end, true)).toBe(1)
	end)
end)
