--!strict
-- Original Nightmare enemy factors and base shop inflation, including unaffected recycling values; public mode selection remains gated.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Danger = require(Shared.Util.DangerRules)
local Shop = require(game:GetService("ServerScriptService").Server.Services.ShopService.ShopRules)
describe("Native Nightmare modifiers", function()
	it("replaces Danger5 enemy factors with original plus60 HP/damage and plus10 speed", function()
		local options = Danger.defaultOptions()
		options.danger = 6
		local hp, damage, speed = Danger.multipliers(options, 1)
		expect(hp).toBe(1.6)
		expect(damage).toBe(1.6)
		expect(speed).toBe(1.1)
		options.enemyHp, options.enemyDamage, options.enemySpeed = 75, 50, 25
		hp, damage, speed = Danger.multipliers(options, 1)
		expect(hp).toBeNear(1.2)
		expect(damage).toBe(0.8)
		expect(speed).toBe(0.275)
	end)
	it("changes base wave inflation from point1 to point11 before Item Prices and final truncation", function()
		expect(Shop.price(100, 10, 1, nil, 5)).toBe(210)
		expect(Shop.price(100, 10, 1, nil, 6)).toBe(220)
		expect(Shop.price(100, 10, 0.5, nil, 6)).toBe(110)
		-- affected=false suppresses Item Prices and endless factors, not the native base inflation modifier.
		expect(Shop.price(100, 10, 0.5, false, 6)).toBe(220)
		-- Wave30 endlessFactor1.1: unaffected basis460; affected price floor(460*1.22)=561.
		expect(Shop.price(100, 30, 0.5, false, 6)).toBe(460)
		expect(Shop.price(100, 30, 1, nil, 6)).toBe(561)
	end)
	it("propagates the original inflation into weapon and offer price paths", function()
		-- Existing tier-I base20: 20 +10 +20*10*.11 =52.
		local C = require(Shared.Config.Shop)
		local base = C.weaponTierPrices.RattleRepeater and C.weaponTierPrices.RattleRepeater[1]
			or C.weaponPrices.RattleRepeater
		expect(base).toBe(20)
		local expected = 52
		expect(Shop.weaponPrice("RattleRepeater", 1, 10, 1, nil, nil, 6)).toBe(expected)
		expect(Shop.offerPrice({ kind = "Weapon", itemId = "RattleRepeater", tier = 1, priceWave = 10 }, 1, nil, 6)).toBe(
			expected
		)
	end)
end)
