--!strict
-- Silesaurus source fans aim from each randomized, mirrored transform origin before applying their fan angle.
loadHelper("tests/helpers/RobloxMock.luau")
local Volley = require(game:GetService("ReplicatedStorage").Shared.Util.NativeEnemyVolley)
local function emit(targetX, finalAim)
	local draws, results = { 0, 1, 0.5, 1, 0, 0.5 }, {}
	local cursor = 0
	Volley.emit(
		{
			count = 2,
			spread = 0.1,
			constantSpread = true,
			offsetX = 4.5,
			offsetZ = -10,
			speedStep = 0,
			spawnSquare = 7.5,
			baseAimFromSpawn = true,
			aimFromSpawn = if finalAim then { targetRotation = 0 } else nil,
		},
		0,
		0,
		targetX,
		20,
		65,
		function()
			cursor += 1
			-- A final target rotation consumes one batch draw, even for a zero rotation.
			return draws[if finalAim then math.max(1, cursor - 1) else cursor]
		end,
		function(x, z, dx, dz)
			table.insert(results, { x = x, z = z, angle = math.atan2(dz, dx) })
		end
	)
	return results
end
describe("Native projectile origin aim", function()
	it("adds the constant fan to each square-spawn origin's own target bearing", function()
		local shots = emit(40, false)
		expect(shots[1].x).toBeNear(0.75)
		expect(shots[1].z).toBeNear(-6.25)
		expect(shots[1].angle).toBeNear(math.atan2(26.25, 39.25) - 0.1)
		expect(shots[2].x).toBeNear(8.25)
		expect(shots[2].z).toBeNear(-13.75)
		expect(shots[2].angle).toBeNear(math.atan2(33.75, 31.75) + 0.1)
	end)
	it("mirrors the transform before calculating each projectile bearing", function()
		local shots = emit(-40, false)
		expect(shots[1].x).toBeNear(-8.25)
		expect(shots[1].angle).toBeNear(math.atan2(26.25, -31.75) - 0.1)
	end)
	it("retains the source final-target override after fan calculation", function()
		local shots = emit(40, true)
		for _, shot in shots do
			expect(shot.angle).toBeNear(math.atan2(20 - shot.z, 40 - shot.x))
		end
	end)
end)
