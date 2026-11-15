--!strict
-- Slash2 shares native keyframes but its Hitbox parent is165pixels forward; ordinary MadSlasher geometry stays unchanged.
loadHelper("tests/helpers/RobloxMock.luau")
local Geometry = require(game:GetService("ReplicatedStorage").Shared.Util.NativeSlashGeometry)
describe("Native forward slash2 geometry", function()
	for _, row in { { 1, 0, 20.7, 3.3 }, { -1, 0, -16.7, 2.7 }, { 0, 1, 1.7, 21.7 } } do
		it("rotates the original parent offset with direction " .. row[1] .. "/" .. row[2], function()
			local shot = { x = 2, z = 3, dx = row[1], dz = row[2], speed = 30, variant = "Forward" }
			local x, z, hx, hz = Geometry.rectangle(shot, 0.48, 0.1)
			expect(x).toBeNear(row[3])
			expect(z).toBeNear(row[4])
			expect(hx).toBeNear(3)
			expect(hz).toBeNear(1.7)
			expect(Geometry.contains(shot, 0.48, x, z, 0, 0.1)).toBe(true)
			expect(Geometry.contains(shot, 0.479, x, z, 0, 0.1)).toBe(false)
			expect(Geometry.contains(shot, 0.6, x, z, 0, 0.1)).toBe(false)
		end)
	end
end)
