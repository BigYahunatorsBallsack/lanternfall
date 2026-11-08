--!strict
-- Source parity and special-attack regressions for all original base-game weapons.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Service = game:GetService("ServerScriptService").Server.Services.WeaponService
local WeaponStats = require(Service.WeaponStats)
local Runtime = require(Service.BrotatoRuntime)
local Fixture = loadHelper("tests/helpers/BrotatoCatalog.luau")

local function weapon(id, tier, bonuses)
	return {
		id = id,
		uid = 1,
		ownerId = 1,
		config = Config.Weapons[id],
		tier = tier,
		state = {},
		stats = WeaponStats.compute(Config.Weapons[id], tier, bonuses or {}, nil, Config.Player.minWeaponCooldown),
	}
end

describe("Brotato original catalog", function()
	local count = 0
	for id, original in Fixture do
		count += 1
		it(original.name .. " matches every available source tier", function()
			local w = Config.Weapons[id]
			expect(w.displayName).toBe(original.name)
			expect(w.minTier).toBe(original.minTier)
			expect(Service.Behaviors:FindFirstChild(id) ~= nil).toBe(true)
			for tier = original.minTier, 4 do
				local source = original.tiers[tier]
				local s = WeaponStats.compute(w, tier, {}, nil, Config.Player.minWeaponCooldown)
				-- Native LV.0 contributes no level scaling; explicit LV.10 is checked below.
				expect(s.damage).toBeNear(source.damage)
				expect(s.range).toBeNear(source.range * 0.1)
				expect(s.cooldown).toBeNear(source.cooldown)
				expect(s.critChance).toBeNear(source.critChance)
				expect(s.critDamage).toBeNear(source.critDamage)
				expect(s.lifeSteal).toBeNear(source.lifeSteal)
				expect(s.knockback).toBeNear(source.knockback * Config.Combat.knockback.studsPerPoint)
				expect(Config.Shop.weaponTierPrices[id][tier]).toBeNear(source.price)
				for stat, share in original.scaling[tier] do
					local bonus = { [stat] = 10 }
					local effective = WeaponStats.compute(w, tier, bonus, nil, Config.Player.minWeaponCooldown)
					local scaled = if stat == "level" then source.damage + share * 10 else s.damage + share * 10
					expect(effective.damage).toBeNear(scaled)
				end
			end
		end)
	end
	it("retains all 62 original records alongside seven stable starting families and no custom evolutions", function()
		local actual = 0
		for id in Config.Weapons do
			actual += 1
			expect(Fixture[id] ~= nil or require(Shared.Config.CharacterWeaponData).weapons[id] ~= nil).toBe(true)
		end
		expect(actual).toBe(69)
		expect(count).toBe(62)
		expect(next(Config.Evolutions)).toBe(nil)
	end)
	it("converts HP scaling once and includes player level", function()
		expect(weapon("Chopper", 1, { maxHp = 100 }).stats.damage).toBeNear(21)
		expect(weapon("Excalibur", 4, { maxHp = 100, meleeDamage = 10 }).stats.damage).toBeNear(420)
		expect(weapon("Quarterstaff", 1, { level = 8 }).stats.damage).toBeNear(16)
	end)
	it("keeps Particle Accelerator from bouncing and scales its slow", function()
		local s = weapon("ParticleAccelerator", 4, { bounce = 20, engineering = 12 }).stats
		expect(s.bounce).toBe(0)
		expect(s.pierce).toBe(-1)
		expect(s.slow).toBeNear(0.24)
	end)
	it("counts other Sticks before Damage percent", function()
		local a, b = weapon("Stick", 1), weapon("Stick", 2)
		Runtime.recompute({ a, b }, { damage = 50 })
		expect(a.stats.damage).toBeNear((8 + 4) * 1.5)
		expect(b.stats.damage).toBeNear((9 + 6) * 1.5)
	end)
	it("grows Drill and Railgun each five seconds and resets the railgun on damage", function()
		local drill, rail = weapon("Drill", 4), weapon("Railgun", 1)
		local gains = Runtime.step({ drill, rail }, 10, true, 100, 100, function() end)
		expect(gains.attackSpeed).toBe(20)
		Runtime.recompute({ drill, rail }, {})
		expect(rail.stats.damage).toBeNear(16)
		Runtime.hurt({ drill, rail })
		Runtime.recompute({ drill, rail }, {})
		expect(rail.stats.damage).toBeNear(10)
		expect(drill.state.attackSpeedGain).toBe(20)
	end)
	it("applies stationary Lance penalties and missing-health Tooth bonuses", function()
		local lance, tooth = weapon("JoustingLance", 4), weapon("SharpTooth", 4)
		local gains = Runtime.step({ lance, tooth }, 0, false, 50, 100, function() end)
		expect(gains.damage).toBe(-25)
		expect(gains.lifeSteal).toBe(5)
		expect(Runtime.step({ lance, tooth }, 0, true, 100, 100, function() end).damage).toBe(0)
	end)
	it("drains Scythe health on time and awards damage on each hurt", function()
		local scythe = weapon("Scythe", 4)
		local drained = 0
		Runtime.step({ scythe }, 2.5, true, 100, 100, function(amount)
			drained += amount
			Runtime.hurt({ scythe })
		end)
		expect(drained).toBe(6)
		expect(Runtime.step({ scythe }, 0, true, 40, 100, function() end).damage).toBe(6)
	end)
end)
