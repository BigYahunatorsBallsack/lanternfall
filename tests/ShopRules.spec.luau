-- Unit tests for the shop formulas (ShopService/ShopRules) against Config.Shop and DESIGN.md section 3.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local ShopRules = require(game:GetService("ServerScriptService").Server.Services.ShopService.ShopRules)

local WEAPONS = { "BoomerangAxe", "ChainLightning", "OrbitBlades", "Shockwave", "SparkBolt", "ThornTrail" }
local PASSIVES = { "Armor", "Focus", "Haste", "Magnet", "Might", "Vitality" }

local function params(overrides)
	local counter = 0
	local seed = 0
	local base = {
		wave = 1,
		weapons = WEAPONS,
		passives = PASSIVES,
		ownedWeapons = {},
		ownedPassives = {},
		maxWeapons = 4,
		maxPassives = 4,
		maxLevel = 5,
		nextId = function()
			counter += 1
			return tostring(counter)
		end,
		random = function()
			seed = (seed * 9301 + 49297) % 233280
			return seed / 233280
		end,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function count(offers, kind)
	local n = 0
	for _, offer in offers do
		if offer.kind == kind then
			n += 1
		end
	end
	return n
end

describe("ShopRules", function()
	it("prices like Brotato: base + wave + 10 % of base per wave", function()
		expect(ShopRules.price(20, 1)).toBe(23) -- the SMG example: base 20 in the first shop
		expect(ShopRules.price(20, 5)).toBe(35)
		expect(ShopRules.price(10, 11)).toBe(32)
		expect(ShopRules.price(0, 0)).toBe(1) -- never free
	end)

	it("raises the reroll price by 40 % of the wave per reroll", function()
		expect(ShopRules.rerollPrice(5, 0)).toBe(5) -- floor(3.75) + 2
		expect(ShopRules.rerollPrice(5, 1)).toBe(7)
		expect(ShopRules.rerollPrice(1, 0)).toBe(1) -- floor(0.75) + at least 1
		expect(ShopRules.rerollPrice(1, 3)).toBe(4)
		expect(ShopRules.rerollPrice(10, 0)).toBe(11)
	end)

	it("fills every slot with different items and unique ids", function()
		local offers = ShopRules.roll(params())
		expect(#offers).toBe(Config.Shop.slots)
		local seen, ids = {}, {}
		for _, offer in offers do
			expect(seen[offer.itemId]).toBe(nil)
			expect(ids[offer.id]).toBe(nil)
			seen[offer.itemId] = true
			ids[offer.id] = true
			expect(offer.sold).toBe(false)
			expect(#offer.id <= 32).toBe(true)
			expect(offer.price).toBe(ShopRules.price(Config.Shop.basePrices[offer.itemId], 1))
		end
	end)

	it("guarantees two weapons after waves 1-2 and one after waves 3-5", function()
		for seed = 1, 20 do
			local p = params({ wave = 2 })
			for _ = 1, seed do
				p.random()
			end
			expect(count(ShopRules.roll(p), "Weapon") >= 2).toBe(true)
			p.wave = 5
			expect(count(ShopRules.roll(p), "Weapon") >= 1).toBe(true)
		end
		expect(ShopRules.guaranteedWeapons(6)).toBe(0)
	end)

	it("offers owned items one level higher and nothing new once the slots are full", function()
		local owned = { OrbitBlades = 2, SparkBolt = 5, Shockwave = 1, ThornTrail = 1 }
		local offers = ShopRules.roll(params({ ownedWeapons = owned, wave = 1 }))
		for _, offer in offers do
			if offer.kind == "Weapon" then
				expect(owned[offer.itemId] ~= nil).toBe(true)
				expect(offer.itemId ~= "SparkBolt").toBe(true) -- max level
				expect(offer.level).toBe(owned[offer.itemId] + 1)
				expect(offer.isNew).toBe(false)
			end
		end
	end)

	it("returns fewer offers when nothing else can be bought", function()
		local maxed = {}
		for _, id in PASSIVES do
			maxed[id] = 5
		end
		local offers = ShopRules.roll(params({
			passives = PASSIVES,
			ownedPassives = maxed,
			weapons = { "SparkBolt" },
			ownedWeapons = { SparkBolt = 4 },
		}))
		expect(#offers).toBe(1)
		expect(offers[1].itemId).toBe("SparkBolt")
	end)
end)
