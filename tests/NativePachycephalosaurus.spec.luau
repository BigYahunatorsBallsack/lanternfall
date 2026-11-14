--!strict
-- Real normal Pachycephalosaurus body, charge and shield integration; evolution/art/area remain separate work.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local Kinds = require(f.Shared.Util.EnemyKinds)
local EnemyStats = require(f.Shared.Util.EnemyStats)
local Sim = require(f.S.StructureService.Projectiles)
local Pets = require(f.Shared.Config.Pets)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.MapService).setMovementCheck(false)
require(f.S.CombatService).protect(f.me, 10000)
require(f.S.CombatService).protect(f.peer, 10000)
f.peer.Character.HumanoidRootPart.Position = Vector3.new(-80, 100, 80)
local function actor(active)
	Sim.clear()
	Enemy.killAll()
	local root = f.me.Character.HumanoidRootPart
	local id = assert(Enemy.spawn("Pachycephalosaurus", root.Position.X - 20, root.Position.Z, 1000, 0, nil, nil, 0))
	if active then
		for _ = 1, 240 do
			f.world.step(1 / 60)
			if Enemy.isProjectileDeflecting(id) then
				break
			end
		end
		expect(Enemy.isProjectileDeflecting(id)).toBe(true)
	end
	return id
end
describe("Native normal Pachycephalosaurus", function()
	it("registers its original body, independent stat growth and zone filtering", function()
		local k = assert(Kinds.get("Pachycephalosaurus"))
		expect(k.typeId).toBe(54)
		expect(Kinds.byTypeId(54).id).toBe("Pachycephalosaurus")
		expect(k.hp).toBe(12)
		expect(k.hpPerWave).toBe(12)
		expect(k.speed).toBeNear(25)
		expect(k.speedMax).toBeNear(30)
		expect(k.damagePerWave).toBe(1)
		expect(k.radius).toBeNear(5.3)
		expect(k.hurtRadius).toBeNear(4.70106)
		expect(k.hitRadius).toBeNear(3.50571)
		expect(k.nativeBodyOffsetZ).toBeNear(-3.6)
		expect(k.nativeHurtOffsetZ).toBeNear(-2.9)
		expect(k.nativeHitOffsetZ).toBeNear(-1.7)
		expect(k.nativeArtPending).toBe(true)
		expect(EnemyStats.canSpawn(k, 1, 0, 0)).toBe(false)
		expect(EnemyStats.canSpawn(k, 1, 0, 2)).toBe(true)
		Enemy.killAll()
		local id = assert(Enemy.spawn("Pachycephalosaurus", 40, 0, 2, 3, nil, nil, 0, 10))
		expect(Enemy.getMaxHealth(id)).toBeNear((12 + 12 * 9) * 2)
		local _, damage = Enemy.getMultipliers(id)
		expect(damage).toBeNear((1 + 9) * 3)
		expect(Enemy.allowsHurtSlowEffects(id)).toBe(false)
	end)
	it("starts as a normal follower and activates its real shield at SHOOT", function()
		local id = actor(false)
		local active, capable = Enemy.isProjectileDeflecting(id)
		expect(active).toBe(false)
		expect(capable).toBe(true)
		local k = assert(Kinds.get("Pachycephalosaurus"))
		expect(k.wander).toBe(nil)
		expect(k.nativeFollowXShare).toBe(nil)
		expect(k.nativeCharge.speed).toBeNear(40)
		expect(k.nativeCharge.target.atShoot).toBe(true)
		expect(k.nativeCharge.target.radius).toBeNear(10)
		for _ = 1, 240 do
			f.world.step(1 / 60)
			if Enemy.isProjectileDeflecting(id) then
				break
			end
		end
		expect(Enemy.isProjectileDeflecting(id)).toBe(true)
		expect(Enemy.getMode(id)).toBe(2)
		Enemy.damage(id, assert(Enemy.getHealth(id)) + 1)
		active, capable = Enemy.isProjectileDeflecting(id)
		expect(active).toBe(false)
		expect(capable).toBe(false)
	end)
	it("actually deflects Catling shots but permits ordinary turret damage on the registered body", function()
		local id = actor(true)
		local center = assert(Enemy.getHurtGeometry(id))
		local hp = Enemy.getHealth(id)
		local pixel = f.Config.Stats.range.studsPerPoint
		local side = Pets.projectile.offsetSidePoints * pixel
		Sim.launchPet(
			f.me,
			center - Vector3.new(0, 0, side),
			Pets.kinds.CatlingGun.weapon,
			{},
			{ Vector3.new(1, 0, 0) },
			false
		)
		Sim.step(0.001)
		expect(Enemy.getHealth(id)).toBe(hp)
		Sim.clear()
		Sim.launch(f.me, center, f.Config.Structures.kinds.BrassSentry, {}, { Vector3.new(1, 0, 0) })
		Sim.step(0.001)
		expect(Enemy.getHealth(id) < hp).toBe(true)
		expect(f.Run.getNativeZoneId()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
	it("remains damageable outside the shield window without generic Enemy hurt slows", function()
		local id = actor(false)
		local center = assert(Enemy.getHurtGeometry(id))
		local hp = Enemy.getHealth(id)
		Sim.launchPet(
			f.me,
			center - Vector3.new(0, 0, Pets.projectile.offsetSidePoints * f.Config.Stats.range.studsPerPoint),
			Pets.kinds.CatlingGun.weapon,
			{},
			{ Vector3.new(1, 0, 0) },
			false
		)
		Sim.step(0.001)
		expect(Enemy.getHealth(id) < hp).toBe(true)
		expect(Enemy.allowsHurtSlowEffects(id)).toBe(false)
	end)
	it("retains active charge defense through the actual charm transfer", function()
		local id = actor(true)
		expect(Enemy.charmSummoned(id, f.me.UserId)).toBe(true)
		expect(Enemy.isCharmed(id)).toBe(true)
		local active, capable = Enemy.isProjectileDeflecting(id)
		expect(active).toBe(true)
		expect(capable).toBe(true)
		for _ = 1, 180 do
			f.world.step(1 / 60)
		end
		expect(Enemy.isProjectileDeflecting(id)).toBe(false)
		expect(#f.world.errors).toBe(0)
	end)
end)
Sim.clear()
