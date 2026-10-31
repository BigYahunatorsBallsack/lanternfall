-- Unit tests for saved player data (Paket 12): schema migrations, what a run adds to the record, the lobby summary
-- and the Output dump (src/server/Services/PlayerDataService/Migrations, ProfileRecords, ProfileTemplate).

local Services = game:GetService("ServerScriptService").Server.Services
local Migrations = require(Services.PlayerDataService.Migrations)
local ProfileRecords = require(Services.PlayerDataService.ProfileRecords)
local ProfileTemplate = require(Services.PlayerDataService.ProfileTemplate)

-- What a v1 profile (before Paket 12) looked like.
local function v1Data()
	return {
		schemaVersion = 1,
		embers = 40,
		talents = { toughness = 1, power = 0, reach = 0, greed = 0, rescuer = 0, rerolls = 0 },
		classes = { "BladeWarden", "SparkMage" },
		difficultyUnlocked = "Normal",
		cosmetics = { owned = {}, equipped = {} },
		stats = { runs = 3, kills = 900, bossKills = 1, bestTime = 640 },
		quests = { day = "", list = {} },
		streak = { lastLogin = 0, count = 0 },
		pass = { season = 1, xp = 0, premium = false, claimed = {} },
		receipts = { ["abc"] = true },
	}
end

local function run(overrides)
	local record =
		{ won = false, wave = 7, danger = 0, classId = "SparkMage", kills = 120, bossKills = 0, seconds = 300 }
	for key, value in overrides or {} do
		record[key] = value
	end
	return record
end

describe("Migrations", function()
	it("has a step for every older schema version", function()
		for version = 1, ProfileTemplate.SCHEMA_VERSION - 1 do
			expect(Migrations.steps[version] ~= nil).toBe(true)
		end
	end)

	it("upgrades v1 data to the current schema and keeps every old value", function()
		local data = v1Data()
		expect(Migrations.run(data, ProfileTemplate.SCHEMA_VERSION)).toBe(1)
		expect(data.schemaVersion).toBe(ProfileTemplate.SCHEMA_VERSION)
		expect(data.stats.runs).toBe(3)
		expect(data.stats.kills).toBe(900)
		expect(data.stats.bestTime).toBe(640)
		expect(data.stats.wins).toBe(0)
		expect(data.stats.bestWave).toBe(0)
		expect(data.stats.bestDanger).toBe(-1)
		expect(next(data.characterStats)).toBe(nil)
		expect(data.embers).toBe(40)
		expect(data.talents.toughness).toBe(1)
		expect(data.receipts[1]).toBe("abc") -- since v5 a list of PurchaseIds (Paket 16)
	end)

	it("turns v4 receipts into a list and adds the purchase fields (v5, Paket 16)", function()
		local data = ProfileTemplate.new() :: any
		data.schemaVersion = 4
		data.receipts = { ["p2"] = true, ["p1"] = true }
		data.stats.embersBought = nil
		data.stats.purchases = nil
		data.tokens = nil
		data.passCache = nil
		data.boost = nil
		expect(Migrations.run(data, ProfileTemplate.SCHEMA_VERSION)).toBe(4)
		expect(#data.receipts).toBe(2)
		expect(data.receipts[1]).toBe("p1")
		expect(data.receipts[2]).toBe("p2")
		expect(data.stats.embersBought).toBe(0)
		expect(data.stats.purchases).toBe(0)
		expect(data.tokens.revives).toBe(0)
		expect(data.tokens.rerolls).toBe(0)
		expect(next(data.passCache)).toBe(nil)
		expect(data.boost.untilTime).toBe(0)
		expect(data.boost.by).toBe("")
	end)

	it("treats data without a version as v1", function()
		local data = v1Data()
		data.schemaVersion = nil
		expect(Migrations.run(data, ProfileTemplate.SCHEMA_VERSION)).toBe(1)
		expect(data.schemaVersion).toBe(ProfileTemplate.SCHEMA_VERSION)
	end)

	it("leaves current and newer data alone", function()
		local data = ProfileTemplate.new()
		expect(Migrations.run(data, ProfileTemplate.SCHEMA_VERSION)).toBe(ProfileTemplate.SCHEMA_VERSION)
		local newer = ProfileTemplate.new()
		newer.schemaVersion = ProfileTemplate.SCHEMA_VERSION + 1
		expect(Migrations.run(newer, ProfileTemplate.SCHEMA_VERSION)).toBe(ProfileTemplate.SCHEMA_VERSION + 1)
		expect(newer.schemaVersion).toBe(ProfileTemplate.SCHEMA_VERSION + 1)
	end)

	it("migrated data has every key of a fresh profile", function()
		local data = v1Data()
		Migrations.run(data, ProfileTemplate.SCHEMA_VERSION)
		local function check(template, target, path)
			for key, value in template do
				expect(`{path}{key}:{target[key] ~= nil}`).toBe(`{path}{key}:true`)
				if type(value) == "table" and next(value) ~= nil and type(key) == "string" then
					check(value, target[key], `{path}{key}.`)
				end
			end
		end
		check(ProfileTemplate.new(), data, "")
	end)
end)

describe("ProfileRecords", function()
	it("counts a lost run", function()
		local data = ProfileTemplate.new()
		ProfileRecords.applyRun(data, run())
		expect(data.stats.runs).toBe(1)
		expect(data.stats.wins).toBe(0)
		expect(data.stats.kills).toBe(120)
		expect(data.stats.bestWave).toBe(7)
		expect(data.stats.bestTime).toBe(300)
		expect(data.stats.bestDanger).toBe(-1)
		local character = data.characterStats.SparkMage
		expect(character.runs).toBe(1)
		expect(character.wins).toBe(0)
		expect(character.bestWave).toBe(7)
		expect(character.bestDanger).toBe(-1)
	end)

	it("keeps the best values and the highest danger won", function()
		local data = ProfileTemplate.new()
		ProfileRecords.applyRun(
			data,
			run({ won = true, wave = 20, danger = 3, kills = 2000, bossKills = 1, seconds = 812.6 })
		)
		ProfileRecords.applyRun(data, run({ won = true, wave = 20, danger = 1 }))
		ProfileRecords.applyRun(data, run({ wave = 4, danger = 5, classId = "BladeWarden" }))
		expect(data.stats.runs).toBe(3)
		expect(data.stats.wins).toBe(2)
		expect(data.stats.bossKills).toBe(1)
		expect(data.stats.bestWave).toBe(20)
		expect(data.stats.bestTime).toBe(812)
		expect(data.stats.bestDanger).toBe(3) -- the danger 5 run was lost
		expect(data.characterStats.SparkMage.wins).toBe(2)
		expect(data.characterStats.SparkMage.bestDanger).toBe(3)
		expect(data.characterStats.BladeWarden.runs).toBe(1)
		expect(data.characterStats.BladeWarden.bestWave).toBe(4)
	end)

	it("skips the character record without a class", function()
		local data = ProfileTemplate.new()
		ProfileRecords.applyRun(data, run({ classId = "" }))
		expect(data.stats.runs).toBe(1)
		expect(next(data.characterStats)).toBe(nil)
	end)

	it("sums up the record for the lobby", function()
		local data = ProfileTemplate.new()
		ProfileRecords.applyRun(data, run({ won = true, wave = 20, danger = 2, bossKills = 1 }))
		local info = ProfileRecords.info(data, "Mock")
		expect(info.saveMode).toBe("Mock")
		expect(info.schemaVersion).toBe(ProfileTemplate.SCHEMA_VERSION)
		expect(info.runs).toBe(1)
		expect(info.wins).toBe(1)
		expect(info.bestWave).toBe(20)
		expect(info.bestDanger).toBe(2)
		expect(info.bossKills).toBe(1)
	end)

	it("dumps every value as sorted lines", function()
		local lines = ProfileRecords.dump({ b = 2, a = { y = true, x = {} } })
		expect(table.concat(lines, "|")).toBe("a:|  x = {}|  y = true|b = 2")
	end)
end)
