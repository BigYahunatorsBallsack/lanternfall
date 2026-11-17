--!strict
-- Plants bind stationary normal bullets and flat armor; inactive detection zones do not invent an eating mechanic.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Kinds = require(Shared.Util.EnemyKinds)
local C = require(Shared.Config.JungleWalkers)
describe("Normal Jungle plants", function()
	for _, row in
		{
			{ "CarnivorousPlant", 65, 7, 5, 3, 4, 0.25, 33.2415, 32, 30, 120, 20 },
			{ "CarnivorousPlantMother", 66, 35, 16, 7, 8, 0.5, 66.483, 64, 54, 90, 0 },
		}
	do
		it("uses the actual scaled body, normal bullet and armor of " .. row[1], function()
			local kind = assert(Kinds.get(row[1]))
			expect(kind.typeId).toBe(row[2])
			expect(kind.hp).toBe(row[3])
			expect(kind.hpPerWave).toBe(row[4])
			expect(kind.xp).toBe(row[5])
			expect(kind.speed).toBe(0)
			expect(kind.mass).toBe(50)
			expect(kind.knockbackResistance).toBe(1)
			expect(kind.nativeArmor.perWave).toBe(row[7])
			expect(kind.radius).toBeNear(row[8] * 0.1)
			expect(kind.hurtRadius).toBeNear(row[9] * 0.1)
			expect(kind.hitRadius).toBeNear(row[10] * 0.1)
			expect(kind.ranged.nativePillar).toBe(false)
			expect(kind.ranged.projectileRadius).toBeNear(1.70294)
			expect(kind.ranged.nativeVolley.count).toBe(row[6])
			expect(#kind.ranged.nativeVolley.specificDegrees).toBe(row[6])
			expect(kind.ranged.nativeVolley.offsetZ).toBe(-7)
			expect(kind.ranged.nativeTiming.fireInterval).toBe(row[11] / 60)
			expect(kind.ranged.nativeTiming.initialSeconds).toBe(row[12] / 60)
			expect(kind.ranged.nativeTiming.fireAt).toBeNear(0.4)
			expect(kind.ranged.nativeTiming.animationSeconds).toBeNear(0.5)
			expect(kind.shotDamagePerWave).toBeNear(1.2)
			expect(C.enemies[row[1]].bindingAudit.detectionZoneHasEatingConnection).toBe(false)
			expect(C.enemies[row[1]].projectileVariants.Normal.source).toBe(
				"res://projectiles/bullet_enemy/enemy_projectile.tscn"
			)
			expect(C.enemies[row[1]].projectileVariants.Meca.source).toBe(
				"res://projectiles/laser_enemy/enemy_laser.tscn"
			)
			expect(C.enemies[row[1]].evolutionVariantsImplemented).toBe(false)
		end)
	end
end)
