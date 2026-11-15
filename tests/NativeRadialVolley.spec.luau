--!strict
-- Source Dimetrodon ring positions and outward aim override player aim; shared by hostile and Charm volleys.
loadHelper("tests/helpers/RobloxMock.luau")
local Volley = require(game:GetService("ReplicatedStorage").Shared.Util.NativeEnemyVolley)
local function shots(tx, tz)
	local result = {}
	Volley.emit(
		{
			count = 8,
			spread = 0,
			constantSpread = true,
			offsetX = 0,
			offsetZ = 0,
			speedStep = 0,
			spawnRing = { radius = 1.25, away = true },
		},
		12,
		-8,
		tx,
		tz,
		40,
		function()
			return 0.37
		end,
		function(x, z, dx, dz, speed)
			table.insert(result, { x, z, dx, dz, speed })
		end
	)
	return result
end
describe("Native outward ring", function()
	it("spawns on the 12.5px border with eight fixed world directions", function()
		local found = shots(100, 70)
		expect(#found).toBe(8)
		for i, s in found do
			local a = (i - 1) * math.pi / 4
			expect(s[1]).toBeNear(12 + math.cos(a) * 1.25)
			expect(s[2]).toBeNear(-8 + math.sin(a) * 1.25)
			expect(s[3]).toBeNear(math.cos(a))
			expect(s[4]).toBeNear(math.sin(a))
			expect(s[5]).toBe(40)
		end
	end)
	it("does not rotate the ring towards a different target", function()
		local a, b = shots(100, 70), shots(-50, -100)
		for i, s in a do
			for j, v in s do
				expect(b[i][j]).toBeNear(v)
			end
		end
	end)
end)
