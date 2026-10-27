-- Unit tests for effective weapon stats (WeaponService/WeaponStats): level deltas, the owner's stats with Brotato's
-- rules (damage scaling, Damage %, Attack Speed, Range, crit and life steal), the cooldown floor and evolutions.

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local WeaponStats = require(game:GetService("ServerScriptService").Server.Services.WeaponService.WeaponStats)

local W = Config.Weapons
local MIN_COOLDOWN = Config.Player.minWeaponCooldown

local function compute(weaponId, level, bonuses, evolutionId)
	local evolution = if evolutionId then Config.Evolutions[evolutionId] else nil
	return WeaponStats.compute(W[weaponId], level, bonuses or {}, evolution, MIN_COOLDOWN)
end

describe("WeaponStats", function()
	it("uses the base values at level 1", function()
		local stats = compute("OrbitBlades", 1)
		for key, value in W.OrbitBlades.base do
			expect(stats[key]).toBe(value)
		end
		expect(stats.critChance).toBeNear(Config.Player.critChance)
		expect(stats.lifeSteal).toBe(0)
	end)

	it("adds the level deltas up to the level", function()
		local blades = compute("OrbitBlades", 5)
		expect(blades.count).toBe(W.OrbitBlades.base.count + 2) -- +1 blade on level 3 and 5
		expect(blades.damage).toBeNear(W.OrbitBlades.base.damage * 1.3) -- +15 % on level 2 and 4
		local bolt = compute("SparkBolt", 4)
		expect(bolt.count).toBe(W.SparkBolt.base.count + 2)
		expect(bolt.damage).toBeNear(W.SparkBolt.base.damage * 1.2)
		local wave = compute("Shockwave", 5)
		expect(wave.radius).toBeNear(W.Shockwave.base.radius + 8)
		expect(wave.cooldown).toBeNear(W.Shockwave.base.cooldown - 1.2)
	end)

	it("adds the scaling damage stat, then multiplies with Damage %", function()
		local bolt = compute("SparkBolt", 1, { rangedDamage = 3, meleeDamage = 10, damage = 20, maxHp = 50 })
		expect(bolt.damage).toBeNear((W.SparkBolt.base.damage + 3) * 1.2) -- melee does not count for a ranged weapon
		local blades = compute("OrbitBlades", 1, { meleeDamage = 4 })
		expect(blades.damage).toBeNear(W.OrbitBlades.base.damage + 4)
		local weak = compute("ThornTrail", 1, { elementalDamage = -50, damage = -90 })
		expect(weak.damage).toBe(1) -- never below 1
	end)

	it("halves cooldowns at +100 % Attack Speed and slows them less with negative values", function()
		local fast = compute("SparkBolt", 1, { attackSpeed = 100 })
		expect(fast.cooldown).toBeNear(W.SparkBolt.base.cooldown / 2)
		local slow = compute("SparkBolt", 1, { attackSpeed = -100 })
		expect(slow.cooldown).toBeNear(W.SparkBolt.base.cooldown * 1.5)
		local blades = compute("OrbitBlades", 1, { attackSpeed = 50 })
		expect(blades.hitCooldownPerEnemy).toBeNear(W.OrbitBlades.base.hitCooldownPerEnemy / 1.5)
		expect(blades.rotationSpeed).toBeNear(W.OrbitBlades.base.rotationSpeed * 1.5)
		local thorns = compute("ThornTrail", 1, { attackSpeed = 25 })
		expect(thorns.tickInterval).toBeNear(W.ThornTrail.base.tickInterval / 1.25)
	end)

	it("never goes below the minimum cooldown", function()
		local stats = compute("SparkBolt", 1, { attackSpeed = 10000 })
		expect(stats.cooldown).toBe(MIN_COOLDOWN)
	end)

	it("lengthens ranges with Range, melee weapons by half", function()
		local rule = Config.Stats.range
		local bolt = compute("SparkBolt", 1, { range = 50 })
		expect(bolt.range).toBeNear(W.SparkBolt.base.range + 50 * rule.studsPerPoint)
		local chain = compute("ChainLightning", 1, { range = 50 })
		expect(chain.jumpRange).toBeNear(W.ChainLightning.base.jumpRange + 50 * rule.studsPerPoint)
		local blades = compute("OrbitBlades", 1, { range = 50 })
		expect(blades.radius).toBeNear(W.OrbitBlades.base.radius + 50 * rule.studsPerPoint * rule.meleeFactor)
		local short = compute("SparkBolt", 1, { range = -100000 })
		expect(short.range).toBe(rule.minStuds)
	end)

	it("carries crit chance and life steal from the stats", function()
		local stats = compute("SparkBolt", 1, { critChance = 20, lifeSteal = 5 })
		expect(stats.critChance).toBeNear(Config.Player.critChance + 0.2)
		expect(stats.lifeSteal).toBeNear(0.05)
		expect(compute("SparkBolt", 1, { critChance = 500 }).critChance).toBe(1)
	end)

	it("applies an evolution on top of the max level", function()
		local storm = compute("OrbitBlades", 5, {}, "BladeStorm")
		local evolution = Config.Evolutions.BladeStorm.stats
		expect(storm.count).toBe(evolution.count)
		expect(storm.radius).toBe(evolution.radius)
		expect(storm.damage).toBeNear(W.OrbitBlades.base.damage * 1.3 * evolution.damageMultiplier)
		expect(storm.damageMultiplier).toBe(nil)
		local bigger = compute("OrbitBlades", 5, { range = 20 }, "BladeStorm")
		local rule = Config.Stats.range
		expect(bigger.radius).toBeNear(evolution.radius + 20 * rule.studsPerPoint * rule.meleeFactor) -- stats still count
	end)
end)
