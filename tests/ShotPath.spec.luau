--!strict
-- Client shot visuals (WeaponRenderer/B7ProjectileVisual): a shot that starts at the barrel on screen, away from the
-- server's start, still flies on one straight line instead of bending onto the server path.

loadHelper("tests/helpers/RobloxMock.luau")

local renderer = folderProxy("src/client", "Client").Controllers.WeaponRenderer
local HeldModels = require(renderer.HeldModels)
local Pistol = require(renderer.Visuals.WatchmanPistol)

local function frame(folder, number, now)
	return {
		number = number,
		now = now,
		dt = 1 / 60,
		floorY = 100,
		folder = folder,
		move = function(part, cframe)
			part.CFrame = cframe
		end,
		ownerPosition = function()
			return nil
		end,
		evolved = function()
			return false
		end,
	}
end

describe("Shot path", function()
	it("keeps a shot from the visible barrel on a straight line", function()
		workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 200, 0.1), Vector3.new(0, 100, 0))
		local folder = Instance.new("Folder")
		local owner = { userId = 9, position = Vector3.new(0, 100, 0) }
		local now = workspace:GetServerTimeNow()
		-- the held pistol floats left of the figure on screen; the server's shot starts somewhere else
		HeldModels.renderWeapon(owner, { uid = 5, id = "WatchmanPistol" }, 2, 2, frame(folder, 1, now))
		Pistol.effect({
			weapon = "WatchmanPistol",
			userId = 9,
			uid = 5,
			kind = "Fire",
			id = 77,
			at = now,
			x = 3,
			z = 2,
			dx = 0.6,
			dz = 0.8,
			speed = 40,
			range = 30,
		} :: any)
		local points = {}
		for step = 1, 6 do
			Pistol.render(frame(folder, step + 1, now + step * 0.05))
			local parts = folder:GetChildren()
			local bolt = parts[#parts]
			table.insert(points, bolt.CFrame.Position)
		end
		-- every point lies on the line through the first and the last one
		local first, last = points[1], points[#points]
		local ax, az = last.X - first.X, last.Z - first.Z
		local length = math.sqrt(ax * ax + az * az)
		expect(length > 1).toBe(true)
		for _, point in points do
			local cross = (point.X - first.X) * az - (point.Z - first.Z) * ax
			expect(math.abs(cross / length) < 1e-6).toBe(true)
		end
		Pistol.clear()
		HeldModels.clear()
	end)
end)
