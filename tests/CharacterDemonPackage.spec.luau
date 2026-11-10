--!strict
-- Native full starting choices, personal core mechanics and exact unlock boundary through production services.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Demon")
local Shop = require(f.S.ShopService)
describe("Native Demon package", function()
	it("runs all20 native starts", function()
		f.starts(20)
	end)
	it("converts material chunks before harvesting and purchases with MaxHP while rerolling with materials", function()
		f.start("FoundryKey")
		Shop.addShards(f.me, 103 - Shop.getShards(f.me))
		f.Run.skipTo(require(f.Shared.Util.RunSchedule).wave(f.Run.getWave()).endsAt)
		f.world.advance(0.1)
		expect(Shop.getShards(f.me)).toBe(64)
		expect(f.Stats.getStat(f.me, "maxHp")).toBe(13)
		local offer
		for _, row in Shop.getOffers(f.me) do
			if row.kind == "Weapon" and not row.blocked then
				offer = row
				break
			end
		end
		assert(offer)
		local Rules = require(f.S.ShopService.ShopRules)
		local expected = math.ceil(Rules.weaponPrice(offer.itemId, offer.tier, offer.priceWave, 1, "Demon") / 20)
		expect(offer.price).toBe(expected)
		local before = Shop.getShards(f.me)
		f.world.fireServerAs(f.me, "BuyShopOffer", offer.id)
		expect(f.Stats.getStat(f.me, "maxHp")).toBe(13 - expected)
		expect(Shop.getShards(f.me)).toBe(before)
		f.world.fireServerAs(f.me, "BuyShopOffer", "forged")
		expect(f.Stats.getStat(f.me, "maxHp")).toBe(13 - expected)
		f.world.fireServerAs(f.me, "RerollShop")
		expect(Shop.getShards(f.me)).toBe(before - Rules.rerollPrice(f.Run.getWave(), 0))
	end)
	it("requires a saved Danger5victory", function()
		local A = require(f.Shared.Util.CharacterAccess)
		f.Data.get(f.peer).stats.bestDanger = 4
		expect(A.characterUnlocked(f.Data.get(f.peer), "Demon")).toBe(false)
		f.Data.get(f.peer).stats.bestDanger = 5
		expect(A.characterUnlocked(f.Data.get(f.peer), "Demon")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
	it("refreshes personal HP affordability after permanent stat changes and rejects unaffordable offers", function()
		f.start("FoundryKey")
		local latest, peerLatest
		f.world.netWatch = function(name, player, payload)
			if name == "ShopState" then
				if player == f.me then
					latest = payload
				elseif player == f.peer then
					peerLatest = payload
				end
			end
		end
		f.Run.skipTo(require(f.Shared.Util.RunSchedule).wave(f.Run.getWave()).endsAt)
		f.world.advance(0.1)
		expect(latest.currencyKind).toBe("MaxHp")
		expect(peerLatest.currencyKind).toBe("Materials")
		local peerCurrency = peerLatest.currencyAmount
		f.Stats.addStats(f.me, { maxHp = 7 })
		expect(latest.currencyAmount).toBe(math.floor(f.Stats.getStat(f.me, "maxHp")))
		expect(peerLatest.currencyAmount).toBe(peerCurrency)
		local offer = assert(Shop.getOffers(f.me)[1])
		f.Stats.addStats(f.me, { maxHp = -f.Stats.getStat(f.me, "maxHp") })
		local wallet = Shop.getShards(f.me)
		f.world.fireServerAs(f.me, "BuyShopOffer", offer.id)
		expect(offer.sold).toBe(false)
		expect(Shop.getShards(f.me)).toBe(wallet)
		expect(#f.world.errors).toBe(0)
		f.world.netWatch = nil
	end)
end)
