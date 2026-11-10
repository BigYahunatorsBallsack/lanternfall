--!strict
-- Complete native starting choices, personal package rules and original unlock challenge in production services.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Engineer")
describe("Native Engineer package", function()
	it("runs all7 choices plus the guaranteed additional Wrench", function()
		expect(#f.class.startWeapons).toBe(7)
		for _, id in f.class.startWeapons do
			f.start(id)
			local w = f.Weapons.getWeapons(f.me)
			expect(#w).toBe(2)
			expect(w[1].id).toBe(id)
			expect(w[2].id).toBe("FoundryKey")
			expect(w[1].tier).toBe(f.class.startWeaponTiers[id])
			expect(w[2].tier).toBe(1)
		end
	end)
	it("scales Engineering gains by25% and damage gains by-50%", function()
		f.start("Crowbar")
		expect(f.Stats.getStat(f.me, "engineering")).toBe(13.75)
		f.Stats.addStats(
			f.me,
			{ engineering = 4, meleeDamage = 10, rangedDamage = 10, elementalDamage = 10, damage = 10 }
		)
		expect(f.Stats.getStat(f.me, "engineering")).toBe(18.75)
		for _, stat in { "meleeDamage", "rangedDamage", "elementalDamage", "damage" } do
			expect(f.Stats.getStat(f.me, stat)).toBe(5)
		end
	end)
	it("counts five personal turret sources, excluding Gardens/mines/traps and foreign turrets", function()
		local A = require(f.Shared.Util.CharacterAccess)
		assert(f.Stats.addItem(f.peer, "MoonGarden"))
		assert(f.Stats.addItem(f.peer, "RuneMine"))
		for _ = 1, 4 do
			assert(f.Stats.addItem(f.peer, "BrassSentry"))
		end
		expect(A.characterUnlocked(f.Data.get(f.peer), "Engineer")).toBe(false)
		for _ = 1, 10 do
			f.Weapons.NativeStructureRequested:Fire(f.peer, "BloodTurret", Vector3.new(0, 0, 0))
		end
		f.world.advance(0.1)
		expect(A.characterUnlocked(f.Data.get(f.peer), "Engineer")).toBe(false)
		assert(f.Stats.addItem(f.peer, "MercySentry"))
		expect(A.characterUnlocked(f.Data.get(f.peer), "Engineer")).toBe(false)
		f.nextWave()
		expect(A.characterUnlocked(f.Data.get(f.peer), "Engineer")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
