--!strict
-- Source volley geometry preserves constant spread, mirrored offsets and per-projectile speeds for hostile and charmed callers.
loadHelper("tests/helpers/RobloxMock.luau")
local Volley = require(game:GetService("ReplicatedStorage").Shared.Util.NativeEnemyVolley)
local rule = { count = 2, spread = 0.1, constantSpread = true, offsetX = 2, offsetZ = -3, speedStep = -2 }
local function shots(tx, tz, count)
	local found = {}
	local copy = table.clone(rule)
	copy.count = count or copy.count
	Volley.emit(copy, 0, 0, tx, tz, 60, function()
		return 0.5
	end, function(x, z, dx, dz, speed)
		table.insert(found, { x = x, z = z, dx = dx, dz = dz, speed = speed })
	end)
	return found
end
describe("Native enemy volleys", function()
	it("uses evenly spaced source angles and each projectile's own speed", function()
		local found = shots(32, -3)
		expect(#found).toBe(2)
		expect(found[1].dx).toBeNear(math.cos(-0.1))
		expect(found[1].dz).toBeNear(math.sin(-0.1))
		expect(found[2].dz).toBeNear(math.sin(0.1))
		expect(found[1].speed).toBe(60)
		expect(found[2].speed).toBe(58)
	end)
	it("mirrors the transform's x offset but retains its vertical offset", function()
		local found = shots(-32, -3)
		expect(found[1].x).toBe(-2)
		expect(found[1].z).toBe(-3)
		expect(found[1].dx).toBeNear(-math.cos(0.1))
	end)
	it("keeps the middle projectile aimed and does not invent a spread for a single bullet", function()
		local found = shots(32, -3, 3)
		expect(found[2].dx).toBeNear(1)
		expect(found[2].dz).toBeNear(0)
		expect(found[3].speed).toBe(56)
		local single = shots(32, -3, 1)
		expect(single[1].dx).toBeNear(1)
		expect(single[1].dz).toBeNear(0)
	end)
end)
