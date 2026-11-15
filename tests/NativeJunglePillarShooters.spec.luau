--!strict
-- Normal Hesperosaurus/Stegosaurus bind pillars; slash_2 is a different evolution branch.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Kinds = require(Shared.Util.EnemyKinds)
local C = require(Shared.Config.JungleWalkers)
describe("Normal Jungle pillar shooters", function()
	for _, row in
		{
			{ "Hesperosaurus", 62, 25, 12, 2, 3, 50, 1 },
			{ "Stegosaurus", 63, 50, 20, 4, 5, 60, 2 },
		}
	do
		it("binds " .. row[1] .. " to its actual normal pillar branch", function()
			local k = assert(Kinds.get(row[1]), "Normal pillar shooter missing")
			expect(k.typeId).toBe(row[2])
			expect(k.hp).toBe(row[3])
			expect(k.hpPerWave).toBe(row[4])
			expect(k.xp).toBe(row[5])
			expect(k.nativeSpeedPoints.base).toBe(275)
			expect(k.nativeSpeedPoints.randomization).toBe(25)
			expect(k.damagePerWave).toBeNear(1.1)
			expect(k.ranged.nativePillar).toBe(true)
			expect(k.ranged.nativeSlash).toBe(nil)
			expect(k.ranged.nativeVolley.count).toBe(row[6])
			expect(k.ranged.projectileSpeed).toBe(row[7])
			expect(k.ranged.projectileDamage).toBe(row[8])
			expect(k.shotDamagePerWave).toBe(1)
			expect(k.ranged.nativeVolley.speedStep).toBeNear(-3.5)
			expect(k.ranged.nativeVolley.spread).toBeNear(0.6)
			expect(k.ranged.nativeTiming.fireAt).toBeNear(0.8)
			expect(k.ranged.nativeTiming.animationSeconds).toBe(1)
			expect(k.ranged.nativeTiming.fireInterval).toBe(1)
			expect(k.wander.around).toBe("Target")
			expect(k.wander.range).toBe(30)
			expect(k.wander.rangeJitter).toBe(10)
			expect(k.stayInRange).toBe(nil)
			local f = C.enemies[row[1]]
			expect(f.projectileVariants.Normal.source).toBe("res://projectiles/pillar_enemy/pillar_projectile.tscn")
			expect(f.projectileVariants.Meca.source).toBe("res://projectiles/slash/slash_projectile_2.tscn")
			expect(f.projectileVariants.Mutant.source).toBe("res://projectiles/acid_projectile/acid_projectile.tscn")
			expect(f.evolutionVariantsImplemented).toBe(false)
		end)
	end
end)
