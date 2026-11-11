--!strict
-- Original pet weapon arithmetic, including Beast Master's additional scaling; guards the pet runtime adapter.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Pets = require(Shared.Config.Pets)
local Rules = require(game:GetService("ServerScriptService").Server.Services.StructureService.PetRules)
describe("Native pet stats", function()
	it("matches the native exponential Bonk Dog jump, including exact endpoints", function()
		expect(Rules.jumpShare(0)).toBe(0)
		expect(Rules.jumpShare(0.25)).toBeNear(0.015125)
		expect(Rules.jumpShare(0.5)).toBeNear(0.50025)
		expect(Rules.jumpShare(0.75)).toBeNear(0.9848671875)
		expect(Rules.jumpShare(1)).toBe(1)
	end)
	it("keeps normal attack speed out of pet cooldowns, including structure pets", function()
		local sheet = { attackSpeed = 1000, structureAttackSpeed = 1000 }
		expect(Rules.compute(Pets.kinds.BonkDog.weapon, sheet).cooldown).toBe(28 / 60)
		expect(Rules.compute(Pets.kinds.BotOMine.weapon, sheet).cooldown).toBe(32 / 60)
		expect(Rules.compute(Pets.kinds.CatlingGun.weapon, sheet).cooldown).toBe(55 / 60)
	end)
	it("adds missing damage scalings without replacing Ratzilla's Max HP scaling", function()
		local sheet = { maxHp = 50, meleeDamage = 10, rangedDamage = 20, elementalDamage = 30, engineering = 40 }
		expect(Rules.compute(Pets.kinds.Ratzilla.weapon, sheet).damage).toBe(9)
		expect(Rules.compute(Pets.kinds.Ratzilla.weapon, sheet, true).damage).toBe(19)
		expect(Rules.compute(Pets.kinds.BonkDog.weapon, sheet, true).damage).toBe(70)
		expect(Rules.compute(Pets.kinds.Lootworm.weapon, sheet, true).damage).toBe(1)
		expect(#Pets.kinds.Ratzilla.weapon.scaling).toBe(1)
	end)
	it("truncates scaled flat damage before percentages and distinguishes structure pets", function()
		local sheet = { meleeDamage = 1, engineering = 1, damage = 50, structureDamage = 100, explosionDamage = 50 }
		expect(Rules.compute(Pets.kinds.BonkDog.weapon, sheet).damage).toBe(15)
		expect(Rules.compute(Pets.kinds.BonkDog.explosion, sheet).damage).toBe(16)
		expect(Rules.compute(Pets.kinds.BotOMine.weapon, sheet).damage).toBe(28)
		expect(Rules.compute(Pets.kinds.BotOMine.mine, sheet).damage).toBe(33)
		expect(Rules.compute(Pets.kinds.BonkDog.weapon, { meleeDamage = -100, damage = 200 }).damage).toBe(3)
	end)
	it("grants ordinary pets critical and life steal bonuses while retaining structure restrictions", function()
		local sheet = { critChance = 40, critDamage = 50, lifeSteal = 25 }
		local dog = Rules.compute(Pets.kinds.BonkDog.weapon, sheet)
		expect(dog.critChance).toBe(0.4)
		expect(dog.critDamage).toBe(2)
		expect(dog.lifeSteal).toBe(0.25)
		local bot = Rules.compute(Pets.kinds.BotOMine.weapon, sheet)
		expect(bot.critChance).toBe(0)
		expect(bot.critDamage).toBe(1.5)
		expect(bot.lifeSteal).toBe(0)
		local enabled = Rules.compute(Pets.kinds.BotOMine.weapon, sheet, false, true)
		expect(enabled.critChance).toBe(0.4)
		expect(enabled.critDamage).toBe(2)
	end)
	it("uses half Range for melee pets, full Range for ranged pets and Structure Range for Bot-O-Mine", function()
		local sheet = { range = 100, structureRange = 200 }
		expect(Rules.compute(Pets.kinds.Ratzilla.weapon, sheet).range).toBe(20)
		expect(Rules.compute(Pets.kinds.CatlingGun.weapon, sheet).range).toBe(60)
		expect(Rules.compute(Pets.kinds.BotOMine.weapon, sheet).range).toBe(50)
		expect(Rules.compute(Pets.kinds.Ratzilla.weapon, { range = -1000 }).range).toBe(2.5)
		expect(Rules.compute(Pets.kinds.Ratzilla.weapon, { range = 1 }).range).toBe(15)
		expect(Rules.speed(Pets.kinds.Ratzilla, { speed = -80 })).toBe(50)
		expect(Rules.speed(Pets.kinds.Ratzilla, { speed = 20 })).toBe(60)
	end)
	it("applies ranged modifiers to the native Blazemander shot without changing its base configuration", function()
		local s = Rules.compute(
			Pets.kinds.Blazemander.ranged,
			{ projectiles = 2, piercing = 3, piercingDamage = 25, bounce = 2, bounceDamage = 10, accuracy = 20 }
		)
		expect(s.count).toBe(3)
		expect(s.pierce).toBe(102)
		expect(s.pierceDamage).toBe(0.25)
		expect(s.bounce).toBe(2)
		expect(s.bounceDamage).toBe(0.6)
		expect(s.nativeAccuracy).toBe(0.8)
		expect(s.nativeSpread).toBe(3.2)
		expect(s.projectileSpeed).toBe(60)
		expect(Pets.kinds.Blazemander.ranged.count).toBe(1)
	end)
	it("adds weapon-scaling effects after Beast Master's expansion and respects explicit cooldown limits", function()
		local s = Rules.compute(
			Pets.kinds.Ratzilla.weapon,
			{ maxHp = 100, meleeDamage = 10, engineering = 20, weaponCooldownMin = 1 },
			true,
			false,
			{ meleeDamage = 50 }
		)
		expect(s.damage).toBe(22) -- 4 +10 Max HP +6 Melee +2 Engineering.
		expect(s.cooldown).toBe(1)
	end)
end)
