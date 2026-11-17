--!strict
-- Production registration of both source-bound crossing families, kept separate from complete Jungle area acceptance.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Kinds = require(Shared.Util.EnemyKinds)
local Stats = require(Shared.Util.EnemyStats)
local Facts = require(Shared.Config.JungleWalkers)
describe("Native crossing families", function()
	for _, row in
		{
			{ "Oviraptor", 59, 4, 5, 650, 175, 0.6, 1, 0.25, 0.35, -0.8, -0.9, -1 },
			{ "Iguanodon", 60, 16, 8, 800, 50, 1, 2, 0.35, 1.5, 1, 0.4, 1 },
		}
	do
		it("registers " .. row[1] .. " with original stats, body policy and source crossing rule", function()
			local k = assert(Kinds.get(row[1]), "Source family is not registered")
			expect(k.typeId).toBe(row[2])
			expect(k.hp).toBe(row[3])
			expect(k.hpPerWave).toBe(row[4])
			expect(k.nativeSpeedPoints.base).toBe(row[5])
			expect(k.nativeSpeedPoints.randomization).toBe(row[6])
			expect(k.damagePerWave).toBeNear(row[7])
			expect(k.xp).toBe(row[8])
			expect(k.knockbackResistance).toBeNear(row[9])
			expect(k.nativeCrossing.warningSeconds).toBeNear(row[10])
			expect(k.nativeBodyOffsetZ).toBeNear(row[11])
			expect(k.nativeHurtOffsetZ).toBeNear(row[12])
			expect(k.nativeHitOffsetZ).toBeNear(row[13])
			expect(k.nativeBodyLayer).toBe(4)
			expect(k.nativeBodyMask).toBe(0)
			expect(k.nativeBodyOneWay.margin).toBeNear(0.1)
			expect(k.nativeBodyOneWay.axisZ).toBe(1)
			expect(k.nativeMovement.borderClamp).toBe(false)
			expect(k.nativeObstacleCollision).toBe(false)
			expect(k.nativeMovement.collidePlayers).toBe(false)
			expect(k.nativeArtPending).toBe(true)
			expect(Stats.canSpawn(k, 1, 0, 0)).toBe(false)
			expect(Stats.canSpawn(k, 1, 0, 2)).toBe(true)
			expect(Facts.enemies[row[1]].actorRegistered).toBe(true)
			expect(Facts.enemies[row[1]].sourceOnly).toBe(false)
		end)
	end
end)
