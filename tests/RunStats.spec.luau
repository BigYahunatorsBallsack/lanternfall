-- Unit tests for run statistics (RunStatsService/Tally): kills, team level per minute, damage taken, downs, the
-- results screen summary and the playtest log lines.

local Services = game:GetService("ServerScriptService").Server.Services
local Tally = require(Services.RunStatsService.Tally)

local function results(outcome, seconds)
	return { outcome = outcome, survivedSeconds = seconds, difficulty = "Normal", players = {} }
end

describe("Tally", function()
	it("counts kills by enemy type", function()
		local tally = Tally.new()
		tally:recordKill("Shadeling")
		tally:recordKill("Shadeling")
		tally:recordKill("Brute")
		expect(tally.kills).toBe(3)
		expect(tally.killsByType.Shadeling).toBe(2)
		expect(tally.killsByType.Brute).toBe(1)
	end)

	it("knows the team level at any time of the run, also across skipped levels", function()
		local tally = Tally.new()
		expect(tally:levelAt(0)).toBe(1)
		tally:recordLevel(2, 10)
		tally:recordLevel(3, 50)
		tally:recordLevel(6, 70) -- admin skip: 4 and 5 count as reached at the same time
		expect(tally:levelAt(9)).toBe(1)
		expect(tally:levelAt(60)).toBe(3)
		expect(tally:levelAt(70)).toBe(6)
		expect(tally:getLevel()).toBe(6)
	end)

	it("adds damage taken and downs per player and ignores unknown players", function()
		local tally = Tally.new()
		tally:addPlayer(1, "Ana", "BladeWarden")
		tally:recordDamageTaken(1, 5)
		tally:recordDamageTaken(1, 12)
		tally:recordDamageTaken(99, 50)
		tally:recordDown(1, 125)
		tally:recordDown(1, 300)
		local ana = tally:getPlayer(1)
		expect(ana.damageTaken).toBe(17)
		expect(ana.downs).toBe(2)
		expect(ana.firstDownAt).toBe(125)
	end)

	it("builds the results summary from the weapons each player carried", function()
		local tally = Tally.new()
		tally:addPlayer(1, "Ana", "BladeWarden")
		tally:addPlayer(2, "Ben", "SparkMage")
		tally:recordKill("Shadeling")
		tally:recordDamageTaken(2, 9.6)
		local summary = tally:summary({
			[1] = {
				weapons = {
					{ id = "OrbitBlades", level = 3, damage = 100.4, kills = 7 },
					{ id = "SparkBolt", level = 1, damage = 20, kills = 1 },
				},
				items = {},
			},
		})
		expect(summary.teamLevel).toBe(1)
		expect(summary.kills).toBe(1)
		expect(summary.players[1].kills).toBe(8)
		expect(summary.players[1].damageDealt).toBe(120)
		expect(summary.players[2].kills).toBe(0) -- left before the end: no loadout
		expect(summary.players[2].damageTaken).toBe(10)
	end)

	it("writes readable log lines with the level per minute and every build", function()
		local tally = Tally.new()
		tally:addPlayer(1, "Ana", "BladeWarden")
		tally:recordKill("Brute")
		tally:recordLevel(2, 30)
		tally:recordLevel(3, 100)
		tally:recordDown(1, 130)
		local lines = tally:logLines(results("Defeat", 130), {
			[1] = {
				weapons = { { id = "OrbitBlades", level = 2, damage = 64, kills = 1 } },
				items = { { id = "Might", count = 2 } },
			},
		})
		expect(lines[1]).toBe("Defeat after 02:10 · Normal · 1 player(s) · team level 3 · 1 kills (Brute 1)")
		expect(lines[2]).toBe("Level per minute: 1:00 L2 · 2:00 L3")
		expect(lines[3]).toBe("Ana (Blade Warden): 1 kills, 64 damage, took 0, down 1x, first down at 02:10")
		expect(lines[4]).toBe("  Weapons: Orbit Blades LV2 64 dmg/1 kills")
		expect(lines[5]).toBe("  Items: Might x2")
	end)
end)
