--!strict
-- Production native projectile interception skips hit effects and preserves original forced-bounce state.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local W = game:GetService("ServerScriptService").Server.Services.WeaponService
local Projectile = require(W.BrotatoProjectile)
local Combat = require(W.BrotatoCombat)
local function fixture(kind, targetX, targetZ)
	local hits, events, effects, overlap = {}, {}, {}, true
	local shield, capable = true, true
	local serial = 0
	local stats = {
		damage = 10,
		projectileSpeed = 100,
		projectileRadius = 0.2,
		range = 20,
		pierce = 2,
		bounce = 0,
		bounceDamage = 0.8,
		nativeIntegerFalloff = 1,
		critChance = 0,
		critDamage = 2,
		knockback = -2,
		nativeMineChance = 1,
		secondaryCount = 1,
		explosionRadius = 2,
	}
	local weapon = {
		id = "Test",
		uid = 1,
		ownerId = 17,
		tier = 1,
		config = { kind = kind, scaling = {} },
		stats = stats,
		state = {},
	}
	local ctx = {
		x = 0,
		z = 0,
		now = 0,
		active = false,
		random = function()
			return 0.5
		end,
		nextId = function()
			serial += 1
			return serial
		end,
		emit = function(_, _, event)
			table.insert(events, event)
		end,
		setHitDirection = function() end,
		enemyPosition = function()
			return 5, 0
		end,
		querySegment = function(_, _, _, _, _, _, out)
			out[1] = 1
			return 1
		end,
		queryCircle = function()
			return 0
		end,
		bounceTarget = function()
			error("Radius-limited Arsenal bounce must not select a deflection target")
		end,
		hit = function()
			table.insert(hits, true)
			return false
		end,
	}
	Combat.configure({
		spawnMine = function()
			table.insert(effects, true)
		end,
	})
	Projectile.setDefense({
		active = function()
			return shield, capable
		end,
		target = function()
			return targetX, targetZ
		end,
		overlaps = function()
			return overlap
		end,
	})
	Projectile.launch(weapon, ctx, 0, 0, 1, 0, stats)
	return weapon,
		ctx,
		hits,
		events,
		effects,
		function(value)
			overlap = value
		end,
		function(value)
			shield = value
		end,
		function(value)
			capable = value
		end
end
local function reentryFixture()
	local w, ctx, hits, events, effects, overlap, shield, capable = fixture("Ranged", 5, 50)
	w.state.projectiles[1].stats.secondaryCount = 0
	w.state.projectiles[1].stats.range = 200
	ctx.present = 1
	ctx.querySegment = function(_, _, _, _, _, _, out)
		if ctx.present then
			out[1] = ctx.present
			return 1
		end
		return 0
	end
	return w, ctx, hits, overlap, shield, capable
end
describe("Native projectile deflection", function()
	it("intercepts before damage, secondary shots, explosions and mine effects without spending pierce", function()
		local original = require(Shared.Config.JungleDeflectCharges).source.projectileBounce
		local configured = require(Shared.Config.Combat).nativeProjectileBounce
		expect(configured.rangePoints).toBe(original.rangePoints)
		expect(configured.additionalDistancePoints).toBe(original.additionalDistancePoints)
		local w, ctx, hits, events, effects = fixture("Ranged", 5, 50)
		Projectile.step(w, ctx, 0.1)
		local shot = w.state.projectiles[1]
		expect(#hits).toBe(0)
		expect(#effects).toBe(0)
		expect(w.state.secondaryShots).toBe(nil)
		expect(shot.left).toBe(3)
		expect(shot.hit[1]).toBe(nil)
		expect(shot.bounces).toBe(-1)
		expect(shot.stats.damage).toBe(8)
		expect(w.stats.damage).toBe(10)
		expect(shot.stats.knockback).toBe(0)
		expect(shot.stats.range).toBeNear(20)
		expect(shot.travelRange).toBeNear(1010)
		expect(shot.dx).toBeNear(0)
		expect(shot.dz).toBeNear(1)
		expect(events[#events - 1].kind).toBe("End")
		expect(events[#events].kind).toBe("Fire")
		expect(events[1].range).toBeNear(20)
		expect(events[#events].range).toBeNear(1010)
	end)
	it("does not repeatedly enter the same shield until the projectile leaves its hurt circle", function()
		local w, ctx, _, _, _, leave = fixture("Ranged", 5, 50)
		Projectile.step(w, ctx, 0.1)
		Projectile.step(w, ctx, 0.1)
		expect(w.state.projectiles[1].bounces).toBe(-1)
		leave(false)
		Projectile.step(w, ctx, 0.1)
		expect(w.state.projectiles[1].bounces).toBe(-2)
		expect(w.state.projectiles[1].stats.damage).toBe(6)
	end)
	it("uses a random angle without another enemy and preserves positive-axis zero-vector aiming", function()
		local w, ctx = fixture("Ranged", nil, nil)
		Projectile.step(w, ctx, 0.1)
		expect(w.state.projectiles[1].dx).toBeNear(1)
		expect(w.state.projectiles[1].dz).toBeNear(0)
		w, ctx = fixture("Ranged", 5, 0)
		Projectile.step(w, ctx, 0.1)
		expect(w.state.projectiles[1].dx).toBeNear(1)
		expect(w.state.projectiles[1].dz).toBeNear(0)
	end)
	it("does not shield projectile effects originating from a melee weapon", function()
		local w, ctx, hits = fixture("Melee", 5, 50)
		Projectile.step(w, ctx, 0.1)
		expect(#hits).toBe(1)
	end)
	it(
		"does not turn shield activation into a new entry while a previously damaging projectile remains inside",
		function()
			local w, ctx, hits, overlap, shield = reentryFixture()
			shield(false)
			Projectile.step(w, ctx, 0.01)
			expect(#hits).toBe(1)
			shield(true)
			Projectile.step(w, ctx, 0.01)
			expect(w.state.projectiles[1].bounces).toBe(0)
			overlap(false)
			ctx.present = nil
			Projectile.step(w, ctx, 0.01)
			overlap(true)
			ctx.present = 1
			Projectile.step(w, ctx, 0.01)
			expect(w.state.projectiles[1].bounces).toBe(-1)
			expect(#hits).toBe(1)
		end
	)
	it("records an ignored reentry before the shield activates without dealing a second hit", function()
		local w, ctx, hits, overlap, shield = reentryFixture()
		shield(false)
		Projectile.step(w, ctx, 0.01)
		overlap(false)
		ctx.present = nil
		Projectile.step(w, ctx, 0.01)
		overlap(true)
		ctx.present = 1
		Projectile.step(w, ctx, 0.01)
		shield(true)
		Projectile.step(w, ctx, 0.01)
		expect(w.state.projectiles[1].bounces).toBe(0)
		expect(#hits).toBe(1)
		overlap(false)
		ctx.present = nil
		Projectile.step(w, ctx, 0.01)
		overlap(true)
		ctx.present = 1
		Projectile.step(w, ctx, 0.01)
		expect(w.state.projectiles[1].bounces).toBe(-1)
	end)
	it("keeps separate entry state for two simultaneously overlapping reflectors", function()
		local w, ctx = reentryFixture()
		Projectile.step(w, ctx, 0.01)
		ctx.present = 2
		Projectile.step(w, ctx, 0.01)
		expect(w.state.projectiles[1].bounces).toBe(-2)
		ctx.present = 1
		Projectile.step(w, ctx, 0.01)
		expect(w.state.projectiles[1].bounces).toBe(-2)
	end)
	it("preserves ordinary ignored-hit behavior without allocating reflection-overlap state", function()
		local w, ctx, hits, _, shield, capable = reentryFixture()
		shield(false)
		capable(false)
		Projectile.step(w, ctx, 0.01)
		Projectile.step(w, ctx, 0.01)
		expect(#hits).toBe(1)
		expect(w.state.projectiles[1].defenseOverlaps).toBe(nil)
	end)
	it("rechecks live defense when an earlier hit kills a later collision candidate", function()
		local w, ctx = reentryFixture()
		local alive = true
		ctx.querySegment = function(_, _, _, _, _, _, out)
			out[1], out[2] = 1, 2
			return 2
		end
		ctx.enemyPosition = function(_, id)
			return id * 2, 0
		end
		ctx.hit = function(_, _, id)
			if id == 1 then
				alive = false
			end
			return false
		end
		Projectile.setDefense({
			active = function(id)
				return id == 2 and alive, id == 2 and alive
			end,
			target = function()
				error("A dead candidate cannot reflect")
			end,
			overlaps = function()
				return alive
			end,
		})
		Projectile.step(w, ctx, 0.1)
		expect(w.state.projectiles[1].bounces).toBe(0)
		expect(w.state.projectiles[1].travelRange).toBe(nil)
	end)
end)
