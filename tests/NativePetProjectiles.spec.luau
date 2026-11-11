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
end)
