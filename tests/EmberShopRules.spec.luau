-- Unit tests for the Ember shop rules (Paket 17, Util/EmberShopRules): character and cosmetic prices, owning,
-- buying in place, VIP-only cosmetics, equipping and which cosmetic a slot shows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local EmberShopRules = require(ReplicatedStorage.Shared.Util.EmberShopRules)

local Cosmetics = Config.Cosmetics

local function wallet(embers)
	return {
		embers = embers or 0,
		achievements = {},
		classes = { "BladeWarden", "SparkMage" },
		cosmetics = { owned = {}, equipped = {} },
	}
end

local function firstPaid(list)
	for _, entry in list do
		if not entry.vip and entry.price > 0 then
			return entry
		end
	end
	error("no paid cosmetic")
end

describe("Ember shop rules", function()
	it("prices only locked characters that are listed", function()
		local price = EmberShopRules.characterPrice("ManyHands")
		expect(price).toBe(Config.Progress.characterPrices.ManyHands)
		expect(EmberShopRules.characterPrice("BladeWarden")).toBe(nil)
		local _, reason = EmberShopRules.price("Character", "BladeWarden", wallet(99999), false)
		expect(reason).toBe("notForSale")
		_, reason = EmberShopRules.price("Character", "Nobody", wallet(99999), false)
		expect(reason).toBe("notForSale")
		_, reason = EmberShopRules.price("Weapon", "SparkBolt", wallet(99999), false)
		expect(reason).toBe("notForSale")
	end)

	it("buys a character in place and then owns it", function()
		local price = Config.Progress.characterPrices.ManyHands
		local poor = wallet(price - 1)
		local cost, reason = EmberShopRules.buy("Character", "ManyHands", poor, false)
		expect(cost).toBe(nil)
		expect(reason).toBe("notEnough")
		expect(poor.embers).toBe(price - 1)

		local rich = wallet(price + 5)
		cost, reason = EmberShopRules.buy("Character", "ManyHands", rich, false)
		expect(cost).toBe(price)
		expect(reason).toBe(nil)
		expect(rich.embers).toBe(5)
		expect(table.find(rich.classes, "ManyHands") ~= nil).toBe(true)
		expect(EmberShopRules.ownsCharacter("ManyHands", rich)).toBe(true)
		_, reason = EmberShopRules.buy("Character", "ManyHands", rich, false)
		expect(reason).toBe("alreadyOwned")
	end)

	it("does not sell a character its achievement already unlocked", function()
		local done = wallet(99999)
		done.achievements.DeepNight = true -- unlocks Many Hands
		local _, reason = EmberShopRules.price("Character", "ManyHands", done, false)
		expect(reason).toBe("alreadyOwned")
	end)

	it("buys cosmetics once and keeps free ones owned by everyone", function()
		local paid = firstPaid(Cosmetics.trails)
		local purse = wallet(paid.price)
		expect(EmberShopRules.ownsCosmetic(paid.id, purse.cosmetics.owned, false)).toBe(false)
		local cost = EmberShopRules.buy("Cosmetic", paid.id, purse, false)
		expect(cost).toBe(paid.price)
		expect(purse.embers).toBe(0)
		expect(EmberShopRules.ownsCosmetic(paid.id, purse.cosmetics.owned, false)).toBe(true)
		local _, reason = EmberShopRules.buy("Cosmetic", paid.id, purse, false)
		expect(reason).toBe("alreadyOwned")
		expect(EmberShopRules.ownsCosmetic(Cosmetics.defaults.Lantern, {}, false)).toBe(true)
		_, reason = EmberShopRules.price("Cosmetic", "NoSuchThing", purse, false)
		expect(reason).toBe("notForSale")
	end)

	it("never sells VIP cosmetics for Embers, VIP owns them", function()
		local vipTrail = Cosmetics.vipDefaults.Trail
		local _, reason = EmberShopRules.buy("Cosmetic", vipTrail, wallet(99999), false)
		expect(reason).toBe("vipOnly")
		expect(EmberShopRules.ownsCosmetic(vipTrail, {}, true)).toBe(true)
		expect(EmberShopRules.ownsCosmetic(vipTrail, { vipTrail }, false)).toBe(false)
	end)

	it("equips only owned cosmetics of the right slot", function()
		local paid = firstPaid(Cosmetics.lanterns)
		expect(EmberShopRules.canEquip("Lantern", paid.id, {}, false)).toBe(false)
		expect(EmberShopRules.canEquip("Lantern", paid.id, { paid.id }, false)).toBe(true)
		expect(EmberShopRules.canEquip("Trail", paid.id, { paid.id }, false)).toBe(false)
		expect(EmberShopRules.canEquip("Lantern", Cosmetics.none, {}, false)).toBe(true)
		expect(EmberShopRules.canEquip("Hat", Cosmetics.none, {}, false)).toBe(false)
	end)

	it("shows the pick, the default, the VIP default or nothing", function()
		local paid = firstPaid(Cosmetics.lanterns)
		expect(EmberShopRules.shown("Lantern", {}, {}, false)).toBe(Cosmetics.defaults.Lantern)
		expect(EmberShopRules.shown("Trail", {}, {}, false)).toBe(nil)
		expect(EmberShopRules.shown("Lantern", {}, {}, true)).toBe(Cosmetics.vipDefaults.Lantern)
		expect(EmberShopRules.shown("Trail", {}, {}, true)).toBe(Cosmetics.vipDefaults.Trail)
		expect(EmberShopRules.shown("Lantern", { Lantern = paid.id }, { paid.id }, true)).toBe(paid.id)
		expect(EmberShopRules.shown("Lantern", { Lantern = Cosmetics.none }, {}, true)).toBe(nil)
		-- the VIP lantern picked, pass gone: back to the default
		local vipLantern = Cosmetics.vipDefaults.Lantern
		expect(EmberShopRules.shown("Lantern", { Lantern = vipLantern }, {}, false)).toBe(Cosmetics.defaults.Lantern)
	end)

	it("lists every cosmetic id for the remote", function()
		local ids = EmberShopRules.ids()
		expect(#ids).toBe(#Cosmetics.lanterns + #Cosmetics.trails)
		for _, id in ids do
			expect(EmberShopRules.cosmetic(id) ~= nil).toBe(true)
		end
	end)
end)
