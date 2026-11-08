--!strict
-- Whip's source hit window, one hit per target and animation lock through its actual behavior.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Service = game:GetService("ServerScriptService").Server.Services.WeaponService
local Whip = require(Service.Behaviors.Whip)
local function setup()
	local hits, available, segments = {}, { 1 }, {}
	local w = {
		id = "Whip",
		uid = 1,
		state = {},
		stats = require(Service.WeaponStats).compute(Config.Weapons.Whip, 1, {}, nil, Config.Player.minWeaponCooldown),
	}
	local ctx = {
		active = true,
		slot = 1,
		slotCount = 1,
		x = 0,
		z = 0,
		nearestEnemies = function(_, _, _, _, _, out)
			out[1] = 1
			return 1
		end,
		enemyPosition = function(_, id)
			return 10, 0
		end,
		segments = segments,
		querySegment = function(_, x0, z0, x1, z1, radius, out)
			table.insert(segments, { x0 = x0, z0 = z0, x1 = x1, z1 = z1, radius = radius })
			for i, id in available do
				out[i] = id
			end
			return #available
		end,
		hit = function(_, weapon, id)
			table.insert(hits, { id = id, slow = weapon.stats.slow, duration = weapon.stats.slowSeconds })
			return false
		end,
		random = function()
			return 1
		end,
		emit = function() end,
	}
	return w, ctx, hits, available
end
describe("Native Whip attack", function()
	it("does not hit before the 0.24s opening and hits each enemy once during its 0.08s window", function()
		local w, ctx, hits, available = setup()
		expect(Whip.fire(w, ctx)).toBe(true)
		expect(#hits).toBe(0)
		Whip.step(w, ctx, 0.23)
		expect(#hits).toBe(0)
		Whip.step(w, ctx, 0.02)
		expect(#hits).toBe(1)
		table.insert(available, 2)
		Whip.step(w, ctx, 0.02)
		expect(#hits).toBe(2)
		expect(hits[1].slow).toBe(0.5)
		expect(hits[1].duration).toBe(0.5)
		Whip.step(w, ctx, 0.1)
		table.insert(available, 3)
		Whip.step(w, ctx, 0.01)
		expect(#hits).toBe(2)
	end)
	it("waits for the original 0.48s animation, even at very high attack speed", function()
		local w, ctx = setup()
		w.stats = require(Service.WeaponStats).compute(
			Config.Weapons.Whip,
			1,
			{ attackSpeed = 1000 },
			nil,
			Config.Player.minWeaponCooldown
		)
		expect(w.stats.cooldown).toBe(0.48)
		expect(Whip.fire(w, ctx)).toBe(true)
		expect(Whip.fire(w, ctx)).toBe(false)
		Whip.step(w, ctx, 0.48)
		expect(Whip.fire(w, ctx)).toBe(true)
	end)
	it("ends the attack when its owner is inactive and never catches up damage after death", function()
		local w, ctx, hits = setup()
		assert(Whip.fire(w, ctx))
		ctx.active = false
		Whip.step(w, ctx, 0.3)
		expect(#hits).toBe(0)
		ctx.active = true
		Whip.step(w, ctx, 0.1)
		expect(#hits).toBe(0)
	end)
	it("follows the native cubic sprite movement and rotation while the hitbox is open", function()
		local w, ctx = setup()
		assert(Whip.fire(w, ctx))
		local dx, dz = w.state.swing.dx, w.state.swing.dz
		local hx, hz = require(Shared.Util.WeaponPose).anchor(0, 0, 1, 1, "Whip")
		Whip.step(w, ctx, 0.28)
		local segment = ctx.segments[1]
		local along = (segment.x0 - hx) * dx + (segment.z0 - hz) * dz
		local side = -(segment.x0 - hx) * dz + (segment.z0 - hz) * dx
		expect(along).toBeNear(5.0633125 - 1.2 * math.cos(math.rad(0.0875)))
		expect(side).toBeNear(-1.2 * math.sin(math.rad(0.0875)))
		expect(segment.radius).toBe(1.6)
	end)
end)
