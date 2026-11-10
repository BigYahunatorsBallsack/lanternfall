--!strict
-- Native lifetime digging is additive and cannot be reconstructed from unrelated old counters.
loadHelper("tests/helpers/RobloxMock.luau")
local S = game:GetService("ServerScriptService").Server.Services.PlayerDataService
local Migrations = require(S.Migrations)
local Template = require(S.ProfileTemplate)
describe("Digging profile migration", function()
	it("preserves old lifetime counts and adds a zero digging count", function()
		local data = Template.new()
		data.schemaVersion = 11
		data.nativeCounts = { materialsCollected = 123, enemiesKilled = 456 }
		Migrations.run(data, 12)
		expect(data.schemaVersion).toBe(12)
		expect(data.nativeCounts.materialsCollected).toBe(123)
		expect(data.nativeCounts.enemiesKilled).toBe(456)
		expect(data.nativeCounts.digSitesDug).toBe(0)
	end)
end)
