--!strict
-- Normal Ankylosaurus source geometry, wandering and real server SHOOT-direction plumbing; evolution, art and area acceptance remain separate.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local Kinds = require(f.Shared.Util.EnemyKinds)
local EnemyStats = require(f.Shared.Util.EnemyStats)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.MapService).setMovementCheck(false)
require(f.S.CombatService).protect(f.me, 10000)
require(f.S.CombatService).protect(f.peer, 10000)
f.peer.Character.HumanoidRootPart.Position = Vector3.new(-80, 100, 80)
describe("Native normal Ankylosaurus", function()
	it("uses native independent growth and all three translated circles without joining Crash spawns", function()
		local k = assert(Kinds.get("Ankylosaurus"))
		expect(k.typeId).toBe(53)
		expect(Kinds.byTypeId(53).id).toBe("Ankylosaurus")
		expect(k.hp).toBe(25)
		expect(k.hpPerWave).toBe(12)
		expect(k.damagePerWave).toBeNear(1.1)
		expect(k.radius).toBeNear(4.5)
		expect(k.hurtRadius).toBeNear(4)
		expect(k.hitRadius).toBeNear(3.50571)
		expect(k.nativeBodyOffsetZ).toBeNear(-3.6)
		expect(k.nativeHurtOffsetZ).toBeNear(-2.9)
		expect(k.nativeHitOffsetZ).toBeNear(-1.7)
		expect(k.nativeArtPending).toBe(true)
		expect(EnemyStats.canSpawn(k, 1, 0, 0)).toBe(false)
		expect(EnemyStats.canSpawn(k, 1, 0, 2)).toBe(true)
		local id = assert(Enemy.spawn("Ankylosaurus", 40, 0, 2, 3, nil, nil, 0, 10))
		expect(Enemy.allowsHurtSlowEffects(id)).toBe(false)
		expect(Enemy.allowsHurtSlowEffects(-999)).toBe(false)
		expect(Enemy.getMaxHealth(id)).toBeNear((25 + 12 * 9) * 2)
		local _, damage = Enemy.getMultipliers(id)
		expect(damage).toBeNear((1 + 1.1 * 9) * 3)
		Enemy.killAll()
	end)
	it("uses the original 200px sprite inset for random arena goals rather than following a player", function()
		local k = assert(Kinds.get("Ankylosaurus"))
		expect(k.wander.around).toBe("Arena")
		expect(k.nativeMovement.goalInsetX).toBeNear(10)
		expect(k.nativeMovement.goalInsetZ).toBeNear(10)
		expect(k.nativeMovement.collidePlayers).toBe(false)
		local Movement = require(f.S.EnemySim.NativeMovement)
		local n = 0
		local x, z = Movement.goal(
			{ minX = -100, maxX = 100, minZ = -100, maxZ = 100 },
			k,
			k.wander,
			0,
			-50,
			-50,
			{},
			function()
				n += 1
				return if n == 1 then 1 else 0.5
			end
		)
		expect(x).toBeNear(90)
		expect(z).toBeNear(0)
	end)
	it("samples validated input at zero player speed and makes an actual diagonal server rush", function()
		Enemy.killAll()
		local Movement = require(f.S.CharacterService.Movement)
		Movement.init(function()
			return 0
		end)
		local root = f.me.Character.HumanoidRootPart
		root.AssemblyLinearVelocity = Vector3.zero
		local id = assert(Enemy.spawn("Ankylosaurus", root.Position.X - 35, root.Position.Z, 1000, 0, nil, nil, 0, 1))
		for frame = 1, 180 do
			if frame % 10 == 1 then
				f.world.fireServerAs(f.me, "SetMovementIntent", true, Vector3.new(0, 0, 1))
			end
			f.world.step(1 / 60)
			if Enemy.getMode(id) == 2 then
				break
			end
		end
		local mode, dx, dz = Enemy.getMode(id)
		expect(mode).toBe(2)
		expect(dz > 0).toBe(true)
		expect(Movement.getInput(f.me).Magnitude).toBe(0)
		local before = assert(Enemy.getPosition(id))
		f.world.step(1 / f.Config.Simulation.tickRate)
		local after = assert(Enemy.getPosition(id))
		expect(after.X - before.X).toBeNear(dx * 45 / f.Config.Simulation.tickRate)
		expect(after.Z - before.Z).toBeNear(dz * 45 / f.Config.Simulation.tickRate)
		expect(f.Run.getNativeZoneId()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
	it("skips generic Enemy hurt-hook slows while retaining damage and direct Unit speed penalties", function()
		Enemy.killAll()
		local root = f.me.Character.HumanoidRootPart
		local id = assert(Enemy.spawn("Ankylosaurus", root.Position.X - 10, root.Position.Z, 1000, 0, nil, nil, 1, 1))
		for _ = 1, 240 do
			f.world.step(1 / 60)
			local mode, dx, dz = Enemy.getMode(id)
			if mode == 2 and dx * dx + dz * dz > 0 then
				break
			end
		end
		local mode, dx, dz = Enemy.getMode(id)
		expect(mode).toBe(2)
		local k = assert(Kinds.get("Ankylosaurus"))
		local _, _, factor = Enemy.getMultipliers(id)
		local speed = k.speed * factor + 45
		local hp = Enemy.getHealth(id)
		local stats = {
			damage = 1,
			critChance = 0,
			critDamage = 2,
			knockback = 0,
			carbonMeleeSlow = 50,
			carbonSlowSeconds = 2,
			impactSlowRadius = 20,
			impactSlowPercent = 30,
			impactSlowHold = 2,
		}
		local weapon =
			{ id = "CarbonBow", ownerId = f.me.UserId, tier = 1, config = { scaling = {} }, stats = stats, state = {} }
		local context = {}
		function context:random()
			return 0.5
		end
		function context:enemyPosition(target)
			local at = assert(Enemy.getPosition(target))
			return at.X, at.Z
		end
		function context:hit(_, target)
			return Enemy.damage(target, 1, f.me)
		end
		require(f.S.WeaponService.BrotatoCombat).hit(weapon, context, id)
		expect(Enemy.getHealth(id)).toBeNear(hp - 1)
		local before = assert(Enemy.getPosition(id))
		f.world.step(1 / f.Config.Simulation.tickRate)
		local after = assert(Enemy.getPosition(id))
		expect(after.X - before.X).toBeNear(dx * speed / f.Config.Simulation.tickRate)
		expect(after.Z - before.Z).toBeNear(dz * speed / f.Config.Simulation.tickRate)
		Enemy.nativeSlow(id, -100, false, 2)
		before = after
		f.world.step(1 / f.Config.Simulation.tickRate)
		after = assert(Enemy.getPosition(id))
		expect(after.X - before.X).toBeNear(dx * (speed - 10) / f.Config.Simulation.tickRate)
		expect(after.Z - before.Z).toBeNear(dz * (speed - 10) / f.Config.Simulation.tickRate)
	end)
end)
