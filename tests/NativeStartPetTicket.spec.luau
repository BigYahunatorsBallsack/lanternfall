--!strict
-- Optional pet picks survive hub tickets while legacy parsers and forged item ids remain safe.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Rules = require(Shared.Util.PlaceRules)
local Danger = require(Shared.Util.DangerRules)
local function ticket()
	return Rules.runTicket({
		partyId = "pet-party",
		leader = 1,
		group = { 1 },
		options = Danger.defaultOptions(),
		picks = { [1] = { classId = "BeastMaster", petId = "BotOMine" } },
	})
end
local function parse(data, petValidator)
	return assert(Rules.parseRunTicket(data, 1, 4, function(id)
		return Config.Classes[id] ~= nil
	end, function(id)
		return Config.Weapons[id] ~= nil
	end, petValidator))
end
local function pet(id)
	local item = Config.Items.byId[id]
	return item ~= nil and item.pet ~= nil
end
describe("Native pet teleport ticket", function()
	it("carries a separate validated pet field without encoding it as a weapon", function()
		local data = ticket()
		expect(data.picks["1"].petId).toBe("BotOMine")
		local parsed = parse(data, pet)
		expect(parsed.picks[1].petId).toBe("BotOMine")
		expect(parsed.picks[1].weaponId).toBe(nil)
		expect(parse(data, nil).picks[1].petId).toBe(nil)
	end)
	it("drops malformed and non-pet item ids before receiving-server class validation", function()
		for _, forged in { "WatchmanPistol", "MossWard", "Unknown", 12, {} } do
			local data = ticket()
			data.picks["1"].petId = forged
			expect(parse(data, pet).picks[1].petId).toBe(nil)
		end
	end)
end)
