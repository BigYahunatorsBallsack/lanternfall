--!strict
-- Intrinsic pet burns retain their original scaling and merge Sausage before damage percentages.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Pets = require(f.Shared.Config.Pets)
local Rules = require(f.S.StructureService.PetRules)
local Sim = require(f.S.StructureService.Projectiles)
local Enemy = require(f.S.EnemySim)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
describe("Native intrinsic pet burn", function()
	it("retains half Elemental scaling, five ticks and Beast Master's expansion", function()
		local def = Pets.kinds.Blazemander.ranged.burning
		expect(Rules.burnDamage(def, { elementalDamage = 20, nativeGlobalBurnDamage = 1 })).toBe(14)
		expect(Rules.burnDamage(def, { elementalDamage = 3, damage = 50, structureDamage = 900 })).toBe(6)
		expect(
			Rules.burnDamage(def, { elementalDamage = 20, meleeDamage = 10, rangedDamage = 30, engineering = 40 }, true)
		).toBe(53)
		expect(def.ticks).toBe(5)
	end)
	it("emits one flame per ring direction even with zero projectile count and merges global burn once", function()
		assert(f.Stats.addItem(f.me, "SmolderingWick"))
		f.Stats.addStats(f.me, { elementalDamage = 20, burnSpeed = 50 })
		local weapon = table.clone(Pets.kinds.Blazemander.ranged)
		weapon.nativeSpread = 0
		local id = assert(Enemy.spawn("Brute", 20, 0, 100, 0, nil, nil, 0))
		local hp = Enemy.getHealth(id)
		local random = require(f.S.RandomService)
		local original = random.number
		random.number = function(stream, player)
			return if stream == "Effects" then 0 else original(stream, player)
		end
		Sim.launchPet(
			f.me,
			Vector3.new(0, f.Config.Map.arena.center.Y, 0),
			weapon,
			{ elementalDamage = 20, nativeGlobalBurnDamage = 1, projectiles = -1, burnSpeed = 50 },
			{ Vector3.new(1, 0, 0) },
			false
		)
		Sim.step(0.3)
		random.number = original
		expect(Enemy.getHealth(id)).toBe(hp - 1)
		for _, player in { f.me, f.peer } do
			for _, owned in f.Weapons.getWeapons(player) do
				assert(f.Weapons.removeWeapon(player, owned.uid))
			end
		end
		f.Weapons.setPaused(false)
		f.world.advance(0.3, 1 / 60)
		expect(Enemy.getHealth(id)).toBe(hp - 15)
		f.world.advance(1.1, 1 / 60)
		expect(Enemy.getHealth(id)).toBe(hp - 71)
	end)
end)
