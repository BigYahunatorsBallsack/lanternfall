--!strict
-- Live EnemySim hurt geometry drives friendly native pillar hits while origin APIs and dead/unknown identities remain distinct.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local Kinds = require(f.Shared.Util.EnemyKinds)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
local Map = require(f.S.MapService)
Map.setMovementCheck(false)
for _, p in { f.me, f.peer } do
	require(f.S.CombatService).protect(p, 10000)
end
describe("Native live hurt geometry", function()
	it("uses translated hurt circles for actual animated friendly slash rectangles", function()
		Enemy.killAll()
		local Geometry = require(f.Shared.Util.NativeSlashGeometry)
		local C = require(f.Shared.Config.NightmareEnemies)
		local pixel = f.Config.Stats.range.studsPerPoint
		local attack = C.enemies.MadSlasher.attack
		local info = { x = 0, z = 0, dx = 1, dz = 0, speed = attack.projectile_speed * pixel }
		local edge, cx = -math.huge, 0
		for frame = math.ceil(C.slash.hitFrom * 60), math.ceil(C.slash.hitUntil * 60) - 1 do
			local x, z, _, hz = Geometry.rectangle(info, frame / 60, pixel)
			if z + hz > edge then
				edge, cx = z + hz, x
			end
		end
		local k = assert(Kinds.get("BabyPterosaur"))
		local targetZ = edge + k.hurtRadius - 0.1 + 3.4
		for frame = math.ceil(C.slash.hitFrom * 60), math.ceil(C.slash.hitUntil * 60) - 1 do
			expect(Geometry.contains(info, frame / 60, cx, targetZ, k.hurtRadius, pixel)).toBe(false)
		end
		local id = assert(Enemy.spawn("BabyPterosaur", cx, targetZ, 1000, 0, nil, nil, 0, 1))
		local source = assert(Enemy.spawn("MadSlasher", 50, 30, 1000, 0, nil, nil, 0, 1))
		local Random = require(f.S.RandomService)
		local original = Random.number
		Random.number = function(name, player)
			return if name == "Combat" then 0.5 else original(name, player)
		end
		local ok, err = pcall(function()
			Enemy.NativeSlash:Fire(source, 0, 0, 7, f.me.UserId)
		end)
		Random.number = original
		assert(ok, err)
		local hp = Enemy.getHealth(id)
		f.world.advance(0.62, 1 / 60)
		expect(Enemy.getHealth(id)).toBeNear(hp - 14)
	end)
	it("reports live scaled circles independently of origins and preserves killed geometry until compact", function()
		local at = Map.getRootPosition(f.me)
		local id = assert(Enemy.spawn("BabyTrex", at.X, at.Z, 1000, 0, nil, nil, 0, 1))
		f.world.advance(1.1, 1 / 60)
		local origin = assert(Enemy.getPosition(id))
		local hurt, radius = Enemy.getHurtGeometry(id)
		expect(hurt.Z - origin.Z).toBeNear(-0.8825)
		expect(radius).toBeNear(Kinds.get("BabyTrex").hurtRadius * 1.025)
		Enemy.damage(id, 1e9, nil)
		local killed = Enemy.getHurtGeometry(id)
		expect(killed.Z).toBeNear(hurt.Z)
		f.world.advance(0.2)
		expect(Enemy.getHurtGeometry(id)).toBe(nil)
		expect(Enemy.getHurtGeometry(65534)).toBe(nil)
	end)
	it("hits the translated edge with a real friendly pillar instead of the old origin circle", function()
		Enemy.killAll()
		local at = Map.getRootPosition(f.me)
		local id = assert(Enemy.spawn("BabyPterosaur", at.X, at.Z, 1000, 0, nil, nil, 0, 1))
		local origin = assert(Enemy.getPosition(id))
		local k = assert(Kinds.get("BabyPterosaur"))
		local pillarRadius = require(f.Shared.Config.JungleWalkers).shootingRules.pillar.radiusPoints
			* f.Config.Stats.range.studsPerPoint
		local z = origin.Z - 3.4 - k.hurtRadius - pillarRadius + 0.1
		local hp = Enemy.getHealth(id)
		local source = assert(Enemy.spawn("Enigmacursor", at.X + 40, at.Z + 30, 1000, 0, nil, nil, 0, 1))
		local offset = require(f.Shared.Config.JungleWalkers).shootingRules.pillar.offsetPoints
		local pixel = f.Config.Stats.range.studsPerPoint
		Enemy.NativePillar:Fire(source, origin.X - offset[1] * pixel, z - offset[2] * pixel, 1, 0, 0, 5, f.me.UserId)
		Enemy.remove(source)
		f.world.advance(0.62, 1 / 60)
		expect(Enemy.getHealth(id)).toBeNear(hp - 5)
		expect(#f.world.errors).toBe(0)
	end)
end)
