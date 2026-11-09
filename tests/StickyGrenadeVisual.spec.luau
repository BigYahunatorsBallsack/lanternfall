--!strict
-- Fusing markers follow authoritative updates and release pooled parts when their fuse expires or the run clears.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Client = folderProxy("src/client", "Client")
local Visual = require(Client.Controllers.WeaponRenderer.Visuals.StickyGrenade)
local folder = Instance.new("Folder")
local frame = {
	now = 1,
	dt = 0,
	floorY = 0,
	folder = folder,
	move = function(part, cf)
		part.CFrame = cf
	end,
}
describe("Sticky Grenade feedback", function()
	it("updates a single pooled marker and removes it at fuse expiry", function()
		Visual.effect({
			weapon = "StickyGrenade",
			userId = 1,
			kind = "Drop",
			id = 1,
			at = 1,
			x = 3,
			z = 4,
			duration = 0.75,
		})
		Visual.render(frame)
		local first = folder:FindFirstChild("StickyGrenadeFuse")
		expect(first ~= nil).toBe(true)
		Visual.effect({
			weapon = "StickyGrenade",
			userId = 1,
			kind = "Drop",
			id = 1,
			at = 1.1,
			x = 6,
			z = 7,
			duration = 0.65,
		})
		frame.now = 1.1
		Visual.render(frame)
		expect(folder:FindFirstChild("StickyGrenadeFuse")).toBe(first)
		expect(first.CFrame.Position.X).toBe(6)
		frame.now = 1.75
		Visual.render(frame)
		expect(#folder:GetChildren()).toBe(0)
	end)
	it("clears all fusing markers on a run reset", function()
		Visual.effect({
			weapon = "StickyGrenade",
			userId = 1,
			kind = "Drop",
			id = 2,
			at = 2,
			x = 0,
			z = 0,
			duration = 1,
		})
		frame.now = 2
		Visual.render(frame)
		expect(#folder:GetChildren()).toBe(1)
		Visual.clear()
		expect(#folder:GetChildren()).toBe(0)
	end)
end)
