--!strict
-- Native sinusoidal enemy projectiles enter from outside the arena, follow the same client/server path and hit along that path.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Motion = require(Shared.Util.NativeBulletMotion)
local Feed = require(Shared.Net.ShotFeed)
local Volleys = require(game:GetService("ServerScriptService").Server.Services.EnemySim.Volleys)
local function volleys()
	return Volleys.new({ playerRadius = 0.1, minX = 0, maxX = 100, minZ = 0, maxZ = 100, obstacles = {} })
end
local motion = { amplitudeX = 0, amplitudeZ = 20, frequencyX = 3, frequencyZ = 3 }
describe("Native environmental projectile path", function()
	it("reconstructs native fixed physics Euler velocity offsets on both axes", function()
		local x, z = 0, 0
		for frame = 1, 120 do
			x += 10 / 60
			z += math.sin(frame / 60 * 3) * 20 / 2 / 60
			local px, pz = Motion.offset(frame / 60, 1, 0, 10, motion)
			expect(px).toBeNear(x, 0.00001)
			expect(pz).toBeNear(z, 0.00001)
		end
	end)
	it(
		"enters offscreen instead of dying at the ordinary arena bound and exits after its native directional margin",
		function()
			local v = volleys()
			v:fire(-6.4, 50, 1, 0, 20, math.huge, 0.1, 8, motion)
			v:step(0.1, {}, {}, 0)
			expect(v:getCount()).toBe(1)
			for _ = 1, 60 do
				v:step(0.1, {}, {}, 0)
			end
			expect(v:getCount()).toBe(0)
		end
	)
	it("hits the curved path once and misses the obsolete straight path", function()
		local v = volleys()
		local _, z = Motion.offset(1, 1, 0, 10, motion)
		v:fire(0, 30, 1, 0, 10, math.huge, 0.1, 8, motion)
		v:step(1, { 10, 10 }, { 30, 30 + z }, 2)
		expect(v.hitCount).toBe(1)
		expect(v.hits[1]).toBe(2)
		expect(v.hits[2]).toBe(8)
		expect(v:getCount()).toBe(0)
	end)
	it("keeps ordinary packets byte-for-byte sized and roundtrips mixed environmental metadata", function()
		local shot = { id = 1, x = -6.4, z = 30, dx = 1, dz = 0, speed = 20, range = 120, at = 10 }
		local legacy = Feed.encode({ fired = { shot }, ended = {} })
		expect(buffer.len(legacy)).toBe(45)
		expect(Feed.decode(legacy).fired[1].motion).toBe(nil)
		local curved = table.clone(shot)
		curved.id = 2
		curved.motion = motion
		local b = Feed.encode({ reset = true, fired = { shot, curved }, ended = { 2, 20 } })
		local decoded = Feed.decode(b)
		expect(decoded.reset).toBe(true)
		expect(decoded.fired[1].motion).toBe(nil)
		expect(decoded.fired[2].motion.amplitudeZ).toBe(20)
		expect(decoded.fired[2].motion.frequencyZ).toBe(3)
		expect(decoded.ended[2]).toBe(20)
		local bad = buffer.create(buffer.len(b) - 1)
		buffer.copy(bad, 0, b, 0, buffer.len(bad))
		expect(#Feed.decode(bad).fired).toBe(0)
	end)
end)
