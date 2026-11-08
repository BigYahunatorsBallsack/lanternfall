--!strict
-- Native projectile-family sequencing, material reload selection and Harpoon targeting/preview rules.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local S = game:GetService("ServerScriptService").Server.Services.WeaponService
local Compute = require(S.WeaponStats).compute
local Projectile, Runtime, Target = require(S.BrotatoProjectile), require(S.BrotatoRuntime), require(S.WeaponTarget)
local function weapon(id, sheet)
	local c = Config.Weapons[id]
	return {
		id = id,
		uid = 1,
		ownerId = 1,
		config = c,
		tier = c.minTier,
		state = {},
		stats = Compute(c, c.minTier, sheet or {}, nil, Config.Player.minWeaponCooldown),
	}
end
local function context()
	local nextId = 0
	return {
		x = 0,
		z = 0,
		slot = 1,
		slotCount = 1,
		now = 100,
		active = true,
		nearestEnemies = function(_, _, _, _, _, out)
			out[1] = 1
			return 1
		end,
		enemyPosition = function()
			return 40, 0
		end,
		random = function()
			return 0.5
		end,
		nextId = function()
			nextId += 1
			return nextId
		end,
		emit = function() end,
	}
end
describe("Native projectile starting rules", function()
	it("modifies every fifth Javelin volley, including all pellets, without leaking its stats", function()
		local w, ctx = weapon("Javelin"), context()
		w.stats.count = 3
		for _ = 1, 5 do
			assert(Projectile.fire(w, ctx))
		end
		for i = 1, 12 do
			expect(w.state.projectiles[i].stats.critChance).toBe(0)
		end
		for i = 13, 15 do
			expect(w.state.projectiles[i].stats.critChance).toBe(1)
		end
		expect(w.stats.critChance).toBe(0)
		assert(Projectile.fire(w, ctx))
		expect(w.state.projectiles[16].stats.critChance).toBe(0)
	end)
	it("adds Javelin's temporary Crit Chance before the cap, preserving negative player chance", function()
		local w, ctx = weapon("Javelin", { critChance = -100 }), context()
		for _ = 1, 5 do
			assert(Projectile.fire(w, ctx))
		end
		expect(w.state.projectiles[5].stats.critChance).toBe(0)
	end)
	it("reloads the highest eligible cooldown once per collected material and skips active recoil", function()
		local a = weapon("Blunderbuss")
		local b = weapon("Blunderbuss")
		local other = weapon("Javelin")
		a.cooldownLeft = 3
		b.cooldownLeft = 5
		other.cooldownLeft = 100
		Runtime.reloadFromMaterials({ a, b, other }, 1, 100)
		expect(b.cooldownLeft).toBe(0)
		expect(a.cooldownLeft).toBe(3)
		a.state.shootingUntil = 101
		b.cooldownLeft = 2
		Runtime.reloadFromMaterials({ a, b, other }, 1, 100)
		expect(a.cooldownLeft).toBe(3)
		expect(b.cooldownLeft).toBe(0)
		a.state.shootingUntil = 0
		b.cooldownLeft = 5
		Runtime.reloadFromMaterials({ a, b, other }, 2, 100)
		expect(a.cooldownLeft).toBe(0)
		expect(b.cooldownLeft).toBe(0)
		expect(other.cooldownLeft).toBe(100)
	end)
	it("keeps Harpoon pull nonpositive and maximum range above its fixed minimum", function()
		local w = weapon("HarpoonGun", { range = -10000 })
		expect(w.stats.knockback).toBe(-3)
		expect(w.stats.range).toBe(32.5)
		expect(weapon("HarpoonGun", { knockback = 40 }).stats.knockback).toBe(0)
		local Preview = require(folderProxy("src/client", "Client").UI.OfferText)
		expect(Preview.stats("HarpoonGun", 2, { range = -10000 }).knockback).toBe(-3)
		expect(Preview.stats("HarpoonGun", 2, { range = -10000 }).range).toBe(32.5)
		expect(weapon("TranqRifle", { bounce = 5 }).stats.bounce).toBe(0)
	end)
	it("ignores all targets at or below the Harpoon minimum, including a previously kept one", function()
		local w = weapon("HarpoonGun")
		w.state.targetId = 1
		local positions = { 29, 30, 31, 60 }
		local ctx = context()
		ctx.queryCircle = function(_, _, _, _, out)
			for i = 1, 4 do
				out[i] = i
			end
			return 4
		end
		ctx.enemyPosition = function(_, id)
			return positions[id], 0
		end
		local out = {}
		expect(Target.pick(w, ctx, 80, 1, out, 30)).toBe(1)
		expect(out[1]).toBe(3)
	end)
end)
