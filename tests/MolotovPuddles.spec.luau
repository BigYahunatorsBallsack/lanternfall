--!strict
-- Native fire-puddle entry, expiry and ownership rules used by the real projectile integration.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Service = game:GetService("ServerScriptService").Server.Services.WeaponService
local function setup()
	local ignitions, events = {}, {}
	local bodies = { [1] = { x = 0, z = 0 }, [2] = { x = 20, z = 0 } }
	local engine = require(Service.FirePuddles).new({
		query = function(x, z, radius, out)
			local n = 0
			for id, body in bodies do
				if (body.x - x) ^ 2 + (body.z - z) ^ 2 <= radius ^ 2 then
					n += 1
					out[n] = id
				end
			end
			return n
		end,
		ignite = function(weapon, id, stats)
			table.insert(ignitions, { owner = weapon.ownerId, id = id, damage = stats.burnDamage })
		end,
		emit = function(_, event)
			table.insert(events, event)
		end,
	})
	local config = assert(require(Shared.Config).Weapons.Molotov, "Molotov is missing")
	local stats = require(Service.WeaponStats).compute(config, 1, { elementalDamage = 5 }, nil, 0)
	local weapon = { ownerId = 1 }
	return engine, weapon, stats, bodies, ignitions, events
end
describe("Native Molotov fire puddles", function()
	it("ignite on entry, allow re-entry, and do not refresh a stationary target every tick", function()
		local engine, weapon, stats, bodies, hits = setup()
		engine:spawn(weapon, 0, 0, stats)
		engine:step(0.2)
		expect(#hits).toBe(1)
		expect(hits[1].damage).toBe(8)
		engine:step(0.5)
		expect(#hits).toBe(1)
		bodies[1].x = 20
		engine:step(0.1)
		bodies[1].x = 0
		engine:step(0.1)
		expect(#hits).toBe(2)
	end)
	it("retain their captured burn and owner and stop igniting at the exact lifetime", function()
		local engine, weapon, stats, bodies, hits = setup()
		engine:spawn(weapon, 0, 0, stats)
		stats.burnDamage = 999
		engine:step(0.2)
		expect(hits[1].damage).toBe(8)
		expect(hits[1].owner).toBe(1)
		engine:step(2.8)
		bodies[2].x = 0
		engine:step(0.1)
		expect(#hits).toBe(1)
	end)
	it("preserve separate overlapping owners and clear all lingering fire on a wave reset", function()
		local engine, weapon, stats, _, hits = setup()
		engine:spawn(weapon, 0, 0, stats)
		engine:spawn({ ownerId = 2 }, 0, 0, stats)
		engine:step(0.2)
		expect(#hits).toBe(2)
		engine:clear()
		engine:step(0.2)
		expect(#hits).toBe(2)
	end)
	it("keeps the native tier sizes and durations", function()
		local _, _, _, _, _, _ = setup()
		local config = require(Shared.Config).Weapons.Molotov
		for tier, expected in { { 5.6, 3 }, { 6, 3.5 }, { 6.4, 4 }, { 7.2, 4.5 } } do
			local stats = require(Service.WeaponStats).compute(config, tier, {}, nil, 0)
			expect(stats.puddleRadius).toBeNear(expected[1])
			expect(stats.puddleSeconds).toBe(expected[2])
		end
	end)
end)
