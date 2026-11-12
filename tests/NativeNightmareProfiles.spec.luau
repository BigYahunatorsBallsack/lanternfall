--!strict
-- Native Nightmare access uses saved, completed character/zone results; legacy aggregate records cannot invent missing zones.
loadHelper("tests/helpers/RobloxMock.luau")
local S = game:GetService("ServerScriptService").Server.Services
local Template = require(S.PlayerDataService.ProfileTemplate)
local Migrations = require(S.PlayerDataService.Migrations)
local Records = require(S.PlayerDataService.ProfileRecords)
local function finish(data, classId: string, changes)
	local run =
		{ won = true, wave = 20, danger = 5, zoneId = 0, classId = classId, kills = 0, bossKills = 2, seconds = 1200 }
	for key, value in changes or {} do
		run[key] = value
	end
	Records.applyRun(data, run)
end
local characters = { "Baby", "Jack", "Vampire", "BeastMaster", "Soldier", "Speedy", "Vagabond", "King", "Loud", "Old" }
describe("Native Nightmare saved progress", function()
	it("migrates v13 additively without assigning aggregate victories to a guessed zone", function()
		local data = Template.new()
		data.schemaVersion, data.nativeZoneBest, data.embers = 13, nil, 42
		data.characterStats.Baby = { runs = 20, wins = 20, bestWave = 20, bestDanger = 5 }
		Migrations.run(data, Template.SCHEMA_VERSION)
		expect(data.schemaVersion).toBe(14)
		expect(next(data.nativeZoneBest)).toBe(nil)
		expect(data.characterStats.Baby.wins).toBe(20)
		expect(data.embers).toBe(42)
		data.nativeZoneBest.Baby = { ["0"] = 5 }
		Migrations.run(data, Template.SCHEMA_VERSION)
		expect(data.nativeZoneBest.Baby["0"]).toBe(5)
	end)
	it("does not qualify defeat, partial victory, tutorial, unknown character or absent/unknown zone", function()
		for _, changes in
			{ { won = false }, { wave = 19 }, { firstNight = true }, { classId = "Unknown" }, { zoneId = 99 } }
		do
			local data = Template.new()
			finish(data, "Baby", changes)
			expect(next(data.nativeZoneBest)).toBe(nil)
		end
		local data = Template.new()
		Records.applyRun(
			data,
			{ won = true, wave = 20, danger = 5, classId = "Baby", kills = 0, bossKills = 2, seconds = 1200 }
		)
		expect(next(data.nativeZoneBest)).toBe(nil)
	end)
	it("requires ten distinct saved results and never counts repeated wins twice", function()
		local data = Template.new()
		for index = 1, 9 do
			finish(data, characters[index])
		end
		expect(Records.nightmareUnlocked(data)).toBe(false)
		for _ = 1, 10 do
			finish(data, "Baby")
		end
		expect(Records.nightmareUnlocked(data)).toBe(false)
		finish(data, characters[10])
		expect(Records.nightmareUnlocked(data)).toBe(true)
		expect(Records.info(data, "Memory").nativeNightmareUnlocked).toBe(true)
	end)
	it("stores separate canonical string zone keys and keeps the highest win for each pair", function()
		local data = Template.new()
		for index = 1, 5 do
			finish(data, characters[index], { zoneId = 0 })
			finish(data, characters[index], { zoneId = 1, danger = 4 })
		end
		expect(Records.nightmareUnlocked(data)).toBe(false)
		for index = 1, 5 do
			finish(data, characters[index], { zoneId = 1 })
		end
		expect(Records.nightmareUnlocked(data)).toBe(true)
		finish(data, "Baby", { danger = 0 })
		expect(data.nativeZoneBest.Baby["0"]).toBe(5)
		expect(data.nativeZoneBest.Baby["1"]).toBe(5)
	end)
	it(
		"ignores unknown identities and malformed optional saved entries instead of inflating the prerequisite",
		function()
			local data = Template.new()
			for index = 1, 9 do
				finish(data, characters[index])
			end
			data.nativeZoneBest.Unknown = { ["0"] = 5, ["1"] = 5, ["2"] = 5 }
			data.nativeZoneBest.Baby["99"] = 5
			data.nativeZoneBest.Old = 5 :: any
			expect(Records.nightmareUnlocked(data)).toBe(false)
			data.nativeZoneBest.Old = { ["0"] = 5.1 }
			expect(Records.nightmareUnlocked(data)).toBe(false)
			finish(data, "Old")
			expect(Records.nightmareUnlocked(data)).toBe(true)
			expect(data.nativeZoneBest.Old["0"]).toBe(5)
		end
	)
end)
