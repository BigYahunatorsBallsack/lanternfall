--!strict
-- Source specific-degree volleys stay world-aligned for hostile and charmed callers, independently of target direction.
loadHelper("tests/helpers/RobloxMock.luau")
local Volley = require(game:GetService("ReplicatedStorage").Shared.Util.NativeEnemyVolley)
describe("Native fixed-angle volleys", function()
	for _, target in { { 80, 30 }, { -80, -30 } } do
		it("preserves four world angles with target x " .. target[1], function()
			local shots = {}
			Volley.emit(
				{
					count = 4,
					spread = 0,
					constantSpread = false,
					offsetX = 0,
					offsetZ = -7,
					speedStep = 0,
					specificDegrees = { 0, 90, 180, 270 },
				},
				2,
				3,
				target[1],
				target[2],
				50,
				function()
					return 0.5
				end,
				function(x, z, dx, dz, speed)
					table.insert(shots, { x, z, dx, dz, speed })
				end
			)
			expect(#shots).toBe(4)
			for index, angle in { 0, math.pi / 2, math.pi, math.pi * 1.5 } do
				expect(shots[index][1]).toBe(2)
				expect(shots[index][2]).toBe(-4)
				expect(shots[index][3]).toBeNear(math.cos(angle))
				expect(shots[index][4]).toBeNear(math.sin(angle))
				expect(shots[index][5]).toBe(50)
			end
		end)
	end

	it("lets the source constant fan override specific degrees again", function()
		local shots = {}
		Volley.emit(
			{
				count = 2,
				spread = 0.2,
				constantSpread = true,
				offsetX = 0,
				offsetZ = 0,
				speedStep = 0,
				specificDegrees = {
					90,
					270,
				},
			},
			0,
			0,
			20,
			0,
			50,
			function()
				return 0.5
			end,
			function(x, z, dx, dz)
				table.insert(shots, { dx, dz })
			end
		)
		expect(shots[1][1]).toBeNear(math.cos(-0.2))
		expect(shots[1][2]).toBeNear(math.sin(-0.2))
		expect(shots[2][2]).toBeNear(math.sin(0.2))
	end)
end)
