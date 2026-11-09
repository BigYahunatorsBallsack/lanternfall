--!strict
-- A Molotov creates one fire patch on its first impact or at maximum travel, including piercing volleys.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Service = game:GetService("ServerScriptService").Server.Services.WeaponService
local Projectile = require(Service.BrotatoProjectile)
local function setup(collisions)
	local config = require(Shared.Config).Weapons.Molotov
	local stats = require(Service.WeaponStats).compute(config, 1, {}, nil, 0)
	stats.pierce = 2
	local weapon = { id = "Molotov", uid = 1, ownerId = 1, tier = 1, config = config, state = {}, stats = stats }
	local patches, hits = {}, {}
	Projectile.setFirePuddle(function(_, x, z)
		table.insert(patches, { x = x, z = z })
	end)
	local serial = 0
	local ctx = {
		x = 0,
		z = 0,
		slot = 1,
		slotCount = 1,
		now = 0,
		active = true,
		nearestEnemies = function(_, _, _, _, _, out)
			out[1] = 1
			return 1
		end,
		enemyPosition = function(_, id)
			return 8 + id, 0
		end,
		nextId = function()
			serial += 1
			return serial
		end,
		random = function()
			return 0.5
		end,
		emit = function() end,
		querySegment = function(_, _, _, _, _, _, out)
			if not collisions then
				return 0
			end
			for id = 1, 3 do
				out[id] = id
			end
			return 3
		end,
		hit = function(_, _, id)
			table.insert(hits, id)
			return false
		end,
	}
	return weapon, ctx, patches, hits
end
describe("Molotov projectile fire placement", function()
	it("creates exactly one patch for three piercing impacts", function()
		local weapon, ctx, patches, hits = setup(true)
		assert(Projectile.fire(weapon, ctx))
		Projectile.step(weapon, ctx, 0.1)
		expect(#hits).toBe(3)
		expect(#patches).toBe(1)
		expect(patches[1].x).toBeNear(9)
		Projectile.step(weapon, ctx, 1)
		expect(#patches).toBe(1)
	end)
	it("creates a patch at the range endpoint even without a hit", function()
		local weapon, ctx, patches, hits = setup(false)
		assert(Projectile.fire(weapon, ctx))
		local shot = weapon.state.projectiles[1]
		local expected = shot.x + shot.dx * shot.stats.range
		Projectile.step(weapon, ctx, 0.5)
		expect(#hits).toBe(0)
		expect(#patches).toBe(1)
		expect(patches[1].x).toBeNear(expected)
	end)
end)
