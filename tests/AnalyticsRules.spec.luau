-- Unit tests of AnalyticsService/AnalyticsRules (Paket 20): funnel order, where returning players start, the event
-- budget, path names and custom fields.

loadHelper("tests/helpers/RobloxMock.luau")

local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local AnalyticsRules = require(ServerScriptService.Server.Services.AnalyticsService.AnalyticsRules)

local function names(list): string
	local out = {}
	for _, entry in list do
		table.insert(out, `{entry.step}:{entry.name}`)
	end
	return table.concat(out, ",")
end

describe("onboarding funnel", function()
	it("sends steps in order and holds a step reached early", function()
		local funnel = AnalyticsRules.newFunnel()
		expect(names(AnalyticsRules.reach(funnel, "Joined"))).toBe("1:Joined")
		expect(names(AnalyticsRules.reach(funnel, "FirstKill"))).toBe("")
		expect(names(AnalyticsRules.reach(funnel, "Moved"))).toBe("2:Moved,3:FirstKill")
		expect(names(AnalyticsRules.reach(funnel, "Moved"))).toBe("")
		expect(names(AnalyticsRules.reach(funnel, "Unknown"))).toBe("")
		expect(funnel.logged).toBe(3)
	end)

	it("starts returning players after the first run and leaves veterans out", function()
		expect(AnalyticsRules.startStep(0)).toBe(0)
		expect(AnalyticsRules.startStep(1)).toBe(AnalyticsRules.stepIndex("FirstRunEnded"))
		expect(AnalyticsRules.startStep(2)).toBe(nil)
		local funnel = AnalyticsRules.newFunnel(AnalyticsRules.startStep(1))
		expect(names(AnalyticsRules.reach(funnel, "Joined"))).toBe("")
		expect(names(AnalyticsRules.reach(funnel, "BackInLobby"))).toBe("7:BackInLobby")
	end)
end)

describe("budget", function()
	it("allows the per-minute limit and keeps a reserve from low priority events", function()
		local budget = AnalyticsRules.newBudget(0)
		local limit = AnalyticsRules.perMinute(1)
		expect(limit).toBe(Config.Analytics.budget.perMinute + Config.Analytics.budget.perMinutePerPlayer)
		local lowCap = math.floor(limit * (1 - Config.Analytics.budget.lowReserveShare))
		local low = 0
		while AnalyticsRules.take(budget, 1, 1, "low") do
			low += 1
		end
		expect(low).toBe(lowCap)
		local high = 0
		while AnalyticsRules.take(budget, 2, 1, "high") do
			high += 1
		end
		expect(high).toBe(limit - lowCap)
		expect(AnalyticsRules.take(budget, 61, 1, "low")).toBe(true) -- a new minute
	end)
end)

describe("names and fields", function()
	it("names progression paths and danger fields", function()
		local options = { danger = 3, endless = false, enemyHp = 100, enemyDamage = 100, enemySpeed = 100 }
		expect(AnalyticsRules.pathName(options)).toBe("Danger3")
		expect(AnalyticsRules.dangerField(options)).toBe("D3")
		options.endless = true
		expect(AnalyticsRules.pathName(options)).toBe("Danger3Endless")
		expect(AnalyticsRules.dangerField(options)).toBe("D3E")
		options.firstNight = true
		expect(AnalyticsRules.pathName(options)).toBe("FirstNight")
	end)

	it("builds up to three custom fields as strings", function()
		local fields = AnalyticsRules.fields({ "Contact", 7, string.rep("x", 80) }) :: any
		expect(fields.CustomField01).toBe("Contact")
		expect(fields.CustomField02).toBe("7")
		expect(#fields.CustomField03).toBe(Config.Analytics.maxFieldLength)
		expect(AnalyticsRules.fields({})).toBe(nil)
	end)

	it("takes a recent hit as the cause of a down", function()
		expect(AnalyticsRules.downCause({ kind = "Shot", time = 10 }, 10.1)).toBe("Shot")
		expect(AnalyticsRules.downCause({ kind = "Shot", time = 10 }, 12)).toBe("Other")
		expect(AnalyticsRules.downCause(nil, 12)).toBe("Other")
	end)
end)
