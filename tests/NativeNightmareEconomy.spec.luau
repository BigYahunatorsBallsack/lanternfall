--!strict
-- Actual Nightmare shop rolls, refreshes and weapon recycling use the frozen server mode; no public mode unlock bypass is added.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Shop = require(f.S.ShopService)
local Schedule = require(f.Shared.Util.RunSchedule)
local originalOptions = f.Run.getRunOptions
f.Run.getRunOptions = function()
	local options = originalOptions()
	options.danger = 6
	return options
end
f.start(f.class.startWeapons[1])
f.Weapons.setPaused(true)
for _, player in { f.me, f.peer } do
	require(f.S.CombatService).protect(player, 10000)
end
local function shop()
	f.Run.skipTo(Schedule.wave(f.Run.getWave()).endsAt)
	f.world.advance(0.1)
	expect(f.Run.getPhase()).toBe("Shop")
end
local function nextWave()
	for _, player in { f.me, f.peer } do
		f.world.fireServerAs(player, "SetShopReady", true)
	end
	f.world.advance(0.3)
	f.Weapons.setPaused(true)
	require(f.S.SpawnDirector).setPaused(true)
	require(f.S.EnemySim).killAll()
end
local function expected(offer, factor)
	local base
	if offer.kind == "Weapon" then
		local prices = f.Config.Shop.weaponTierPrices[offer.itemId]
		base = if prices
			then prices[offer.tier]
			else f.Config.Shop.weaponPrices[offer.itemId] * f.Config.Shop.tierPriceFactors[offer.tier]
	else
		base = f.Config.Items.byId[offer.itemId].price
	end
	return math.max(1, math.floor((base + offer.priceWave + base * offer.priceWave * 0.11) * factor + 1e-9))
end
describe("Native Nightmare shop economy", function()
	it("prices every actual generated offer with original base inflation", function()
		while f.Run.getWave() < 10 do
			shop()
			nextWave()
		end
		shop()
		expect(#Shop.getOffers(f.me)).toBe(4)
		for _, offer in Shop.getOffers(f.me) do
			expect(offer.price).toBe(expected(offer, 1))
		end
	end)
	it("preserves mode inflation when Item Prices refresh a locked offer", function()
		local offer = Shop.getOffers(f.me)[1]
		f.world.fireServerAs(f.me, "LockShopOffer", offer.id, true)
		local wave = offer.priceWave
		assert(f.Stats.addStats(f.me, { itemPrice = 20 }))
		-- Lock updates use the existing real refresh path; bare stat updates do not independently resend this legacy shop.
		f.world.fireServerAs(f.me, "LockShopOffer", offer.id, false)
		f.world.fireServerAs(f.me, "LockShopOffer", offer.id, true)
		f.world.advance(0.2)
		for _, row in Shop.getOffers(f.me) do
			expect(row.price).toBe(expected(row, 1.2))
		end
		nextWave()
		shop()
		local kept
		for _, row in Shop.getOffers(f.me) do
			if row.id == offer.id then
				kept = row
			end
		end
		expect(kept ~= nil).toBe(true)
		expect(kept.priceWave).toBe(wave)
		expect(kept.price).toBe(expected(kept, 1.2))
	end)
	it("passes the frozen danger to actual weapon recycling", function()
		local original = require(f.S.ShopService.ShopRules).sellPrice
		local observed
		require(f.S.ShopService.ShopRules).sellPrice = function(a, b, c, d, e, g, danger)
			observed = danger
			return original(a, b, c, d, e, g, danger)
		end
		local weapon = f.Weapons.getWeapons(f.me)[1]
		f.world.fireServerAs(f.me, "SellWeapon", weapon.uid)
		expect(observed).toBe(6)
		require(f.S.ShopService.ShopRules).sellPrice = original
		expect(#f.world.errors).toBe(0)
	end)
	it("passes the same inflation mode into real crate recycling values", function()
		local Rules = require(f.S.ShopService.ShopRules)
		local original, observed = Rules.price, {}
		Rules.price = function(base, wave, factor, affected, danger)
			table.insert(observed, danger)
			return original(base, wave, factor, affected, danger)
		end
		assert(require(f.S.UpgradeService).addCrate(f.me))
		local crate = require(f.S.UpgradeService).getCrate(f.me)
		Rules.price = original
		expect(crate ~= nil).toBe(true)
		expect(#observed).toBe(2)
		for _, danger in observed do
			expect(danger).toBe(6)
		end
		expect(#f.world.errors).toBe(0)
	end)
end)
