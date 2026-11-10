--!strict
-- Native full starting choices, personal core mechanics and exact unlock boundary through production services.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Fisherman")
local Shop = require(f.S.ShopService)
describe("Native Fisherman package", function()
	it("runs all30 native starts", function()
		f.starts(30)
	end)
	it("guarantees a one-material Bait in every shop roll and applies personal2Harvesting per Bait", function()
		f.start("RitualDirk")
		expect(f.Stats.getStat(f.me, "maxHp")).toBe(15)
		expect(f.Stats.getStat(f.me, "harvesting")).toBe(20)
		f.Run.skipTo(require(f.Shared.Util.RunSchedule).wave(f.Run.getWave()).endsAt)
		f.world.advance(0.1)
		local function bait()
			for _, offer in Shop.getOffers(f.me) do
				if offer.itemId == "BloodLure" and not offer.sold then
					return offer
				end
			end
			error("missing guaranteed Bait")
		end
		expect(bait().price).toBe(1)
		local h = f.Stats.getStat(f.me, "harvesting")
		local d = f.Stats.getStat(f.me, "damage")
		f.world.fireServerAs(f.me, "BuyShopOffer", bait().id)
		expect(f.Stats.getStat(f.me, "harvesting")).toBe(h + 2)
		expect(f.Stats.getStat(f.me, "damage")).toBe(d + 8)
		assert(Shop.rerollFree(f.me))
		expect(bait().price).toBe(1)
	end)
	it("requires two Baits owned by the same profile in one run", function()
		local A = require(f.Shared.Util.CharacterAccess)
		assert(f.Stats.addItem(f.peer, "BloodLure"))
		expect(A.characterUnlocked(f.Data.get(f.peer), "Fisherman")).toBe(false)
		assert(f.Stats.addItem(f.peer, "BloodLure"))
		expect(A.characterUnlocked(f.Data.get(f.peer), "Fisherman")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
