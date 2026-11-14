--!strict
-- Real server native bounce selection is global, includes charmed ordinary actors, and excludes bosses/dead actors.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
describe("Native server bounce target selection", function()
	it("rejects the reflector draw then chooses a distant enemy without using a radius or prior-hit filter", function()
		Enemy.killAll()
		local ignored = assert(Enemy.spawn("Shadeling", -80, 0, 1000, 0))
		local distant = assert(Enemy.spawn("Shadeling", 80, 0, 1000, 0))
		local draws = 0
		local x, z = Enemy.nativeBounceTarget(ignored, function()
			draws += 1
			return if draws == 1 then 0 else 0.999
		end)
		local target = assert(Enemy.getPosition(distant))
		expect(x).toBeNear(target.X)
		expect(z).toBeNear(target.Z)
		expect(draws).toBe(2)
		Enemy.damage(distant, 10000)
		local unused = 0
		x, z = Enemy.nativeBounceTarget(ignored, function()
			unused += 1
			return 0
		end)
		expect(x).toBe(nil)
		expect(z).toBe(nil)
		expect(unused).toBe(0)
	end)
	it("exposes the live probe body's defense through the configured service and clears it on death", function()
		Enemy.killAll()
		local k = f.Config.Enemies.types.Ankylosaurus
		local original = k.nativeCharge
		k.nativeCharge = require(f.Shared.Config.JungleDeflectCharges).rule
		local id = assert(Enemy.spawn("Ankylosaurus", 10, 0, 1000, 0))
		local active, capable = Enemy.isProjectileDeflecting(id)
		expect(active).toBe(false)
		expect(capable).toBe(true)
		for _ = 1, 240 do
			f.world.step(1 / 60)
			if Enemy.isProjectileDeflecting(id) then
				break
			end
		end
		expect(Enemy.isProjectileDeflecting(id)).toBe(true)
		local Projectile = require(f.S.WeaponService.BrotatoProjectile)
		local center = assert(Enemy.getHurtGeometry(id))
		local hx, hz = center.X, center.Z
		local hp = Enemy.getHealth(id)
		local stats = {
			damage = 10,
			projectileSpeed = 100,
			projectileRadius = 0.2,
			range = 100,
			pierce = 0,
			bounce = 0,
			bounceDamage = 1,
			critChance = 0,
			critDamage = 2,
			knockback = 0,
		}
		local weapon = {
			id = "Probe",
			ownerId = f.me.UserId,
			tier = 1,
			config = { kind = "Ranged", scaling = {} },
			stats = stats,
			state = {},
		}
		local serial = 0
		local ctx = {
			x = hx - 10,
			z = hz,
			active = false,
			now = 0,
			random = function()
				return 0.5
			end,
			nextId = function()
				serial += 1
				return serial
			end,
			emit = function() end,
			enemyPosition = function(_, target)
				local at = assert(Enemy.getPosition(target))
				return at.X, at.Z
			end,
			querySegment = function(_, x0, z0, x1, z1, radius, out)
				return Enemy.querySegment(Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z1), radius, out)
			end,
			hit = function()
				error("A shielded real enemy must never receive the damage/life-steal call")
			end,
			setHitDirection = function() end,
		}
		Projectile.launch(weapon, ctx, hx - 10, hz, 1, 0, stats)
		Projectile.step(weapon, ctx, 0.2)
		expect(weapon.state.projectiles[1].bounces).toBe(-1)
		Projectile.step(weapon, ctx, 0.01)
		expect(weapon.state.projectiles[1].bounces).toBe(-1)
		expect(Enemy.getHealth(id)).toBe(hp)
		Enemy.damage(id, hp + 1)
		expect(Enemy.isProjectileDeflecting(id)).toBe(false)
		active, capable = Enemy.isProjectileDeflecting(id)
		expect(capable).toBe(false)
		k.nativeCharge = original
	end)
	it("includes a charmed ordinary enemy while excluding the separate boss pool", function()
		Enemy.killAll()
		local ignored = assert(Enemy.spawn("Shadeling", -30, 0, 100, 0))
		local pet = assert(Enemy.spawn("Shadeling", 60, 0, 100, 0))
		assert(Enemy.charmSummoned(pet, f.me.UserId), "Probe charm conversion required")
		assert(Enemy.spawn("LanternEater", 90, 0, 100, 0), "Boss probe required")
		local x, z = Enemy.nativeBounceTarget(ignored, function()
			return 0.999
		end)
		local at = assert(Enemy.getPosition(pet))
		expect(x).toBeNear(at.X)
		expect(z).toBeNear(at.Z)
		expect(Enemy.isCharmed(pet)).toBe(true)
	end)
end)
