--!strict
-- Native character modifiers must reach existing ranged weapons and the matching shop preview.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Stats = require(game:GetService("ServerScriptService").Server.Services.WeaponService.WeaponStats)
local Preview = require(folderProxy("src/client/UI", "UI").OfferText)

describe("Native existing ranged weapons", function()
	it("applies source aiming and Renegade modifiers at every supported tier", function()
		for id, expected in
			{
				WatchmanPistol = { accuracy = { 0.9, 0.9, 0.9, 1 }, count = { 1, 1, 1, 1 }, spread = 0 },
				ScatterBell = { accuracy = { 0.9, 0.95, 1, 1 }, count = { 4, 4, 4, 6 }, spread = 0.5 },
			}
		do
			for tier = 1, 4 do
				local sheet = { nativePackage = 1, accuracy = -50, projectiles = 2, piercing = 1 }
				local stats = Stats.compute(Config.Weapons[id], tier, sheet, nil, 0)
				local preview = Preview.stats(id, tier, sheet)
				expect(stats.nativeAccuracy).toBe(expected.accuracy[tier] - 0.5)
				expect(stats.count).toBe(expected.count[tier] + 2)
				expect(stats.nativeSpread).toBe(expected.spread + 0.2)
				for _, key in { "nativeAccuracy", "count", "nativeSpread", "pierce" } do
					expect(preview[key]).toBe(stats[key])
				end
			end
		end
	end)
	it("retains the existing public legacy profile until native adoption", function()
		local stats = Stats.compute(Config.Weapons.WatchmanPistol, 1, {}, nil, 0)
		expect(stats.nativeAccuracy).toBe(nil)
		expect(stats.count).toBe(1)
	end)
end)
