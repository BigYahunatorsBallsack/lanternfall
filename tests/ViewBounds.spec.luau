-- Paket 22: the view of the fixed camera (Util/ViewBounds) on the floor: what is on the screen, what is just off it,
-- and that a margin keeps big models visible until they are fully gone.

local Shared = game:GetService("ReplicatedStorage").Shared
local ViewBounds = require(Shared.Util.ViewBounds)

local PITCH, DISTANCE, FOV, ASPECT = 50, 100, 40, 16 / 9

local function view(): any
	local bounds = ViewBounds.new()
	ViewBounds.update(bounds, 0, 0, 0, PITCH, DISTANCE, FOV, ASPECT)
	return bounds
end

describe("ViewBounds", function()
	it("counts everything as visible before the first update", function()
		expect(ViewBounds.contains(ViewBounds.new(), 5000, 0, 5000, 0)).toBe(true)
	end)

	it("sees the floor around the focus and nothing far away", function()
		local bounds = view()
		expect(ViewBounds.contains(bounds, 0, 0, 0, 0)).toBe(true)
		-- at the focus the half width is distance * tan(fov / 2) * aspect = about 64.7 studs
		expect(ViewBounds.contains(bounds, 60, 0, 0, 0)).toBe(true)
		expect(ViewBounds.contains(bounds, -60, 0, 0, 0)).toBe(true)
		expect(ViewBounds.contains(bounds, 70, 0, 0, 0)).toBe(false)
		-- the camera sits south (+Z): the near edge of the floor is about 36 studs south, the far edge 68 north
		expect(ViewBounds.contains(bounds, 0, 0, 33, 0)).toBe(true)
		expect(ViewBounds.contains(bounds, 0, 0, 40, 0)).toBe(false)
		expect(ViewBounds.contains(bounds, 0, 0, -64, 0)).toBe(true)
		expect(ViewBounds.contains(bounds, 0, 0, -72, 0)).toBe(false)
		-- the far edge is wider than the near edge
		expect(ViewBounds.contains(bounds, 85, 0, -60, 0)).toBe(true)
		expect(ViewBounds.contains(bounds, 85, 0, 30, 0)).toBe(false)
		expect(ViewBounds.contains(bounds, 0, 0, 500, 0)).toBe(false) -- behind the camera
	end)

	it("keeps a point visible while its margin still reaches into the view", function()
		local bounds = view()
		expect(ViewBounds.contains(bounds, 70, 0, 0, 0)).toBe(false)
		expect(ViewBounds.contains(bounds, 70, 0, 0, 8)).toBe(true)
		expect(ViewBounds.contains(bounds, 0, 0, 40, 6)).toBe(true)
	end)

	it("follows the focus", function()
		local bounds = ViewBounds.new()
		ViewBounds.update(bounds, 100, 0, -50, PITCH, DISTANCE, FOV, ASPECT)
		expect(ViewBounds.contains(bounds, 100, 0, -50, 0)).toBe(true)
		expect(ViewBounds.contains(bounds, 0, 0, 0, 0)).toBe(false)
		expect(ViewBounds.contains(bounds, 150, 0, -50, 0)).toBe(true)
	end)

	it("is narrower on a portrait screen", function()
		local bounds = ViewBounds.new()
		ViewBounds.update(bounds, 0, 0, 0, PITCH, DISTANCE, FOV, 0.6)
		expect(ViewBounds.contains(bounds, 20, 0, 0, 0)).toBe(true)
		expect(ViewBounds.contains(bounds, 30, 0, 0, 0)).toBe(false)
	end)
end)
