--!strict
-- Native starting alternatives, personal production-service rules and original challenge boundary.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("DuelMaestro")
describe("Native Gladiator package", function()
	it("adopts all20 original melee starts while retaining DuelMaestro", function()
		expect(f.wasLegacy).toBe(true)
		expect(f.class.displayName).toBe("Gladiator")
		f.starts(20)
	end)
	it("counts weapon families rather than tiers and recomputes after removal", function()
		f.start("RitualDirk")
		expect(f.Stats.getStat(f.me, "meleeDamage")).toBe(5)
		expect(f.Stats.getStat(f.me, "luck")).toBe(-30)
		expect(f.Stats.getStat(f.me, "attackSpeed")).toBe(-20)
		assert(f.Weapons.addWeapon(f.me, "RitualDirk", 2))
		expect(f.Stats.getStat(f.me, "attackSpeed")).toBe(-20)
		assert(f.Weapons.addWeapon(f.me, "BrassKnuckles", 1))
		expect(f.Stats.getStat(f.me, "attackSpeed")).toBe(0)
		expect(f.Weapons.addWeapon(f.me, "WatchmanPistol", 1)).toBe(false)
		for _, w in f.Weapons.getWeapons(f.me) do
			if w.id == "RitualDirk" then
				assert(f.Weapons.removeWeapon(f.me, w.uid))
			end
		end
		expect(f.Stats.getStat(f.me, "attackSpeed")).toBe(-20)
		expect(f.Stats.getStat(f.peer, "attackSpeed")).toBe(0)
	end)
	it("opens after20000 personal lifetime kills", function()
		local A = require(f.Shared.Util.CharacterAccess)
		f.Data.get(f.peer).nativeCounts.enemiesKilled = 19999
		expect(A.characterUnlocked(f.Data.get(f.peer), "DuelMaestro")).toBe(false)
		local Enemy = require(f.S.EnemySim)
		local id = assert(Enemy.spawn("Shadeling", 40, 40, 1, 0, nil, nil, 0))
		Enemy.damage(id, 10000, f.peer)
		expect(A.characterUnlocked(f.Data.get(f.peer), "DuelMaestro")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
