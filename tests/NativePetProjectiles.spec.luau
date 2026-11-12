--!strict
-- Native ranged pets reuse the real swept-projectile simulator, with pet damage, crit and life-steal rules.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Shared = f.Shared
local Pets = require(Shared.Config.Pets)
local Sim = require(f.S.StructureService.Projectiles)
local Enemy, Combat = require(f.S.EnemySim), require(f.S.CombatService)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
local at = Vector3.new(0, f.Config.Map.arena.center.Y, 0)
local function target()
	Enemy.killAll()
	Sim.clear()
	return assert(Enemy.spawn("Brute", 20, 0, 100, 0, nil, nil, 0))
end
describe("Native pet projectiles", function()
	it("spawns precisely six flames, ignores accuracy rolls and uses the native flame shape offset", function()
		local originalEmit, originalQuery = f.Weapons.emitStructureEffect, Enemy.querySegment
		local random = require(f.S.RandomService)
		local originalRandom = random.number
		random.number = function()
			return 0.75
		end
		for _, count in { -1, 2 } do
			local events = {}
			f.Weapons.emitStructureEffect = function(_, event)
				table.insert(events, event)
			end
			local directions = {}
			for n = 0, 5 do
				table.insert(directions, Vector3.new(math.cos(n * math.pi / 3), 0, math.sin(n * math.pi / 3)))
			end
			Sim.launchPet(f.me, at, Pets.kinds.Blazemander.ranged, { projectiles = count }, directions, false)
			expect(#events).toBe(6)
			local spread = 3 + count * f.Config.Combat.originalWeapons.spreadPerProjectile
			expect(events[1].dx).toBeNear(math.cos(spread / 2))
			expect(events[1].dz).toBeNear(math.sin(spread / 2))
			Sim.clear()
		end
		random.number = originalRandom
		f.Weapons.emitStructureEffect = originalEmit
		local weapon = table.clone(Pets.kinds.Blazemander.ranged)
		weapon.nativeSpread = 0
		local queried = false
		Enemy.querySegment = function(from, to, radius, out)
			queried = true
			expect(from.X).toBeNear(2.4)
			expect(from.Z).toBeNear(0.4)
			expect(radius).toBeNear(4.4)
			return originalQuery(from, to, radius, out)
		end
		Sim.launchPet(f.me, at, weapon, {}, { Vector3.new(1, 0, 0) }, false)
		Sim.step(0.01)
		Enemy.querySegment = originalQuery
		expect(queried).toBe(true)
		Sim.clear()
	end)
	it("flies Bot-O-Mine shots before applying Damage plus Structure Damage and Engineering", function()
		local id = target()
		local hp = Enemy.getHealth(id)
		Sim.launchPet(
			f.me,
			at,
			Pets.kinds.BotOMine.weapon,
			{ engineering = 10, damage = 50, structureDamage = 50 },
			{ Vector3.new(1, 0, 0) },
			false
		)
		Sim.step(0.02)
		expect(Enemy.getHealth(id)).toBe(hp)
		Sim.step(0.1)
		expect(Enemy.getHealth(id)).toBe(hp - 40)
	end)
	it("applies ordinary pet critical damage and shared life steal on actual projectile hits", function()
		local id = target()
		local hp = Enemy.getHealth(id)
		Combat.drainPlayer(f.me, 2)
		local ownerHp = Combat.getHp(f.me)
		Sim.launchPet(
			f.me,
			at,
			Pets.kinds.CatlingGun.weapon,
			{ rangedDamage = 10, critChance = 100, critDamage = 50, lifeSteal = 100 },
			{ Vector3.new(1, 0, 0) },
			false
		)
		Sim.step(0.1)
		expect(Enemy.getHealth(id)).toBe(hp - 32)
		expect(Combat.getHp(f.me)).toBe(ownerHp + 1)
	end)
	it("keeps Bot-O-Mine's structure restrictions and clears pending pet shots", function()
		local id = target()
		local hp, ownerHp = Enemy.getHealth(id), Combat.getHp(f.me)
		Sim.launchPet(
			f.me,
			at,
			Pets.kinds.BotOMine.weapon,
			{ critChance = 100, critDamage = 200, lifeSteal = 100 },
			{ Vector3.new(1, 0, 0) },
			false
		)
		Sim.step(0.1)
		expect(Enemy.getHealth(id)).toBe(hp - 10)
		expect(Combat.getHp(f.me)).toBe(ownerHp)
		Sim.launchPet(f.me, at, Pets.kinds.BotOMine.weapon, {}, { Vector3.new(1, 0, 0) }, false)
		Sim.clear()
		Sim.step(1)
		expect(Enemy.getHealth(id)).toBe(hp - 10)
		expect(#f.world.errors).toBe(0)
	end)
	it("does not create a pet shot when the native projectile count falls to zero", function()
		local id = target()
		local hp = Enemy.getHealth(id)
		Sim.launchPet(f.me, at, Pets.kinds.BotOMine.weapon, { projectiles = -1 }, { Vector3.new(1, 0, 0) }, false)
		Sim.step(1)
		expect(Enemy.getHealth(id)).toBe(hp)
	end)
	it("uses the original bullet hit circle and the native auto-aim flight extension", function()
		target()
		Enemy.killAll()
		local wide = assert(Enemy.spawn("Brute", 20, 5, 100, 0, nil, nil, 0))
		local hp = Enemy.getHealth(wide)
		Sim.launchPet(f.me, at, Pets.kinds.BotOMine.weapon, {}, { Vector3.new(1, 0, 0) }, false)
		Sim.step(0.1)
		expect(Enemy.getHealth(wide)).toBe(hp - 10)
		target()
		Enemy.killAll()
		local far = assert(Enemy.spawn("Brute", 37, 0, 100, 0, nil, nil, 0))
		hp = Enemy.getHealth(far)
		Sim.launchPet(f.me, at, Pets.kinds.BotOMine.weapon, {}, { Vector3.new(1, 0, 0) }, false)
		Sim.step(0.2)
		expect(Enemy.getHealth(far)).toBe(hp - 10)
	end)
	it("truncates each native piercing hit and retains one damage at total falloff", function()
		for _, case in
			{ { base = 11, falloff = 0.3, damage = { 11, 7, 4 } }, { base = 1, falloff = 1, damage = { 1, 1, 1 } } }
		do
			target()
			Enemy.killAll()
			local ids, hp = {}, {}
			for n = 1, 3 do
				ids[n] = assert(Enemy.spawn("Brute", n * 10, 0, 100, 0, nil, nil, 0))
				hp[n] = Enemy.getHealth(ids[n])
			end
			local weapon = table.clone(Pets.kinds.BotOMine.weapon)
			weapon.damage, weapon.pierce, weapon.pierceFalloff = case.base, 2, case.falloff
			Sim.launchPet(f.me, at, weapon, {}, { Vector3.new(1, 0, 0) }, false)
			Sim.step(0.2)
			for n, id in ids do
				expect(Enemy.getHealth(id)).toBe(hp[n] - case.damage[n])
			end
		end
	end)
end)
