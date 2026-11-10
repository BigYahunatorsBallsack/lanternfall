--!strict
-- Original Boomerang tier facts, real behavior trajectories, per-leg hits and return-locked cooldown.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local S = game:GetService("ServerScriptService").Server.Services.WeaponService
local Behavior = require(S.Behaviors.Boomerang)
local Compute = require(S.WeaponStats).compute
local Combat = require(S.BrotatoCombat)
Combat.configure({})
local function fixture(tier, sheet)
	local w = {
		id = "Boomerang",
		uid = 1,
		ownerId = 1,
		tier = tier,
		config = Config.Weapons.Boomerang,
		state = {},
		stats = Compute(Config.Weapons.Boomerang, tier, sheet or {}, nil, Config.Player.minWeaponCooldown),
		cooldownLeft = 0.5,
	}
	local hits, effects, serial = 0, {}, 0
	local ctx = { x = 0, z = 0, slot = 1, slotCount = 1, active = true, now = 0 }
	function ctx.nearestEnemies(_, _, _, _, _, out)
		out[1] = 1
		return 1
	end
	function ctx.enemyPosition()
		return 20, 0
	end
	function ctx.random()
		return 0.5
	end
	function ctx.nextId()
		serial += 1
		return serial
	end
	function ctx.emit(_, _, effect)
		table.insert(effects, effect)
	end
	function ctx.setHitDirection() end
	function ctx.querySegment(_, _, _, _, _, _, out)
		out[1] = 1
		return 1
	end
	function ctx.hit()
		hits += 1
		return false
	end
	local function step(dt)
		ctx.now += dt
		Behavior.step(w, ctx, dt)
		if ctx.active then
			w.cooldownLeft -= dt
		end
	end
	return w, ctx, step, function()
		return hits
	end, effects
end
describe("Native Boomerang", function()
	it("preserves four original tiers, native cooldown, unusual scaling, range and no bounce", function()
		local damages = { 6, 9, 12, 17 }
		for tier = 1, 4 do
			local w = fixture(tier)
			expect(w.stats.damage).toBe(damages[tier])
			expect(w.stats.projectileSpeed).toBe(85 + 5 * tier)
			expect(w.stats.range).toBe(27.5 + 2.5 * tier)
			expect(w.stats.cooldown).toBeNear((32 - 2 * tier) / 60)
			expect(w.stats.noBounce).toBe(1)
		end
		local w = fixture(1, { meleeDamage = 10, speed = 20, rangedDamage = 100 })
		expect(w.stats.damage).toBe(12)
		expect(Config.Weapons.Boomerang.available).toBe(false)
	end)
	it("eases to the full reach, holds the apex and hits each target once on each leg", function()
		local w, ctx, step, hits = fixture(1)
		assert(Behavior.fire(w, ctx))
		local shot = w.state.boomerangs[1]
		local start = shot.startX
		step(0.2)
		expect(shot.x - start).toBeNear(30 * (1 - (1 - 0.2 / (30 / 90 * 1.6)) ^ 2))
		expect(hits()).toBe(1)
		step(0.2)
		expect(hits()).toBe(1)
		step(0.2)
		expect(shot.phase).toBe("Apex")
		expect(shot.x - start).toBeNear(30)
		step(0.1)
		expect(hits()).toBe(1)
		step(0.1)
		expect(shot.phase).toBe("Back")
		expect(hits()).toBe(2)
		for _ = 1, 30 do
			step(0.05)
		end
		expect(#w.state.boomerangs).toBe(0)
		expect(hits()).toBe(2)
	end)
	it("waits for every projectile, freezes cooldown during flight and returns to the moving carrier", function()
		local w, ctx, step = fixture(1, { projectiles = 2 })
		assert(Behavior.fire(w, ctx))
		expect(#w.state.boomerangs).toBe(3)
		for _ = 1, 5 do
			step(0.1)
		end
		expect(w.cooldownLeft).toBeNear(0.5)
		expect(Behavior.fire(w, ctx)).toBe(false)
		ctx.x, ctx.z = 5, 8
		for _ = 1, 40 do
			step(0.05)
		end
		expect(#w.state.boomerangs).toBe(0)
		expect(w.cooldownLeft < 0.5).toBe(true)
	end)
	it("clears flight at the four-second limit or when the carrier is down", function()
		local w, ctx, step, _, effects = fixture(1)
		assert(Behavior.fire(w, ctx))
		ctx.x = 10000
		for _ = 1, 81 do
			step(0.05)
		end
		expect(#w.state.boomerangs).toBe(0)
		expect(effects[#effects].kind).toBe("End")
		ctx.x = 0
		assert(Behavior.fire(w, ctx))
		ctx.active = false
		step(0.01)
		expect(#w.state.boomerangs).toBe(0)
	end)
	it("keeps flight alive while a living carrier temporarily cannot attack", function()
		local w, ctx, step = fixture(1)
		assert(Behavior.fire(w, ctx))
		Combat.configure({
			ownerAlive = function()
				return true
			end,
		})
		ctx.active = false
		step(0.1)
		expect(#w.state.boomerangs).toBe(1)
		Combat.configure({})
	end)
	it("emits no projectiles when the resolved count is zero", function()
		local w, ctx, _, _, effects = fixture(1, { projectiles = -1 })
		expect(w.stats.count).toBe(0)
		assert(Behavior.fire(w, ctx))
		expect(#w.state.boomerangs).toBe(0)
		expect(#effects).toBe(0)
	end)
end)
