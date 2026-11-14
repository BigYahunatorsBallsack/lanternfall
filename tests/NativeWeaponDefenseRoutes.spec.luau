--!strict
-- Exercise real configured ranged behavior modules against active/inactive defense; secondary projectiles retain melee origin.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local S = game:GetService("ServerScriptService").Server.Services.WeaponService
local Compute = require(S.WeaponStats).compute
local Projectile = require(S.BrotatoProjectile)
local Combat = require(S.BrotatoCombat)
Combat.configure({})
local active = true
Projectile.setDefense({
	active = function()
		return active, true
	end,
	target = function()
		return nil, nil
	end,
	overlaps = function()
		return false
	end,
})
local function fixture(id, definition)
	local hits, serial = 0, 0
	local w = {
		id = id,
		uid = 1,
		ownerId = 1,
		tier = 1,
		config = definition,
		state = {},
		stats = Compute(definition, 1, {}, nil, Config.Player.minWeaponCooldown),
		cooldownLeft = 1,
	}
	local ctx = { x = 0, z = 0, slot = 1, slotCount = 1, active = false, now = 0 }
	function ctx.nearestEnemies(_, _, _, _, _, out)
		out[1] = 1
		return 1
	end
	function ctx.enemyPosition()
		return math.max(20, (w.stats.minimumRange or 0) + 1), 0
	end
	function ctx.random()
		return 0.5
	end
	function ctx.nextId()
		serial += 1
		return serial
	end
	function ctx.emit() end
	function ctx.setHitDirection() end
	function ctx.querySegment(_, _, _, _, _, _, out)
		out[1] = 1
		return 1
	end
	function ctx.queryCircle(_, _, _, _, out)
		out[1] = 1
		return 1
	end
	function ctx.bounceTarget()
		return nil
	end
	function ctx.hit()
		hits += 1
		return false
	end
	return w, ctx, function()
		return hits
	end
end
describe("Native configured projectile defense routes", function()
	local ids = {}
	for id, def in Config.Weapons do
		if def.kind == "Ranged" and id ~= "Boomerang" and id ~= "StickyGrenade" then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for _, id in ids do
		it("intercepts " .. id .. " before hit and still permits its ordinary hit without an active shield", function()
			local def = Config.Weapons[id]
			local behavior = require(S.Behaviors[def.behavior])
			local w, ctx, hits = fixture(id, def)
			active = true
			assert(behavior.fire(w, ctx), id .. " must really fire")
			assert(w.state.projectiles and #w.state.projectiles > 0, id .. " must launch actual shots")
			behavior.step(w, ctx, 1 / 60)
			expect(hits()).toBe(0)
			for _, shot in w.state.projectiles do
				expect(shot.bounces).toBe((w.stats.bounce or 0) - 1)
				expect(shot.stats.knockback).toBe(0)
				expect(shot.travelRange).toBeNear(1010)
			end
			w, ctx, hits = fixture(id, def)
			active = false
			assert(behavior.fire(w, ctx))
			behavior.step(w, ctx, 1 / 60)
			expect(hits() > 0).toBe(true)
		end)
	end
	it("keeps source melee on-hit projectiles outside the ranged defense predicate", function()
		active = true
		local def = Config.Weapons.CactiClub
		local w, ctx, hits = fixture("CactiClub", def)
		-- The real melee hit queues its native on-hit volley; the same owning melee weapon launches that volley.
		assert(require(S.Behaviors[def.behavior]).fire(w, ctx))
		-- Unit ignores the primary victim; the outward volley meets a different enemy.
		function ctx.querySegment(_, _, _, _, _, _, out)
			out[1] = 2
			return 1
		end
		local before = hits()
		assert(w.state.secondaryShots and #w.state.secondaryShots > 0)
		require(S.Behaviors[def.behavior]).step(w, ctx, 1 / 60)
		expect(hits() > before).toBe(true)
	end)
end)
