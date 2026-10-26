-- Unit tests for effective weapon stats (WeaponService/WeaponStats): level deltas, owner bonuses, the cooldown floor
-- and evolution overrides.

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

	it("scales damage, cooldown and area with the owner's bonuses", function()
		local stats = compute("SparkBolt", 1, { damage = 0.2, cooldown = -0.1, maxHp = 0.5 })
		expect(stats.damage).toBeNear(W.SparkBolt.base.damage * 1.2)
		expect(stats.cooldown).toBeNear(W.SparkBolt.base.cooldown * 0.9)
		local wave = compute("Shockwave", 1, { area = 0.15 })
		expect(wave.radius).toBeNear(W.Shockwave.base.radius * 1.15)
		expect(wave.knockback).toBe(W.Shockwave.base.knockback) -- not an area stat
	end)

	it("never goes below the minimum cooldown", function()
		local stats = compute("SparkBolt", 1, { cooldown = -0.99 })
		expect(stats.cooldown).toBe(MIN_COOLDOWN)
	end)

	it("applies an evolution on top of the max level", function()
		local storm = compute("OrbitBlades", 5, {}, "BladeStorm")
		local evolution = Config.Evolutions.BladeStorm.stats
		expect(storm.count).toBe(evolution.count)
		expect(storm.radius).toBe(evolution.radius)
		expect(storm.damage).toBeNear(W.OrbitBlades.base.damage * 1.3 * evolution.damageMultiplier)
		expect(storm.damageMultiplier).toBe(nil)
		local bigger = compute("OrbitBlades", 5, { area = 0.1 }, "BladeStorm")
		expect(bigger.radius).toBeNear(evolution.radius * 1.1) -- bonuses still count after evolving
	end)
end)
