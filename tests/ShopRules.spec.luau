-- Unit tests for the shop formulas (ShopService/ShopRules) against Config.Shop, Config.Items and DESIGN.md section 3.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local ShopRules = require(game:GetService("ServerScriptService").Server.Services.ShopService.ShopRules)

local WEAPONS = { "BoomerangAxe", "ChainLightning", "OrbitBlades", "Shockwave", "SparkBolt", "ThornTrail" }

local function lcg(seed)
	local state = seed or 0
	return function()
		state = (state * 9301 + 49297) % 233280
		return state / 233280
	end
end

local function params(overrides)
	local counter = 0
	local base = {
		wave = 1,
		luck = 0,
		weapons = WEAPONS,
		ownedWeapons = {},
		maxWeapons = 6,
		maxLevel = 5,
		ownedItems = {},
		nextId = function()
			counter += 1
			return tostring(counter)
		end,
		random = lcg(0),
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

	it("fills every slot with different things and unique ids at their prices", function()
		local offers = ShopRules.roll(params({ wave = 7 }))
		expect(#offers).toBe(Config.Shop.slots)
		local seen, ids = {}, {}
		for _, offer in offers do
			expect(seen[offer.itemId]).toBe(nil)
			expect(ids[offer.id]).toBe(nil)
			seen[offer.itemId] = true
			ids[offer.id] = true
			expect(offer.sold).toBe(false)
			expect(#offer.id <= 32).toBe(true)
			if offer.kind == "Item" then
				local item = Config.Items.byId[offer.itemId]
				expect(offer.tier).toBe(item.tier)
				expect(offer.price).toBe(ShopRules.price(item.price, 7))
			else
				expect(offer.price).toBe(ShopRules.price(Config.Shop.weaponPrices[offer.itemId], 7))
			end
		end
	end)

	it("guarantees two weapons after waves 1-2 and one after waves 3-5", function()
		for seed = 1, 20 do
			expect(count(ShopRules.roll(params({ wave = 2, random = lcg(seed) })), "Weapon") >= 2).toBe(true)
			expect(count(ShopRules.roll(params({ wave = 5, random = lcg(seed) })), "Weapon") >= 1).toBe(true)
		end
		expect(ShopRules.guaranteedWeapons(6)).toBe(0)
	end)

	it("offers owned weapons one level higher and no new ones once the slots are full", function()
		local owned = {
			OrbitBlades = 2,
			SparkBolt = 5,
			Shockwave = 1,
			ThornTrail = 1,
			ChainLightning = 1,
			BoomerangAxe = 1,
		}
		for seed = 1, 10 do
			for _, offer in ShopRules.roll(params({ ownedWeapons = owned, wave = 1, random = lcg(seed) })) do
				if offer.kind == "Weapon" then
					expect(offer.itemId ~= "SparkBolt").toBe(true) -- max level
					expect(offer.level).toBe(owned[offer.itemId] + 1)
					expect(offer.isNew).toBe(false)
				end
			end
		end
	end)

	it("offers items again and again, counting what the player owns", function()
		local owned = {}
		for _, item in Config.Items.list do
			owned[item.id] = 3
		end
		local offers = ShopRules.roll(params({ wave = 9, ownedItems = owned, weapons = {} }))
		expect(#offers).toBe(Config.Shop.slots)
		for _, offer in offers do
			local item = Config.Items.byId[offer.itemId]
			expect(offer.kind).toBe("Item")
			expect(item.limit == nil).toBe(true) -- limited items are at their limit
			expect(offer.level).toBe(4)
			expect(offer.isNew).toBe(false)
		end
	end)

	it("only sells Common items after wave 1 and rarer ones later and with Luck", function()
		local function rareShare(wave, luck)
			local rare, total = 0, 0
			for seed = 1, 60 do
				for _, offer in ShopRules.roll(params({ wave = wave, luck = luck, weapons = {}, random = lcg(seed) })) do
					total += 1
					if offer.tier >= 2 then
						rare += 1
					end
				end
			end
			return rare / total
		end
		expect(rareShare(1, 0)).toBe(0)
		expect(rareShare(4, 0) < rareShare(10, 0)).toBe(true)
		expect(rareShare(4, 0) < rareShare(4, 100)).toBe(true)
	end)

	it("gives elite chests at least an Uncommon item", function()
		for seed = 1, 20 do
			local itemId = ShopRules.chestItem(1, 0, {}, lcg(seed))
			expect(itemId ~= nil).toBe(true)
			expect(Config.Items.byId[itemId :: string].tier >= Config.Items.chestMinTier).toBe(true)
		end
	end)
end)
