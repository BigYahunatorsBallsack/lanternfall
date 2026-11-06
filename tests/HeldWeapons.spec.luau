--!strict
-- Approved world sprites, attack copies, and shared shot origins.

loadHelper("tests/helpers/RobloxMock.luau")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Pose = require(Shared.Util.WeaponPose)
local WeaponFx = require(Shared.Net.WeaponFx)
local renderer = folderProxy("src/client", "Client").Controllers.WeaponRenderer
local HeldModels = require(renderer.HeldModels)
local SpriteKit = require(renderer.SpriteKit)
local Images = require(folderProxy("src/client", "Client").UI.WeaponImages)

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

describe("World weapon sprites", function()
	it("uses the approved image for all 62 configured weapons", function()
		local count = 0
		for id in Config.Weapons do
			count += 1
			expect(HeldModels.has(id)).toBe(true)
			if id ~= "OrbitBlades" then
				expect(Config.WeaponVisuals.spriteStuds[id] ~= nil).toBe(true)
			end
			local sprite = SpriteKit.create(id, 3, "TestWeapon")
			expect(sprite.picture.Image).toBe(Images[id])
			expect(sprite.anchor.CanCollide).toBe(false)
			expect(sprite.anchor.CanQuery).toBe(false)
			sprite.anchor:Destroy()
		end
		expect(count).toBe(62)
		expect(Config.WeaponVisuals.spriteStuds.BrassKnuckles < Config.WeaponVisuals.spriteStuds.LamplighterPike).toBe(
			true
		)
	end)

	it("keeps duplicate copies separate and animates only the attacking uid", function()
		local folder = Instance.new("Folder")
		local owner = { userId = 7, position = Vector3.new(0, 100, 0) }
		local one = { uid = 1, id = "RitualDirk" }
		local two = { uid = 2, id = "RitualDirk" }
		HeldModels.renderWeapon(owner, one, 1, 2, frame(folder, 1, 1))
		HeldModels.renderWeapon(owner, two, 2, 2, frame(folder, 1, 1))
		local parts = folder:GetChildren()
		expect(#parts).toBe(2)
		local first, second = parts[1], parts[2]
		local firstX, secondX = first.CFrame.Position.X, second.CFrame.Position.X
		HeldModels.effect({
			weapon = "RitualDirk",
			userId = 7,
			uid = 1,
			kind = "Strike",
			at = 1,
			duration = 0.2,
			dx = 1,
			dz = 0,
			targetDistance = 9,
		})
		HeldModels.renderWeapon(owner, one, 1, 2, frame(folder, 2, workspace:GetServerTimeNow() + 0.1))
		HeldModels.renderWeapon(owner, two, 2, 2, frame(folder, 2, workspace:GetServerTimeNow() + 0.1))
		expect(first.CFrame.Position.X > firstX).toBe(true)
		expect(second.CFrame.Position.X).toBe(secondX)
		HeldModels.finish(frame(folder, 2, workspace:GetServerTimeNow() + 0.1))
		HeldModels.renderWeapon(owner, two, 1, 1, frame(folder, 3, 1.3))
		HeldModels.finish(frame(folder, 3, 1.3))
		expect(#folder:GetChildren()).toBe(1)
		HeldModels.clear()
		expect(#folder:GetChildren()).toBe(0)
	end)

	it("shows a single held Circular Saw and keeps Crossbow visible after firing", function()
		local folder = Instance.new("Folder")
		local owner = { userId = 8, position = Vector3.new(0, 100, 0) }
		HeldModels.renderWeapon(
			owner,
			{ uid = 3, id = "OrbitBlades" },
			1,
			2,
			frame(folder, 1, workspace:GetServerTimeNow())
		)
		HeldModels.effect({
			weapon = "BoomerangAxe",
			userId = 8,
			uid = 4,
			kind = "Fire",
			at = workspace:GetServerTimeNow(),
			dx = 1,
			dz = 0,
		})
		HeldModels.renderWeapon(
			owner,
			{ uid = 4, id = "BoomerangAxe" },
			2,
			2,
			frame(folder, 1, workspace:GetServerTimeNow())
		)
		expect(#folder:GetChildren()).toBe(2)
		for _, anchor in folder:GetChildren() do
			expect(anchor.WeaponArtwork.Sprite.Visible).toBe(true)
		end
		HeldModels.clear()
	end)

	it("sends the precise copy id and starts shots beyond the held weapon", function()
		local x, z = Pose.anchor(10, 20, 4, "WatchmanPistol")
		local mx, mz = Pose.muzzle(10, 20, 4, "WatchmanPistol", 1, 0)
		expect(mx > x).toBe(true)
		expect(mz).toBe(z)
		local effects = WeaponFx.decode(WeaponFx.encode({
			{ weapon = "RitualDirk", userId = 7, uid = 4, kind = "Strike", at = 1, targetDistance = 9 },
		}))
		expect(effects[1].uid).toBe(4)
		expect(effects[1].targetDistance).toBe(9)
	end)
end)
