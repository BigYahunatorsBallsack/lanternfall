--!strict
-- Native starting alternatives, personal production-service rules and original challenge boundary.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("SoleConductor")
describe("Native One Armed package", function()
	it("adopts all31 native starts while retaining SoleConductor", function()
		expect(f.wasLegacy).toBe(true)
		expect(f.class.displayName).toBe("One Armed")
		f.starts(31)
	end)
	it("enforces one weapon, adds three set counts and doubles every listed damage gain", function()
		f.start("Claw")
		expect(f.Stats.getStat(f.me, "attackSpeed")).toBe(200)
		expect(f.Weapons.getMaxWeapons(f.me)).toBe(1)
		expect(f.Weapons.addWeapon(f.me, "RitualDirk", 1)).toBe(false)
		local counts = require(f.Shared.Util.WeaponClasses).counts({ "Claw" }, "SoleConductor")
		expect(counts.Brawl).toBe(4)
		expect(f.Stats.getStat(f.me, "dodge")).toBe(9)
		for _, id in
			{
				"damage",
				"meleeDamage",
				"rangedDamage",
				"elementalDamage",
				"explosionDamage",
				"piercingDamage",
				"bounceDamage",
				"eliteDamage",
			}
		do
			local before = f.Stats.getStat(f.me, id)
			f.Stats.addStats(f.me, { [id] = 3 })
			expect(f.Stats.getStat(f.me, id)).toBe(before + 6)
		end
	end)
	it("requires an actual saved Danger0victory", function()
		local A = require(f.Shared.Util.CharacterAccess)
		f.Data.get(f.peer).stats.bestDanger = -1
		expect(A.characterUnlocked(f.Data.get(f.peer), "SoleConductor")).toBe(false)
		f.Data.get(f.peer).stats.bestDanger = 0
		expect(A.characterUnlocked(f.Data.get(f.peer), "SoleConductor")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
