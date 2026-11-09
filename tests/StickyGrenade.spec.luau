--!strict
-- The sticky lifecycle carries no contact damage and keeps its own shot snapshot while targets move or die.
loadHelper("tests/helpers/RobloxMock.luau")
local S = game:GetService("ServerScriptService").Server.Services
local Sticky = require(S.WeaponService.StickyGrenadeShot)
local function fixture()
	local positions = { [1] = { 10, 0 } }
	local hits, blasts = {}, {}
	local ctx = { now = 1 }
	function ctx:enemyPosition(id)
		local p = positions[id]
		if p then
			return p[1], p[2]
		end
		return nil, nil
	end
	function ctx:querySegment(_, _, _, _, _, out)
		local n = 0
		for id in positions do
			n += 1
			out[n] = id
		end
		return n
	end
	function ctx:queryCircle(_, _, _, out)
		local n = 0
		for id in positions do
			n += 1
			out[n] = id
		end
		return n
	end
	function ctx:emit(_, effect)
		table.insert(blasts, effect)
	end
	function ctx:hit(_, id)
		table.insert(hits, id)
		return false
	end
	local stats = {
		range = 20,
		projectileSpeed = 10,
		stickyDistance = 4,
		stickyFuse = 0.75,
		explosionRadius = 16,
		damage = 8,
		critChance = 0,
	}
	local shot = { id = 1, x = 0, z = 0, dx = 1, dz = 0, flown = 0, stats = stats }
	local weapon = { ownerId = 1, stats = stats, config = { scaling = { rangedDamage = 0.8 } } }
	return positions, hits, blasts, ctx, shot, weapon
end
describe("Sticky Grenade lifecycle", function()
	it("attaches within the original center distance without contact damage and follows the offset", function()
		local positions, hits, events, ctx, shot, weapon = fixture()
		expect(Sticky.step(weapon, ctx, shot, 1)).toBe(false)
		expect(shot.x).toBe(6)
		expect(shot.fuseUntil).toBe(1.75)
		expect(#hits).toBe(0)
		positions[1] = { 14, 2 }
		ctx.now = 1.5
		Sticky.step(weapon, ctx, shot, 0.5)
		expect(shot.x).toBe(10)
		expect(shot.z).toBe(2)
		expect(#hits).toBe(0)
		ctx.now = 1.75
		expect(Sticky.step(weapon, ctx, shot, 0.25)).toBe(true)
		expect(#hits).toBe(1)
		expect(events[#events].kind).toBe("Blast")
	end)
	it("keeps the last position if the attached target dies", function()
		local positions, _, events, ctx, shot, weapon = fixture()
		Sticky.step(weapon, ctx, shot, 1)
		positions[1] = nil
		ctx.now = 1.75
		expect(Sticky.step(weapon, ctx, shot, 0.75)).toBe(true)
		expect(events[#events].x).toBe(6)
	end)
	it("starts the full fuse on the ground when flight range ends", function()
		local positions, hits, _, ctx, shot, weapon = fixture()
		positions[1] = nil
		Sticky.step(weapon, ctx, shot, 2)
		expect(shot.x).toBe(20)
		ctx.now = 1.74
		expect(Sticky.step(weapon, ctx, shot, 0.74)).toBe(false)
		ctx.now = 1.75
		expect(Sticky.step(weapon, ctx, shot, 0.01)).toBe(true)
		expect(#hits).toBe(0)
	end)
	it("rolls explosion crits independently of the direct hit and reports one attack total", function()
		local Combat = require(S.WeaponService.BrotatoCombat)
		local observed, reported = {}, nil
		Combat.configure({
			explosionResolved = function(owner, kills)
				reported = { owner, kills }
			end,
		})
		local stats = { damage = 8, critChance = 0.03, explosionRadius = 10, explosionChance = 1, knockback = 0 }
		local weapon = { ownerId = 7, stats = stats, config = { scaling = {} }, state = {} }
		local ctx = {}
		function ctx:enemyPosition(_)
			return 0, 0
		end
		function ctx:queryCircle(_, _, _, out)
			out[1], out[2] = 1, 2
			return 2
		end
		function ctx:emit(...) end
		function ctx:random()
			return 0
		end
		function ctx:hit(w, id, _, mode)
			table.insert(observed, { chance = w.stats.critChance, mode = mode })
			return id == 2
		end
		Combat.hit(weapon, ctx, 1, nil, stats, true)
		expect(#observed).toBe(2)
		expect(observed[1].chance).toBe(1)
		expect(observed[2].chance).toBe(0.03)
		expect(observed[2].mode).toBe("Explosion")
		expect(reported[1]).toBe(7)
		expect(reported[2]).toBe(1)
		expect(weapon.stats).toBe(stats)
	end)
end)
