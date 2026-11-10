--!strict
-- Native Flail timing and tip criticals; exercises the production behavior without replacing Arsenal.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Service = game:GetService("ServerScriptService").Server.Services.WeaponService
local Whip = require(Service.BrotatoWhip)
local function setup()
	local config = assert(Config.Weapons.Flail, "Flail is missing")
	local weapon = {
		id = "Flail",
		ownerId = 1,
		tier = 1,
		config = config,
		uid = 1,
		state = {},
		stats = require(Service.WeaponStats).compute(
			config,
			1,
			{ critChance = -100 },
			nil,
			Config.Player.minWeaponCooldown
		),
	}
	local hits = {}
	local segment
	local ctx = {
		setHitDirection = function(self, dx, dz)
			self.hitDirX, self.hitDirZ = dx, dz
		end,
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
			if not segment then
				return 10, 0
			end
			local offset = if id == 1 then 0 elseif id == 2 then 3.99 else 4.01
			return segment.x + offset, segment.z
		end,
		querySegment = function(_, _, _, x, z, radius, out)
			segment = { x = x, z = z, radius = radius }
			for i = 1, 3 do
				out[i] = i
			end
			return 3
		end,
		queryCircle = function(self, x, z, radius, out)
			local n = 0
			for id = 1, 3 do
				local ex, ez = self:enemyPosition(id)
				if (ex - x) ^ 2 + (ez - z) ^ 2 <= radius ^ 2 then
					n += 1
					out[n] = id
				end
			end
			return n
		end,
		hit = function(_, w, id)
			hits[id] = w.stats.critChance
			return false
		end,
		random = function()
			return 0.9
		end,
		emit = function() end,
	}
	return weapon, ctx, hits
end
describe("Native Flail", function()
	it("opens at 0.24 seconds and forces criticals only inside the four-stud tip circle", function()
		local w, ctx, hits = setup()
		expect(Whip.fire(w, ctx)).toBe(true)
		Whip.step(w, ctx, 0.23)
		expect(next(hits)).toBe(nil)
		Whip.step(w, ctx, 0.01)
		expect(hits[1]).toBe(1)
		expect(hits[2]).toBe(1)
		expect(hits[3]).toBe(0)
	end)
	it("keeps the fixed animation lock and tier critical multiplier", function()
		local w = setup()
		local compute = require(Service.WeaponStats).compute
		for tier = 1, 4 do
			local stats = compute(w.config, tier, { attackSpeed = 1000 }, nil, Config.Player.minWeaponCooldown)
			expect(stats.cooldown).toBe(0.48)
			expect(stats.critDamage).toBe(2 + tier * 0.5)
		end
	end)
end)
