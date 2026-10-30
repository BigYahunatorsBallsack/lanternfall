-- Unit tests for effective weapon stats (WeaponService/WeaponStats): tier deltas, the owner's stats with Brotato's
-- rules (damage scaling, Damage %, Attack Speed, Range, crit and life steal), the cooldown floor and evolutions, and
-- since B5 the combat stats (per weapon crits and life steal, knockback, piercing, bouncing, explosions, burning).

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local WeaponStats = require(game:GetService("ServerScriptService").Server.Services.WeaponService.WeaponStats)

local W = Config.Weapons
local MIN_COOLDOWN = Config.Player.minWeaponCooldown

local function compute(weaponId, tier, bonuses, evolutionId)
	local evolution = if evolutionId then Config.Evolutions[evolutionId] else nil
	return WeaponStats.compute(W[weaponId], tier, bonuses or {}, evolution, MIN_COOLDOWN)
end

describe("WeaponStats", function()
	it("uses the base values at tier I", function()
		local stats = compute("OrbitBlades", 1)
		for key, value in W.OrbitBlades.base do
			if key ~= "knockback" then
				expect(stats[key]).toBe(value)
			end
		end
		expect(stats.knockback).toBeNear(W.OrbitBlades.base.knockback * Config.Combat.knockback.studsPerPoint)
		expect(stats.critChance).toBeNear(W.OrbitBlades.base.critChance)
		expect(stats.critDamage).toBe(W.OrbitBlades.base.critDamage)
		expect(stats.lifeSteal).toBe(0)
	end)

	it("adds the tier deltas up to the tier", function()
		local blades = compute("OrbitBlades", 4)
		expect(blades.count).toBe(W.OrbitBlades.base.count + 2) -- +1 blade on tier II and III
		expect(blades.damage).toBeNear(W.OrbitBlades.base.damage * 2.1) -- +20 %, +30 %, +60 %
		local bolt = compute("SparkBolt", 3)
		expect(bolt.count).toBe(W.SparkBolt.base.count + 1)
		expect(bolt.damage).toBeNear(W.SparkBolt.base.damage * 1.4)
		local wave = compute("Shockwave", 4)
		expect(wave.radius).toBeNear(W.Shockwave.base.radius + 7)
		expect(wave.cooldown).toBeNear(W.Shockwave.base.cooldown - 1.0)
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
		expect(stats.critChance).toBeNear(W.SparkBolt.base.critChance + 0.2)
		expect(stats.lifeSteal).toBeNear(0.05)
		expect(compute("SparkBolt", 1, { critChance = 500 }).critChance).toBe(1)
		expect(compute("ThornTrail", 1, { critChance = -50 }).critChance).toBe(0)
	end)

	it("adds a weapon's own life steal from its tiers to the stat", function()
		expect(compute("OrbitBlades", 2, { lifeSteal = 5 }).lifeSteal).toBeNear(0.05)
		expect(compute("OrbitBlades", 3, { lifeSteal = 5 }).lifeSteal).toBeNear(0.08)
		expect(compute("OrbitBlades", 4).lifeSteal).toBeNear(0.06)
	end)

	it("scales a weapon with several stats", function()
		local wave = compute("Shockwave", 1, { meleeDamage = 4, armor = 6 })
		expect(wave.damage).toBeNear(W.Shockwave.base.damage + 4 + 6 * W.Shockwave.scaling.armor)
		local axe = compute("BoomerangAxe", 1, { rangedDamage = 10, meleeDamage = 10 })
		expect(axe.damage).toBeNear(W.BoomerangAxe.base.damage + 10 * 0.8 + 10 * 0.5)
	end)

	it("turns knockback points into studs and adds the Knockback stat", function()
		local studs = Config.Combat.knockback.studsPerPoint
		expect(compute("Shockwave", 1).knockback).toBeNear(W.Shockwave.base.knockback * studs)
		expect(compute("ChainLightning", 1, { knockback = 5 }).knockback).toBeNear(5 * studs)
		expect(compute("ChainLightning", 1, { knockback = -5 }).knockback).toBe(0)
	end)

	it("adds Piercing and Bouncing to projectiles and lets Piercing Damage give back the falloff", function()
		local bolt = compute("SparkBolt", 1, { piercing = 2, bounce = 1 })
		expect(bolt.pierce).toBe(W.SparkBolt.base.pierce + 2)
		expect(bolt.pierceDamage).toBeNear(1 - Config.Combat.piercing.falloff)
		expect(bolt.bounce).toBe(1)
		expect(bolt.bounceDamage).toBeNear(1 - Config.Combat.bounce.falloff)
		expect(compute("SparkBolt", 1, { piercingDamage = 15 }).pierceDamage).toBeNear(0.65)
		expect(compute("SparkBolt", 1, { piercingDamage = 500 }).pierceDamage).toBe(1) -- never above full damage
		local axe = compute("BoomerangAxe", 1, { piercing = 3 })
		expect(axe.pierce).toBe(-1) -- already flies through everything
		expect(axe.pierceDamage).toBe(1) -- and loses nothing
		expect(compute("ChainLightning", 1, { bounce = 2 }).jumps).toBe(W.ChainLightning.base.jumps + 2)
	end)

	it("grows explosions with Explosion Size and Damage", function()
		local starfire = compute("SparkBolt", 4, { explosionSize = 50, explosionDamage = 20 }, "Starfire")
		local evolution = Config.Evolutions.Starfire.stats
		expect(starfire.explosionRadius).toBeNear(evolution.explosionRadius * 1.5)
		expect(starfire.explosionDamage).toBeNear(evolution.explosionDamage * 1.2)
	end)

	it("scales a weapon's burn with Elemental Damage, Damage %, Burning Speed and Spread", function()
		local torch = {
			id = "Torch",
			kind = "Melee",
			classes = { "Primal" },
			scaling = {},
			rangeKeys = {},
			base = { damage = 1, cooldown = 1, burnDamage = 3, burnTicks = 3 },
			tiers = { {}, {}, {}, {} },
		}
		local stats = WeaponStats.compute(
			torch :: any,
			1,
			{ elementalDamage = 2, damage = 50, burnSpeed = 20, burnSpread = 1 },
			nil,
			MIN_COOLDOWN
		)
		expect(stats.burnDamage).toBeNear((3 + 2) * 1.5)
		expect(stats.burnInterval).toBeNear(Config.Combat.burn.tickSeconds * 0.8)
		expect(stats.burnSpread).toBe(1)
		expect(stats.burnChance).toBe(1)
		expect(WeaponStats.ownerDamage(1, { elementalDamage = 1 }, { elementalDamage = 4, damage = -50 })).toBeNear(2.5)
		expect(WeaponStats.ownerDamage(1, nil, { damage = -100 })).toBe(1)
	end)

	it("applies an evolution on top of the max tier", function()
		local storm = compute("OrbitBlades", 4, {}, "BladeStorm")
		local evolution = Config.Evolutions.BladeStorm.stats
		expect(storm.count).toBe(evolution.count)
		expect(storm.radius).toBe(evolution.radius)
		expect(storm.damage).toBeNear(W.OrbitBlades.base.damage * 2.1 * evolution.damageMultiplier)
		expect(storm.damageMultiplier).toBe(nil)
		local bigger = compute("OrbitBlades", 4, { range = 20 }, "BladeStorm")
		local rule = Config.Stats.range
		expect(bigger.radius).toBeNear(evolution.radius + 20 * rule.studsPerPoint * rule.meleeFactor) -- stats still count
	end)
end)
