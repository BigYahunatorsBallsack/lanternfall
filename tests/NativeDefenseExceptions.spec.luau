--!strict
-- Original Sticky Grenade disables its flight hitbox; PlayerExplosion uses itself as origin and bypasses ranged-weapon deflection.
loadHelper("tests/helpers/RobloxMock.luau")
local W = game:GetService("ServerScriptService").Server.Services.WeaponService
local Projectile = require(W.BrotatoProjectile)
local Combat = require(W.BrotatoCombat)
local function fixture()
	local stats = {
		damage = 8,
		critChance = 0,
		critDamage = 2,
		range = 20,
		projectileSpeed = 10,
		projectileRadius = 0.1,
		stickyDistance = 4,
		stickyFuse = 0.75,
		explosionRadius = 16,
	}
	local w = {
		id = "StickyGrenade",
		ownerId = 17,
		tier = 1,
		config = { kind = "Ranged", scaling = {} },
		stats = stats,
		state = {},
	}
	local hits, serial = {}, 0
	local ctx = {
		now = 0,
		x = 0,
		z = 0,
		active = false,
		random = function()
			return 0.5
		end,
		nextId = function()
			serial += 1
			return serial
		end,
		emit = function() end,
		enemyPosition = function()
			return 10, 0
		end,
		querySegment = function(_, _, _, _, _, _, out)
			out[1] = 1
			return 1
		end,
		queryCircle = function(_, _, _, _, out)
			out[1] = 1
			return 1
		end,
		hit = function(_, _, id, _, mode)
			table.insert(hits, { id = id, mode = mode })
			return false
		end,
	}
	Projectile.setDefense({
		active = function()
			error("Disabled flight hitboxes and PlayerExplosion origins must not query ranged defense")
		end,
		target = function()
			error("No forced bounce permitted")
		end,
		overlaps = function()
			return true
		end,
	})
	Combat.configure({})
	return w, ctx, hits
end
describe("Original defense exceptions", function()
	it("lets a Sticky Grenade attach and fuse beside an active shield without a contact hit or reflection", function()
		local w, ctx, hits = fixture()
		Projectile.launch(w, ctx, 0, 0, 1, 0, w.stats)
		Projectile.step(w, ctx, 1)
		local shot = w.state.projectiles[1]
		expect(shot.targetId).toBe(1)
		expect(shot.fuseUntil).toBeNear(0.75)
		expect(shot.bounces).toBe(0)
		expect(shot.travelRange).toBe(nil)
		expect(#hits).toBe(0)
		ctx.now = 0.75
		Projectile.step(w, ctx, 0.75)
		expect(#hits).toBe(1)
		expect(hits[1].mode).toBe("Explosion")
		expect(#w.state.projectiles).toBe(0)
	end)
	it("keeps a ranged weapon's separate explosion eligible for damage despite projectile defense", function()
		local w, ctx, hits = fixture()
		Combat.explode(w, ctx, 10, 0)
		expect(#hits).toBe(1)
		expect(hits[1].id).toBe(1)
		expect(hits[1].mode).toBe("Explosion")
		expect(w.stats.damage).toBe(8)
	end)
end)
