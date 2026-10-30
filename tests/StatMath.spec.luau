-- Unit tests for the Brotato stat formulas (Util/StatMath) against Config.Stats, Config.Items.tiers and DESIGN.md
-- section 4.

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local StatMath = require(Shared.Util.StatMath)

describe("StatMath", function()
	it("starts every stat at 0 except Max HP and adds stats times a count", function()
		local sheet = StatMath.baseSheet()
		expect(sheet.maxHp).toBe(Config.Player.maxHp)
		expect(sheet.armor).toBe(0)
		StatMath.add(sheet, { armor = 1, damage = -2 }, 3)
		expect(sheet.armor).toBe(3)
		expect(sheet.damage).toBe(-6)
		sheet.maxHp = -40
		expect(StatMath.maxHp(sheet)).toBe(1)
	end)

	it("reduces damage with armor like Brotato", function()
		expect(StatMath.armorFactor(0)).toBe(1)
		expect(StatMath.armorFactor(5)).toBeNear(0.75)
		expect(StatMath.armorFactor(15)).toBeNear(0.5)
		expect(StatMath.armorFactor(-15)).toBeNear(1.5)
	end)

	it("caps dodge at 60 %", function()
		expect(StatMath.dodgeChance(30)).toBeNear(0.3)
		expect(StatMath.dodgeChance(90)).toBeNear(0.6)
		expect(StatMath.dodgeChance(-10)).toBe(0)
	end)

	it("regenerates one tick every 5 s at 1 and every second at 10", function()
		local scale = Config.Stats.hpScale
		expect(StatMath.regenPerSecond(0)).toBe(0)
		expect(StatMath.regenPerSecond(1)).toBeNear(scale / 5)
		expect(StatMath.regenPerSecond(10)).toBeNear(scale)
	end)

	it("halves cooldowns at +100 % attack speed and changes move speed by percent", function()
		expect(StatMath.cooldownFactor(100)).toBeNear(0.5)
		expect(StatMath.cooldownFactor(-100)).toBeNear(1.5)
		expect(StatMath.speedFactor(10)).toBeNear(1.1)
		expect(StatMath.speedFactor(-300)).toBe(Config.Stats.minSpeedFactor)
	end)

	it("follows Brotato's rarity table by wave and Luck", function()
		expect(StatMath.tierChance(2, 1, 0)).toBe(0)
		expect(StatMath.tierChance(2, 2, 0)).toBeNear(0.06)
		expect(StatMath.tierChance(2, 5, 0)).toBeNear(0.24)
		expect(StatMath.tierChance(2, 5, 100)).toBeNear(0.48)
		expect(StatMath.tierChance(2, 30, 0)).toBeNear(0.6) -- capped
		expect(StatMath.tierChance(3, 4, 0)).toBeNear(0.02)
		expect(StatMath.tierChance(4, 7, 0)).toBe(0)
		expect(StatMath.tierChance(4, 8, 0)).toBeNear(0.0023)
		-- one roll, rarest first
		expect(StatMath.rollTier(30, 0, 0.05)).toBe(4)
		expect(StatMath.rollTier(30, 0, 0.2)).toBe(3)
		expect(StatMath.rollTier(30, 0, 0.5)).toBe(2)
		expect(StatMath.rollTier(30, 0, 0.7)).toBe(1)
	end)

	it("scales gains by the class's multipliers and turns item and enemy stats into factors", function()
		local sheet = StatMath.addGains({ damage = 0, armor = 1 }, { damage = 10, armor = 2 }, { damage = 0.5 })
		expect(sheet.damage).toBe(5)
		expect(sheet.armor).toBe(3)
		expect(StatMath.addGains({}, { luck = 4 }).luck).toBe(4)
		expect(StatMath.priceFactor(-25)).toBeNear(0.75)
		expect(StatMath.priceFactor(-150)).toBe(Config.Stats.minPriceFactor)
		expect(StatMath.enemyFactor(10)).toBeNear(1.1)
		expect(StatMath.enemyFactor(-200)).toBe(Config.Stats.minEnemyFactor)
	end)

	it("formats stat values for cards", function()
		expect(StatMath.format("damage", 5)).toBe("+5% Damage")
		expect(StatMath.format("armor", -1)).toBe("-1 Armor")
		expect(StatMath.format("maxHp", 30)).toBe("+30 Max HP")
	end)
end)
