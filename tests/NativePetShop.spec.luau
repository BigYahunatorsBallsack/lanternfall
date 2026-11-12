--!strict
-- Native boosted wanted tags use the ten-percent shop branch, with strict boundaries and unchanged normal odds.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Rules = require(game:GetService("ServerScriptService").Server.Services.ShopService.ShopRules)
local original = Rules.pickItem
local tagged = false
Rules.pickItem = function(tier, owned, avoid, random, tags, ...)
	tagged = tagged or tags ~= nil
	return original(tier, owned, avoid, random, tags, ...)
end
local function roll(classId: string, chance: number): boolean
	tagged = false
	Rules.roll({
		classId = classId,
		wave = 1,
		luck = 0,
		weapons = {},
		ownedWeapons = {},
		maxWeapons = 6,
		maxTier = 4,
		ownedItems = {},
		nextId = function()
			return "test"
		end,
		random = function()
			return chance
		end,
	})
	return tagged
end
describe("Native pet shop", function()
	it("doubles the wanted-tag branch to ten percent without changing the strict comparison", function()
		expect(#Config.Classes.BeastMaster.wantedTags > 0).toBe(true)
		expect(roll("BeastMaster", 0.099)).toBe(true)
		expect(roll("BeastMaster", 0.1)).toBe(false)
		-- Supply an ordinary tag to the legacy class solely to inspect its normal probability branch.
		local tags = Config.Classes.NightWatch.wantedTags
		Config.Classes.NightWatch.wantedTags = { "pet" }
		expect(roll("NightWatch", 0.049)).toBe(true)
		expect(roll("NightWatch", 0.05)).toBe(false)
		Config.Classes.NightWatch.wantedTags = tags
	end)
end)
