--!strict
-- Full native starts, source mechanics and personal challenge boundaries through production services.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Soldier")
describe("Native Soldier package", function()
	it("runs all24 original starts", function()
		f.starts(24)
	end)
	it("keeps original flat combat stats while blocking new attacks during movement", function()
		f.start("WatchmanPistol")
		expect(f.Stats.getStat(f.me, "damage")).toBe(50)
		expect(f.Stats.getStat(f.me, "attackSpeed")).toBe(50)
		expect(f.Stats.getStat(f.me, "speed")).toBe(10)
		expect(f.Stats.getStat(f.me, "pickupRange")).toBe(200)
		expect(f.Stats.getStat(f.me, "knockback")).toBe(15)
		-- Isolate the Soldier; an independently firing teammate would also damage this target.
		for _, weapon in f.Weapons.getWeapons(f.peer) do
			f.Weapons.removeWeapon(f.peer, weapon.uid)
		end
		local Enemy = require(f.S.EnemySim)
		local p = f.me.Character.HumanoidRootPart.Position
		local id = assert(Enemy.spawn("BroodEgg", p.X + 8, p.Z, 100, 0, nil, nil, 0))
		f.world.fireServerAs(f.me, "SetMovementIntent", true)
		expect(f.Stats.getStat(f.me, "damage")).toBe(50)
		expect(f.Stats.getStat(f.me, "attackSpeed")).toBe(50)
		f.Weapons.setPaused(false)
		local before = Enemy.getHealth(id)
		f.world.advance(1)
		expect(Enemy.getHealth(id)).toBe(before)
		f.world.fireServerAs(f.me, "SetMovementIntent", false)
		f.world.advance(0.3)
		expect(Enemy.getHealth(id) < before).toBe(true)
		f.Weapons.setPaused(true)
	end)
	it("requires a saved Danger2victory", function()
		local A = require(f.Shared.Util.CharacterAccess)
		f.Data.get(f.peer).stats.bestDanger = 1
		expect(A.characterUnlocked(f.Data.get(f.peer), "Soldier")).toBe(false)
		f.Data.get(f.peer).stats.bestDanger = 2
		expect(A.characterUnlocked(f.Data.get(f.peer), "Soldier")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
