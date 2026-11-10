--!strict
-- Pooled fire-patch markers grow, expire and clear using the server-provided lifetime.
loadHelper("tests/helpers/RobloxMock.luau")
local Visual = require(folderProxy("src/client", "Client").Controllers.WeaponRenderer.Visuals.FirePuddle)
describe("Fire patch client marker", function()
	it("grows with the source spawn curve and releases its parts after fading", function()
		local folder = Instance.new("Folder")
		local part
		local frame = {
			now = 0.1,
			floorY = 0,
			folder = folder,
			move = function(value)
				part = value
			end,
		}
		Visual.effect({
			kind = "Puddle",
			weapon = "FirePuddle",
			userId = 1,
			at = 0,
			x = 1,
			z = 2,
			radius = 5.6,
			duration = 3,
		})
		Visual.render(frame)
		expect(part ~= nil).toBe(true)
		expect(part.Size.Y).toBeNear(11.2 * 1.0876975)
		frame.now = 3.4
		Visual.render(frame)
		expect(#folder:GetChildren()).toBe(0)
	end)
	it("clears active patches immediately when the renderer stops", function()
		local folder = Instance.new("Folder")
		Visual.effect({ kind = "Puddle", weapon = "FirePuddle", userId = 1, at = 0, radius = 5.6, duration = 3 })
		Visual.render({ now = 0.2, floorY = 0, folder = folder, move = function() end })
		expect(#folder:GetChildren()).toBe(1)
		Visual.clear()
		expect(#folder:GetChildren()).toBe(0)
	end)
end)
