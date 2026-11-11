--!strict
-- Native starting alternatives, personal production-service rules and original challenge boundary.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Knight")
describe("Native Knight package", function()
	it("runs all21 native tierII melee starting choices", function()
		f.starts(21)
		for _, tier in f.class.startWeaponTiers do
			expect(tier).toBe(2)
		end
	end)
	it("converts permanent and temporary armor, applies gains and enforces tier/kind in the actual shop", function()
		f.start("RitualDirk")
		expect(f.Stats.getStat(f.me, "armor")).toBe(3)
		expect(f.Stats.getStat(f.me, "meleeDamage")).toBe(6)
		f.Stats.addStats(f.me, { armor = 2, attackSpeed = 10, harvesting = 10 })
		expect(f.Stats.getStat(f.me, "meleeDamage")).toBe(10)
		expect(f.Stats.getStat(f.me, "attackSpeed")).toBe(5)
		expect(f.Stats.getStat(f.me, "harvesting")).toBe(2)
		f.Stats.setDynamic(f.me, { armor = 4 })
		expect(f.Stats.getStat(f.me, "meleeDamage")).toBe(18)
		f.Stats.setDynamic(f.me, {})
		expect(f.Weapons.addWeapon(f.me, "RitualDirk", 1)).toBe(false)
		expect(f.Weapons.addWeapon(f.me, "WatchmanPistol", 2)).toBe(false)
		f.Run.skipTo(require(f.Shared.Util.RunSchedule).wave(f.Run.getWave()).endsAt)
		f.world.advance(0.1)
		local Shop = require(f.S.ShopService)
		local weapon
		for _, offer in Shop.getOffers(f.me) do
			if offer.kind == "Weapon" then
				expect(offer.tier >= 2).toBe(true)
				expect(f.Config.Weapons[offer.itemId].kind).toBe("Melee")
				if not offer.blocked then
					weapon = offer
				end
			end
		end
		assert(weapon)
		Shop.addShards(f.me, 100)
		local before = #f.Weapons.getWeapons(f.me)
		f.world.fireServerAs(f.me, "BuyShopOffer", weapon.id)
		expect(#f.Weapons.getWeapons(f.me)).toBe(before + 1)
	end)
	it("requires a saved Danger4victory", function()
		local A = require(f.Shared.Util.CharacterAccess)
		f.Data.get(f.peer).stats.bestDanger = 3
		expect(A.characterUnlocked(f.Data.get(f.peer), "Knight")).toBe(false)
		f.Data.get(f.peer).stats.bestDanger = 4
		expect(A.characterUnlocked(f.Data.get(f.peer), "Knight")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
