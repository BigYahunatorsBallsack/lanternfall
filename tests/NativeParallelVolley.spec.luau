--!strict
-- Source parallel slashes offset along Vector2.tangent and override ordinary fan/specific-angle rules.
loadHelper("tests/helpers/RobloxMock.luau")
local Volley = require(game:GetService("ReplicatedStorage").Shared.Util.NativeEnemyVolley)
local function shots(tx, tz, count)
	local found = {}
	Volley.emit(
		{
			count = count or 2,
			spread = 0.8,
			constantSpread = true,
			offsetX = 0,
			offsetZ = 0,
			speedStep = 5,
			specificDegrees = { 90, 270 },
			parallel = { spacing = 6, angleOffset = 0.05, forwardOffset = 0 },
		},
		0,
		0,
		tx,
		tz,
		30,
		function()
			return 0.5
		end,
		function(x, z, dx, dz, speed)
			table.insert(found, { x, z, dx, dz, speed })
		end
	)
	return found
end
describe("Native parallel slashes", function()
	it("places two rightward slashes on the native tangent instead of a point fan", function()
		local s = shots(20, 0)
		expect(s[1][1]).toBeNear(0)
		expect(s[1][2]).toBeNear(3)
		expect(s[2][2]).toBeNear(-3)
		expect(s[1][3]).toBeNear(math.cos(-0.05))
		expect(s[1][4]).toBeNear(math.sin(-0.05))
		expect(s[2][4]).toBeNear(math.sin(0.05))
		expect(s[2][5]).toBe(35)
	end)
	it("rotates the parallel positions and angles with a leftward target", function()
		local s = shots(-20, 0)
		expect(s[1][2]).toBeNear(-3)
		expect(s[2][2]).toBeNear(3)
		expect(s[1][3]).toBeNear(-math.cos(0.05))
		expect(s[1][4]).toBeNear(math.sin(0.05))
	end)
	it("keeps the source asymmetric negative angle for a lone parallel projectile", function()
		local s = shots(20, 0, 1)
		expect(s[1][1]).toBeNear(0)
		expect(s[1][2]).toBeNear(0)
		expect(s[1][3]).toBeNear(math.cos(-0.05))
		expect(s[1][4]).toBeNear(math.sin(-0.05))
	end)
end)
