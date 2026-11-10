--!strict
-- Native full starting choices, personal core mechanics and exact unlock boundary through production services.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("ManyHands")
describe("Native Multitasker package", function()
	it("preserves ManyHands and atomically adopts all44 original starts", function()
		expect(f.wasLegacy).toBe(true)
		expect(f.class.displayName).toBe("Multitasker")
		f.starts(44)
	end)
	it("permits twelve slots and applies-5Damage per equipped weapon", function()
		f.start("BrassKnuckles")
		expect(f.Stats.getStat(f.me, "damage")).toBe(15)
		for _ = 1, 11 do
			assert(f.Weapons.addWeapon(f.me, "BrassKnuckles", 1))
		end
		expect(#f.Weapons.getWeapons(f.me)).toBe(12)
		expect(f.Weapons.addWeapon(f.me, "BrassKnuckles", 1)).toBe(false)
		expect(f.Stats.getStat(f.me, "damage")).toBe(-40)
		expect(f.Stats.getStat(f.peer, "damage")).toBe(0)
	end)
	it("unlocks after5000 personally collected material objects", function()
		local A = require(f.Shared.Util.CharacterAccess)
		f.Data.get(f.peer).nativeCounts.materialsCollected = 4999
		expect(A.characterUnlocked(f.Data.get(f.peer), "ManyHands")).toBe(false)
		f.Data.observeNativeMaterials(f.peer, 1)
		expect(A.characterUnlocked(f.Data.get(f.peer), "ManyHands")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
