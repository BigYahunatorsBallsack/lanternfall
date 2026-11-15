--!strict
-- Source count-dependent projectile size travels with each emitted volley member.
loadHelper("tests/helpers/RobloxMock.luau")
local Volley = require(game:GetService("ReplicatedStorage").Shared.Util.NativeEnemyVolley)
local function scales(count, minimum, on)
	local out = {}
	Volley.emit(
		{
			count = count,
			spread = 0,
			constantSpread = true,
			offsetX = 0,
			offsetZ = 0,
			speedStep = 0,
			scaleWithCount = on,
			minimumScale = minimum,
		},
		0,
		0,
		10,
		0,
		30,
		function()
			return 0.5
		end,
		function(_, _, _, _, _, scale)
			table.insert(out, scale)
		end
	)
	return out
end
describe("Native volley projectile scale", function()
	it("keeps the middle of a three-shot fan full size and shrinks both ends", function()
		local out = scales(3, 0.7, true)
		expect(#out).toBe(3)
		expect(out[1]).toBeNear(0.7)
		expect(out[2]).toBeNear(1)
		expect(out[3]).toBeNear(0.7)
	end)
	it("interpolates even fans symmetrically", function()
		local out = scales(4, 0.55, true)
		expect(out[1]).toBeNear(0.55)
		expect(out[2]).toBeNear(0.85)
		expect(out[3]).toBeNear(0.85)
		expect(out[4]).toBeNear(0.55)
	end)
	it("does not scale disabled rules or a single fresh projectile below one", function()
		expect(scales(1, 0.7, true)[1]).toBe(1)
		expect(scales(3, 0.7, false)[1]).toBe(1)
		expect(scales(1, 1.2, true)[1]).toBeNear(1.2)
		expect(scales(3, 1.2, true)[2]).toBeNear(1.2)
		expect(#scales(0, 0.7, true)).toBe(0)
	end)
end)
