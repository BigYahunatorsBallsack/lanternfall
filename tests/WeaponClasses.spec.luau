-- Unit tests for the weapon class bonuses (Util/WeaponClasses, Config.WeaponClasses; Brotato's set bonuses since B5):
-- counting copies, the bonus per count up to the cap, adding up several classes and the texts.

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local WeaponClasses = require(Shared.Util.WeaponClasses)

local Classes = Config.WeaponClasses

describe("WeaponClasses", function()
	it("counts every weapon of a class, copies too", function()
		local counts = WeaponClasses.counts({ "OrbitBlades", "OrbitBlades", "BoomerangAxe", "Unknown" })
		expect(counts.Edge).toBe(3)
		expect(counts.Spectral).toBe(2)
		expect(counts.Primal).toBe(1)
		expect(counts.Arcane).toBe(nil)
	end)

	it("gives a class's bonus from 2 weapons on and stops growing at 6", function()
		expect(WeaponClasses.bonus("Edge", 1)).toBe(nil)
		expect(WeaponClasses.bonus("Edge", 2).meleeDamage).toBe(1)
		expect(WeaponClasses.bonus("Edge", 2).lifeSteal).toBe(1)
		expect(WeaponClasses.bonus("Keen", 6).critChance).toBe(15)
		expect(WeaponClasses.bonus("Keen", 9).critChance).toBe(15)
		expect(WeaponClasses.bonus("Primal", 3).maxHp).toBe(6 * Config.Stats.hpScale) -- Brotato's HP times 10
		expect(WeaponClasses.bonus("Nope", 4)).toBe(nil)
	end)

	it("adds up the bonuses of every class", function()
		local sheet = WeaponClasses.bonuses({ "SparkBolt", "ChainLightning", "ThornTrail" })
		expect(sheet.elementalDamage).toBe(2) -- Arcane 3
		expect(sheet.critChance).toBe(3) -- Keen 2
		expect(sheet.maxHp).toBe(nil) -- Primal 1: nothing yet
		expect(next(WeaponClasses.bonuses({ "SparkBolt" }))).toBe(nil)
	end)

	it("names the classes of a weapon and lists the ones carried in config order", function()
		expect(WeaponClasses.names("BoomerangAxe")).toBe("Edge · Primal")
		expect(WeaponClasses.names("Unknown")).toBe("")
		local carried = WeaponClasses.carried({ "BoomerangAxe", "OrbitBlades" })
		expect(#carried).toBe(3)
		expect(carried[1].id).toBe("Edge")
		expect(carried[1].count).toBe(2)
	end)

	it("has a bonus for every count from 2 to 6 and only known stats", function()
		for _, class in Classes.order do
			for count = Classes.minCount, Classes.maxCount do
				local stats = class.bonuses[count]
				expect(stats ~= nil).toBe(true)
				for statId in stats do
					expect(Config.Stats.byId[statId] ~= nil).toBe(true)
				end
			end
		end
		for _, weapon in Config.Weapons do
			expect(#weapon.classes >= 1 and #weapon.classes <= 2).toBe(true)
		end
	end)
end)
