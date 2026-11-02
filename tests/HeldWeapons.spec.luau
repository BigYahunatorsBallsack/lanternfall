-- Held weapons: every configured weapon has a safe model, duplicates can coexist, and stale models return to pools.

loadHelper("tests/helpers/RobloxMock.luau")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local HeldModels = require(folderProxy("src/client", "Client").Controllers.WeaponRenderer.HeldModels)

local function frame(folder, number)
	return {
		number = number,
		now = number,
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

describe("Held weapon models", function()
	it("covers every weapon with a small, non-colliding model", function()
		local folder = Instance.new("Folder")
		local count = 0
		for id in Config.Weapons do
			count += 1
			expect(HeldModels.has(id)).toBe(true)
			HeldModels.renderWeapon(
				{ userId = 1, position = Vector3.zero },
				{ uid = count, id = id },
				1,
				1,
				frame(folder, count)
			)
			local parts = folder:GetChildren()
			expect(#parts >= 3 and #parts <= 12).toBe(true)
			for _, part in parts do
				expect(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch).toBe(true)
			end
			HeldModels.clear()
			expect(#folder:GetChildren()).toBe(0)
		end
		expect(count).toBe(26)
	end)

	it("keeps duplicate copies separate and releases them when absent", function()
		local folder = Instance.new("Folder")
		local owner = { userId = 7, position = Vector3.zero }
		HeldModels.renderWeapon(owner, { uid = 1, id = "WatchmanPistol" }, 1, 2, frame(folder, 1))
		local one = #folder:GetChildren()
		HeldModels.renderWeapon(owner, { uid = 2, id = "WatchmanPistol" }, 2, 2, frame(folder, 1))
		expect(#folder:GetChildren()).toBe(one * 2)
		HeldModels.finish(frame(folder, 1))
		HeldModels.renderWeapon(owner, { uid = 2, id = "WatchmanPistol" }, 1, 1, frame(folder, 2))
		HeldModels.finish(frame(folder, 2))
		expect(#folder:GetChildren()).toBe(one)
		HeldModels.clear()
		expect(#folder:GetChildren()).toBe(0)
	end)
end)
