--!strict
-- Schema13 adds a zero personal tree counter without inventing historical progress or replacing existing counts.
local T = require(game:GetService("ServerScriptService").Server.Services.PlayerDataService.ProfileTemplate)
local M = require(game:GetService("ServerScriptService").Server.Services.PlayerDataService.Migrations)
describe("Native tree counter migration", function()
	it("preserves all v12 counters and adds zero trees", function()
		local data =
			{ schemaVersion = 12, nativeCounts = { materialsCollected = 123, enemiesKilled = 456, digSitesDug = 7 } }
		M.run(data, T.SCHEMA_VERSION)
		expect(data.schemaVersion).toBe(13)
		expect(data.nativeCounts.treesKilled).toBe(0)
		expect(data.nativeCounts.materialsCollected).toBe(123)
		expect(data.nativeCounts.enemiesKilled).toBe(456)
		expect(data.nativeCounts.digSitesDug).toBe(7)
	end)
end)
