--!strict
-- Character selection, asset races and respawn integration using the real service and trusted asset doubles.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Art = require(Shared.Config.CharacterArt)
local Config = require(Shared.Config)

local function part(parent, name, position, size)
	local p = Instance.new("MeshPart")
	p.Name = name
	p.Position = position
	p.CFrame = CFrame.new(position)
	p.Size = size
	p.TextureID = "rbxassetid://1"
	p.Parent = parent
	return p
end
for classId, id in Art.models do
	local model = Instance.new("Model")
	model.Name = classId
	local root = part(model, "RootPart", Vector3.zero, Vector3.new(2, 2, 1))
	model.PrimaryPart = root
	part(model, "Body_Mesh", Vector3.new(0, 0.66, 0), Vector3.new(3.36, 4, 2.56))
	part(model, "Arm_L_Mesh", Vector3.new(1.7, -0.25, 0), Vector3.new(0.4, 0.6, 0.3))
	part(model, "Arm_R_Mesh", Vector3.new(-1.7, -0.25, 0), Vector3.new(0.4, 0.6, 0.3))
	part(model, "Foot_L_Mesh", Vector3.new(0.64, -1.3, 0), Vector3.new(0.5, 0.58, 0.58))
	part(model, "Foot_R_Mesh", Vector3.new(-0.64, -1.3, 0), Vector3.new(0.5, 0.58, 0.58))
	world.assetTemplates[id] = model
end
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local Services = Server.Services
local Run = require(Services.RunDirector)
local Data = require(Services.PlayerDataService)
local Appearance = require(Services.CharacterAppearanceService)
local Skin = require(Services.CharacterAppearanceService.Skin)
local player = world.addPlayer("Owner", 1, true)
world.advance(0.5)
local function rig()
	local humanoid = player.Character.Humanoid
	humanoid.HipHeight = 2
	player.Character.HumanoidRootPart.Size = Vector3.new(2, 2, 1)
	return humanoid
end
rig()
Appearance.refresh(player)
world.advance(0.5)
Data.unlockAll(player)

describe("Character art integration", function()
	it("has one nonzero model for every playable class", function()
		local count = 0
		for id, class in Config.Classes do
			if class.available then
				assert(Art.models[id] and Art.models[id] > 0 and Art.colorAtlases[id])
				count += 1
			end
		end
		expect(count).toBe(10)
	end)
	it("attaches the default skin without replacing the gameplay character", function()
		local original = player.Character
		local skin = original:FindFirstChild(Art.folderName)
		assert(skin and skin:GetAttribute("ClassId") == "BladeWarden")
		expect(player.Character).toBe(original)
		local root = skin.PrimaryPart
		local weld = root:FindFirstChild("CharacterSkinRoot")
		expect(weld.Part0).toBe(original.HumanoidRootPart)
		expect(root.CanCollide).toBe(false)
	end)
	it("ignores an older asset load finishing after a newer selection", function()
		world.assetLoadDelay = 0.3
		assert(Run.selectClass(player, "SparkMage"))
		assert(Run.selectClass(player, "NightWatch"))
		world.advance(0.7)
		world.assetLoadDelay = nil
		expect(player.Character:FindFirstChild(Art.folderName):GetAttribute("ClassId")).toBe("NightWatch")
	end)
	it("uses the validated server selection for all ten classes", function()
		local original = player.Character
		for id in Art.models do
			assert(Run.selectClass(player, id))
			world.advance(0.1)
			expect(original:FindFirstChild(Art.folderName):GetAttribute("ClassId")).toBe(id)
		end
		expect(player.Character).toBe(original)
		local before = original:FindFirstChild(Art.folderName)
		local ok = Run.selectClass(player, "ForgedClass")
		expect(ok).toBe(false)
		expect(original:FindFirstChild(Art.folderName)).toBe(before)
	end)
	it("aligns the skin feet to the existing R15 floor", function()
		local skin = player.Character:FindFirstChild(Art.folderName)
		local relativeRoot = skin.PrimaryPart.Position.Y - player.Character.HumanoidRootPart.Position.Y
		assert(math.abs(relativeRoot + 1.41) < 0.001)
	end)
	it("reapplies the selected class after respawn", function()
		assert(Run.selectClass(player, "NightWatch"))
		world.advance(0.1)
		local old = player.Character
		world.spawnCharacter(player)
		world.advance(0.1)
		rig()
		Appearance.refresh(player)
		world.advance(0.1)
		assert(player.Character ~= old)
		expect(player.Character:FindFirstChild(Art.folderName):GetAttribute("ClassId")).toBe("NightWatch")
	end)
	it("preserves an existing valid skin when replacement fails", function()
		local skin = player.Character:FindFirstChild(Art.folderName)
		local prepared = Skin.prepare(world.assetTemplates[Art.models.BladeWarden]:Clone(), "BladeWarden")
		local bad = Instance.new("Model")
		local ok = pcall(
			Skin.attach,
			bad,
			player.Character,
			player.Character.HumanoidRootPart,
			player.Character.Humanoid,
			"BladeWarden"
		)
		expect(ok).toBe(false)
		expect(player.Character:FindFirstChild(Art.folderName)).toBe(skin)
		prepared:Destroy()
	end)
end)

describe("Character skin visibility", function()
	local Visibility = require(folderProxy("src/client", "Client").CharacterArt.Visibility)
	it("keeps the native avatar until all skin content loads successfully", function()
		local head = part(player.Character, "Head", Vector3.new(0, 5, 0), Vector3.one)
		head.Transparency = 0.25
		world.assetFetchStatus = Enum.AssetFetchStatus.Failure
		Visibility.update()
		world.advance(0.1)
		expect(Visibility.get(player).ready).toBe(false)
		expect(head.LocalTransparencyModifier).toBe(0)
		expect(player.Character:FindFirstChild(Art.folderName).Body_Mesh.LocalTransparencyModifier).toBe(1)
		world.assetFetchStatus = nil
		world.advance(Art.retrySeconds + 0.1)
		Visibility.update()
		world.advance(0.1)
		expect(Visibility.get(player).ready).toBe(true)
		expect(head.LocalTransparencyModifier).toBe(1)
		expect(head.Transparency).toBe(0.25)
		expect(player.Character:FindFirstChild(Art.folderName).Body_Mesh.LocalTransparencyModifier).toBe(0)
	end)
	it("restores native visibility when the skin is removed", function()
		local head = player.Character.Head
		local skin = player.Character:FindFirstChild(Art.folderName)
		skin:Destroy()
		Visibility.update()
		expect(Visibility.get(player)).toBe(nil)
		expect(head.LocalTransparencyModifier).toBe(0)
	end)
end)
