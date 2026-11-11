--!strict
-- Full native starts, source mechanics and personal challenge boundaries through production services.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Vagabond")
describe("Native Vagabond package", function()
	it("runs all29 original starts", function()
		f.starts(29)
	end)
	it("counts every equipped weapon for present sets and prevents duplicate families", function()
		f.start("Claw")
		expect(f.Stats.getStat(f.me, "armor")).toBe(-5)
		expect(f.Stats.getStat(f.me, "dodge")).toBe(-5)
		f.Stats.addStats(f.me, { luck = 10, harvesting = 10 })
		expect(f.Stats.getStat(f.me, "luck")).toBe(5)
		expect(f.Stats.getStat(f.me, "harvesting")).toBe(5)
		assert(f.Weapons.addWeapon(f.me, "Railgun", 1))
		assert(f.Weapons.addWeapon(f.me, "Torch", 1))
		expect(f.Weapons.addWeapon(f.me, "Claw", 2)).toBe(false)
		local Sets = require(f.Shared.Util.WeaponClasses)
		local counts = Sets.counts({ "Claw", "Railgun", "Torch" }, "Vagabond")
		for _, count in counts do
			expect(count).toBe(3)
		end
		expect(counts.Dread).toBe(nil)
		expect(f.Stats.getStat(f.me, "dodge")).toBe(1)
		local Rules = require(f.S.ShopService.ShopRules)
		local merge, blocked = Rules.weaponStatus("Claw", 1, { { id = "Claw", tier = 1 } }, 6, 4, "Vagabond")
		expect(merge).toBe(true)
		expect(blocked).toBe(false)
	end)
	it("requires six distinct simultaneous weapons rather than six copies", function()
		local A = require(f.Shared.Util.CharacterAccess)
		for _, w in f.Weapons.getWeapons(f.peer) do
			f.Weapons.removeWeapon(f.peer, w.uid)
		end
		for _, id in { "WatchmanPistol", "RattleRepeater", "ScatterBell", "ShrapnelOrgan", "WinterNeedle" } do
			assert(f.Weapons.addWeapon(f.peer, id, 1))
		end
		assert(f.Weapons.addWeapon(f.peer, "WatchmanPistol", 2))
		expect(A.characterUnlocked(f.Data.get(f.peer), "Vagabond")).toBe(false)
		for _, w in f.Weapons.getWeapons(f.peer) do
			if w.tier == 2 then
				f.Weapons.removeWeapon(f.peer, w.uid)
			end
		end
		assert(f.Weapons.addWeapon(f.peer, "GalvanicFork", 1))
		expect(A.characterUnlocked(f.Data.get(f.peer), "Vagabond")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
