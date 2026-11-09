--!strict
-- Arms Dealer discounts the base before inflation; personal minimum stock counts locked weapon offers.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Rules = require(game:GetService("ServerScriptService").Server.Services.ShopService.ShopRules)
local Stats = require(Shared.Util.StatMath)
describe("Arms Dealer shop rules", function()
	it("discounts only the original weapon base, before wave additions and Item Prices", function()
		expect(Rules.weaponPrice("WatchmanPistol", 1, 10, 1, "ArmsDealer")).toBe(11)
		expect(Rules.weaponPrice("WatchmanPistol", 1, 10, 1.2, "ArmsDealer")).toBe(13)
		expect(Rules.weaponPrice("WatchmanPistol", 1, 10, 1)).toBe(30)
	end)
	it("uses original endless inflation and removes all price modifiers from the endless recycling basis", function()
		-- Wave30 endless factor1.1: (10*0.05 +30 +10*0.05*3)*1.2*1.22 =46.848.
		expect(Rules.weaponPrice("WatchmanPistol", 1, 30, 1.2, "ArmsDealer")).toBe(46)
		expect(Rules.sellPrice("WatchmanPistol", 1, 30, 0, 1.2, "ArmsDealer")).toBe(17)
		expect(Stats.priceFactor(-100)).toBe(0)
		expect(Rules.price(100, 10, Stats.priceFactor(-100))).toBe(1)
	end)
	it("guarantees a weapon after wave five without duplicating a locked weapon", function()
		local counter = 0
		local function params(keep)
			return {
				classId = "ArmsDealer",
				wave = 10,
				luck = 0,
				priceFactor = 1,
				weapons = { "WatchmanPistol" },
				ownedWeapons = {},
				maxWeapons = 6,
				maxTier = 4,
				ownedItems = {},
				keep = keep or {},
				random = function()
					return 0.99
				end,
				nextId = function()
					counter += 1
					return tostring(counter)
				end,
			}
		end
		local offers = Rules.roll(params())
		local n = 0
		for _, offer in offers do
			if offer.kind == "Weapon" then
				n += 1
			end
		end
		expect(n >= 1).toBe(true)
		local locked = offers[1]
		locked.locked = true
		local again = Rules.roll(params({ locked }))
		expect(again[1]).toBe(locked)
		n = 0
		for _, offer in again do
			if offer.kind == "Weapon" then
				n += 1
			end
		end
		expect(n).toBe(1)
	end)
end)
