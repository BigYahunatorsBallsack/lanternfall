--!strict
-- Native slash animation interpolates its real rectangle and restricts contact to 0.48 <= age < 0.6 seconds.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local G = require(Shared.Util.NativeSlashGeometry)
local C = require(Shared.Config.NightmareEnemies).slash
local shot = { x = 0, z = 0, dx = 1, dz = 0, speed = 0 }
describe("Native slash geometry", function()
	it("uses exact original keyframes, including the hitbox parent offset", function()
		local x, z, hx, hz = G.rectangle(shot, 0.48, 1)
		expect(x).toBe(-122)
		expect(z).toBe(3)
		expect(hx).toBe(30)
		expect(hz).toBe(17)
		local mx, mz, mhx, mhz = G.rectangle(shot, 0.525, 1)
		expect(mx).toBeNear(-38.75)
		expect(mz).toBeNear(3)
		expect(mhx).toBeNear(107.75)
		expect(mhz).toBeNear(14.5)
	end)
	it(
		"rotates/translates the rectangle with projectile movement and uses a true rounded circle/rectangle contact",
		function()
			local moving = { x = 10, z = 20, dx = 0, dz = 1, speed = 300 }
			local x, z, hx, hz = G.rectangle(moving, 0.48, 1)
			expect(x).toBe(7)
			expect(z).toBeNear(42)
			expect(G.contains(moving, 0.48, x, z, 0, 1)).toBe(true)
			expect(G.contains(moving, 0.48, x + hz + 1, z + hx + 1, 1, 1)).toBe(false)
		end
	)
	it("never activates early or after the disable method", function()
		expect(G.active(0.479)).toBe(false)
		expect(G.active(0.48)).toBe(true)
		expect(G.active(0.5999)).toBe(true)
		expect(G.active(0.6)).toBe(false)
		expect(C.stopAt).toBe(0.63)
	end)
	it("uses square target spawns and aims back to target; dormant 90/180 angle data does not constrain it", function()
		local draws = { 0, 1, 0.25, 0.75 }
		local index = 0
		local shots = G.volley(10, 20, 100, 300, 2, 1, function()
			index += 1
			return draws[index]
		end)
		expect(shots[1].x).toBe(-40)
		expect(shots[1].z).toBe(70)
		expect(shots[2].x).toBe(-15)
		expect(shots[2].z).toBe(45)
		expect(shots[1].dx).toBeNear(math.sqrt(0.5))
		expect(shots[1].dz).toBeNear(-math.sqrt(0.5))
	end)
end)
