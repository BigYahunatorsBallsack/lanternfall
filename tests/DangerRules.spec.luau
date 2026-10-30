-- Unit tests for the danger level, slider and endless formulas (Util/DangerRules, B11) against Brotato's numbers in
-- DESIGN.md section 10.

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local DangerRules = require(Shared.Util.DangerRules)

local function options(danger: number, extra: { [string]: any }?)
	local result = DangerRules.defaultOptions()
	result.danger = danger
	for key, value in extra or {} do
		(result :: any)[key] = value
	end
	return result
end

-- A fixed sequence of rolls; random(n) picks the first entry.
local function sequence(rolls: { number })
	local index = 0
	return function(n: number): number
		return 1
	end, function(): number
		index += 1
		return rolls[(index - 1) % #rolls + 1]
	end
end

describe("DangerRules", function()
	it("scales enemies by +12/26/40 % from danger 3, 4 and 5", function()
		expect((DangerRules.multipliers(options(0), 5))).toBeNear(1)
		expect((DangerRules.multipliers(options(2), 5))).toBeNear(1)
		local hp, damage, speed = DangerRules.multipliers(options(3), 5)
		expect(hp).toBeNear(1.12)
		expect(damage).toBeNear(1.12)
		expect(speed).toBeNear(1)
		expect((DangerRules.multipliers(options(4), 5))).toBeNear(1.26)
		expect((DangerRules.multipliers(options(5), 5))).toBeNear(1.4)
	end)

	it("multiplies the sliders with the danger level", function()
		local hp, damage, speed = DangerRules.multipliers(options(5, { enemyDamage = 25, enemySpeed = 150 }), 3)
		expect(hp).toBeNear(1.4)
		expect(damage).toBeNear(0.35) -- Brotato: danger 5 at 25 % damage = 35 %
		expect(speed).toBeNear(1.5)
	end)

	it("cleans options onto the levels and slider steps", function()
		local clean = DangerRules.clean(options(9, { enemyHp = 137, enemySpeed = 400 }))
		expect(clean.danger).toBe(5)
		expect(clean.enemyHp).toBe(125)
		expect(clean.enemySpeed).toBe(150)
		expect(DangerRules.clean(options(-2)).danger).toBe(0)
		expect(DangerRules.label(options(3, { endless = true, enemyHp = 150 }))).toBe(
			"Danger 3 · Endless · Enemy HP 150%"
		)
	end)

	it("follows Brotato's endless factor after wave 20", function()
		expect(DangerRules.endlessFactor(20)).toBe(0)
		expect(DangerRules.endlessFactor(21)).toBeNear(0.02)
		expect(DangerRules.endlessFactor(25)).toBeNear(0.3)
		expect(DangerRules.endlessFactor(30)).toBeNear(1.1)
		expect(DangerRules.endlessFactor(40)).toBeNear(6.3)
		local hp, damage, speed = DangerRules.multipliers(options(0), 30)
		expect(hp).toBeNear(1 + 1.1 * 2.25) -- +248 % HP at wave 30
		expect(damage).toBeNear(2.1) -- +110 % damage
		expect(speed).toBeNear(1 + 1.1 / 13.33)
		local _, _, capped = DangerRules.multipliers(options(0), 80)
		expect(capped).toBeNear(2.75) -- at most 275 % speed
	end)

	it("leaves the new enemies out below danger 1", function()
		expect(DangerRules.spawns(0, "Stalker")).toBe(false)
		expect(DangerRules.spawns(1, "Stalker")).toBe(true)
		expect(DangerRules.spawns(0, "Shadeling")).toBe(true)
	end)

	it("plans no challenge waves below danger 2, one on 2-3 and three on 4-5", function()
		local random, roll = sequence({ 0.9 })
		expect(next(DangerRules.planBlock(1, 0, random, roll, {}))).toBe(nil)
		local plan = DangerRules.planBlock(2, 0, random, roll, {})
		expect(plan[11].kind).toBe("Elite")
		expect(#plan[11].champions).toBe(1)
		local five = DangerRules.planBlock(5, 0, random, roll, {})
		expect(five[11] ~= nil and five[14] ~= nil and five[17] ~= nil).toBe(true)
	end)

	it("makes the first two slots hordes with 40 %, never the third, and never repeats a champion", function()
		local random, roll = sequence({ 0.1 })
		local plan = DangerRules.planBlock(4, 0, random, roll, {})
		expect(plan[11].kind).toBe("Horde")
		expect(plan[14].kind).toBe("Horde")
		expect(plan[17].kind).toBe("Elite")
		local random2, roll2 = sequence({ 0.9 })
		local elites = DangerRules.planBlock(4, 0, random2, roll2, {})
		local seen = {}
		for _, wave in { 11, 14, 17 } do
			local id = elites[wave].champions[1]
			expect(seen[id]).toBe(nil)
			seen[id] = true
		end
	end)

	it("repeats the slots in endless blocks with one more champion each, also in the boss wave", function()
		local random, roll = sequence({ 0.1 })
		local plan = DangerRules.planBlock(4, 1, random, roll, {})
		expect(plan[21].kind).toBe("Elite") -- no hordes after wave 20
		expect(#plan[21].champions).toBe(2)
		expect(plan[27] ~= nil).toBe(true)
		expect(#plan[30].champions).toBe(2)
		expect(next(DangerRules.planBlock(0, 2, random, roll, {}))).toBe(40)
	end)

	it("brings two bosses on danger 5 and every boss in endless boss waves", function()
		expect(DangerRules.bossCount(0, 20)).toBe(1)
		expect(DangerRules.bossCount(5, 20)).toBe(2)
		expect(DangerRules.bossCount(0, 30)).toBe(#Config.Enemies.bossWave.order)
		expect(DangerRules.bossShare(2)).toBe(0.75)
		expect(DangerRules.isBossWave(20)).toBe(true)
		expect(DangerRules.isBossWave(30)).toBe(true)
		expect(DangerRules.isBossWave(25)).toBe(false)
		expect(DangerRules.legendaryCrates(20)).toBe(true)
		expect(DangerRules.legendaryCrates(21)).toBe(false)
	end)
end)
