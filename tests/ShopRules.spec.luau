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
		maxTier = 4,
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
				expect(offer.price).toBe(ShopRules.weaponPrice(offer.itemId, offer.tier, 7))
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

	it("prices weapon tiers from the tier I price and sells for a quarter", function()
		local base = Config.Shop.weaponPrices.SparkBolt
		expect(ShopRules.weaponPrice("SparkBolt", 1, 3)).toBe(ShopRules.price(base, 3))
		expect(ShopRules.weaponPrice("SparkBolt", 3, 3)).toBe(
			ShopRules.price(base * Config.Shop.tierPriceFactors[3], 3)
		)
		expect(ShopRules.weaponPrice("SparkBolt", 2, 3) > ShopRules.weaponPrice("SparkBolt", 1, 3)).toBe(true)
		expect(ShopRules.sellPrice("SparkBolt", 2, 3)).toBe(math.floor(ShopRules.weaponPrice("SparkBolt", 2, 3) * 0.25))
	end)

	it("rolls weapon tiers like item rarities: only tier I after wave 1", function()
		for seed = 1, 20 do
			for _, offer in ShopRules.roll(params({ wave = 1, random = lcg(seed) })) do
				if offer.kind == "Weapon" then
					expect(offer.tier).toBe(1)
				end
			end
		end
		local higher = false
		for seed = 1, 60 do
			for _, offer in ShopRules.roll(params({ wave = 15, luck = 50, random = lcg(seed) })) do
				higher = higher or (offer.kind == "Weapon" and offer.tier > 1)
			end
		end
		expect(higher).toBe(true)
	end)

	it("picks weapons from the pool: owned ones, then the same class, then any", function()
		local owned = { { id = "OrbitBlades", tier = 1 } }
		local function first(roll)
			local offers = ShopRules.roll(params({
				ownedWeapons = owned,
				random = function()
					return roll
				end,
			}))
			return offers[1]
		end
		expect(first(0.1).itemId).toBe("OrbitBlades") -- below 20 %: an owned weapon
		expect(first(0.1).isNew).toBe(false)
		expect(first(0.1).count).toBe(1)
		local sameClass = first(0.3).itemId -- 20-35 %: a melee weapon like the owned one
		expect(Config.Weapons[sameClass].class).toBe("Melee")
		expect(first(0.9).isNew).toBe(true) -- otherwise any weapon; 0.9 picks one near the end of the list
	end)

	it("merges a weapon bought with full slots into a copy of the same tier, else blocks it", function()
		local full = {}
		for index = 1, 6 do
			full[index] = { id = WEAPONS[index], tier = if index == 1 then 2 else 1 }
		end
		expect(select(1, ShopRules.weaponStatus("BoomerangAxe", 2, full, 6, 4))).toBe(true)
		expect(select(2, ShopRules.weaponStatus("BoomerangAxe", 1, full, 6, 4))).toBe(true)
		expect(select(2, ShopRules.weaponStatus("SparkBolt", 1, { full[1] }, 6, 4))).toBe(false) -- free slot
		full[1] = { id = "BoomerangAxe", tier = 4 }
		expect(select(2, ShopRules.weaponStatus("BoomerangAxe", 4, full, 6, 4))).toBe(true) -- IV does not merge
		full[1] = { id = "BoomerangAxe", tier = 2, evolution = "X" }
		expect(select(2, ShopRules.weaponStatus("BoomerangAxe", 2, full, 6, 4))).toBe(true) -- evolved ones neither
	end)

	it("keeps locked offers first at their price and does not repeat the previous roll", function()
		local before = ShopRules.roll(params({ wave = 8, random = lcg(3) }))
		local locked = before[2]
		locked.locked = true
		locked.price = 1
		local previous = {}
		for _, offer in before do
			previous[offer.itemId] = true
		end
		for seed = 1, 20 do
			local after =
				ShopRules.roll(params({ wave = 8, keep = { locked }, previous = previous, random = lcg(seed) }))
			expect(after[1]).toBe(locked)
			expect(after[1].price).toBe(1)
			expect(#after).toBe(Config.Shop.slots)
			for index = 2, #after do
				expect(previous[after[index].itemId]).toBe(nil)
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
			expect(offer.count).toBe(4)
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

	it("lowers prices by Item Prices, keeps a locked offer's wave and adds Sell Value to sales", function()
		expect(ShopRules.price(20, 1, 0.75)).toBe(math.floor((20 + 1 + 2) * 0.75))
		expect(ShopRules.price(1, 0, 0)).toBe(1)
		local offers = ShopRules.roll(params({ wave = 3, priceFactor = 0.9 }))
		for _, offer in offers do
			expect(offer.priceWave).toBe(3)
			expect(offer.price).toBe(ShopRules.offerPrice(offer, 0.9))
			expect(offer.price <= ShopRules.offerPrice(offer, 1)).toBe(true)
		end
		local locked = table.clone(offers[1])
		locked.priceWave = 1 -- rolled after wave 1, still in the shop after wave 6
		expect(ShopRules.offerPrice(locked, 1) < ShopRules.offerPrice(offers[1], 1)).toBe(true)
		local price = ShopRules.weaponPrice("SparkBolt", 1, 5)
		expect(ShopRules.sellPrice("SparkBolt", 1, 5)).toBe(math.floor(price * Config.Shop.sellShare))
		expect(ShopRules.sellPrice("SparkBolt", 1, 5, 35)).toBe(math.floor(price * (Config.Shop.sellShare + 0.35)))
	end)

	it("gives elite chests at least an Uncommon item", function()
		for seed = 1, 20 do
			local itemId = ShopRules.chestItem(1, 0, {}, lcg(seed))
			expect(itemId ~= nil).toBe(true)
			expect(Config.Items.byId[itemId :: string].tier >= Config.Items.chestMinTier).toBe(true)
		end
	end)
end)
