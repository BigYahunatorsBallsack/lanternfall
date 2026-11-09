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
	it("uses approved images for all 62 public weapons and rejects eighteen pending-art families", function()
		local count, pending = 0, 0
		for id, weapon in Config.Weapons do
			if weapon.available == false then
				pending += 1
				expect(HeldModels.has(id)).toBe(false)
				expect(require(Shared.Util.CharacterRules).weaponAllowed(nil, id)).toBe(false)
				expect(require(Shared.Config.CharacterWeaponData).weapons[id] ~= nil).toBe(true)
				continue
			end
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
		expect(pending).toBe(19)
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

	it("spaces held weapons evenly around the figure whatever their uids", function()
		for count = 1, 6 do
			local seen = {}
			for slot = 1, count do
				local dx, dz = Pose.direction(slot, count)
				expect(math.abs(dx * dx + dz * dz - 1) < 1e-9).toBe(true)
				table.insert(seen, math.atan2(dz, dx) % (2 * math.pi))
			end
			table.sort(seen)
			for k = 1, count do
				local nextAngle = if k == count then seen[1] + 2 * math.pi else seen[k + 1]
				expect(math.abs(nextAngle - seen[k] - 2 * math.pi / count) < 1e-6).toBe(true)
			end
		end
		local rx, rz = Pose.direction(1, 2)
		local lx, lz = Pose.direction(2, 2)
		expect(math.abs(rx - 1) < 1e-9 and math.abs(rz) < 1e-9).toBe(true)
		expect(math.abs(lx + 1) < 1e-9 and math.abs(lz) < 1e-9).toBe(true)
	end)

	it("sends the precise copy id and starts shots beyond the held weapon", function()
		local x, z = Pose.anchor(10, 20, 2, 3, "WatchmanPistol")
		local mx, mz = Pose.muzzle(10, 20, 2, 3, "WatchmanPistol", 1, 0)
		expect(mx > x).toBe(true)
		expect(mz).toBe(z)
		local effects = WeaponFx.decode(WeaponFx.encode({
			{ weapon = "RitualDirk", userId = 7, uid = 4, kind = "Strike", at = 1, targetDistance = 9 },
		}))
		expect(effects[1].uid).toBe(4)
		expect(effects[1].targetDistance).toBe(9)
	end)
	it("aims beyond a fixed minimum range instead of pointing at an ineligible close enemy", function()
		workspace.CurrentCamera.CFrame = CFrame.new(0, 100, 0)
		local enemies = Instance.new("Folder")
		enemies.Name = "LanternfallEnemies"
		enemies.Parent = workspace
		for index, position in { Vector3.new(0, 100, 10), Vector3.new(50, 100, 0) } do
			local model = Instance.new("Model")
			model.Name = "MinimumEnemy" .. index
			model.Parent = enemies
			local body = Instance.new("Part")
			body.Name = "Body"
			body.Position = position
			body.Parent = model
		end
		local folder = Instance.new("Folder")
		HeldModels.renderWeapon(
			{ userId = 99, position = Vector3.new(0, 100, 0) },
			{ uid = 90, id = "WatchmanPistol", stats = { range = 80, minimumRange = 30 } },
			1,
			1,
			frame(folder, 999, workspace:GetServerTimeNow())
		)
		local picture = folder:GetChildren()[1].WeaponArtwork.Sprite
		expect(picture.Rotation).toBeNear(SpriteKit.rotationToward("WatchmanPistol", 1, 0))
		HeldModels.clear()
		enemies:Destroy()
	end)
end)
