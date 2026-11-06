--!strict
-- Character selection and respawn integration of the 2D character sprites, using the real service.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Look = Config.Sprites.character

local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local Services = Server.Services
local Run = require(Services.RunDirector)
local Data = require(Services.PlayerDataService)
local Appearance = require(Services.CharacterAppearanceService)
local client = folderProxy("src/client", "Client")
local Portraits = require(client.UI.CharacterPortraits)
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

local function classOf(character: any): any
	return character:GetAttribute("LanternfallClassId")
end

describe("Character sprites", function()
	it("has an approved sprite and measured bounds for every playable class", function()
		local count = 0
		for id, class in Config.Classes do
			if class.available then
				assert((Portraits :: any)[id], id)
				local bounds = Look.classes[id]
				assert(bounds, id)
				assert(bounds.height > 0 and bounds.ground >= 0 and bounds.center > 0, id)
				count += 1
			end
		end
		expect(count).toBe(10)
	end)
	it("publishes the default class without replacing the gameplay character", function()
		local original = player.Character
		expect(classOf(original)).toBe("NightWatch")
		expect(player.Character).toBe(original)
	end)
	it("uses the validated server selection for all ten classes", function()
		local original = player.Character
		for id in Look.classes do
			assert(Run.selectClass(player, id))
			world.advance(0.1)
			expect(classOf(original)).toBe(id)
		end
		expect(player.Character).toBe(original)
		local before = classOf(original)
		local ok = Run.selectClass(player, "ForgedClass")
		expect(ok).toBe(false)
		expect(classOf(original)).toBe(before)
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
		expect(classOf(player.Character)).toBe("NightWatch")
	end)
end)

describe("Character sprite visibility", function()
	local Visibility = require(client.CharacterArt.Visibility)
	local function headOf()
		local head = player.Character:FindFirstChild("Head")
		if not head then
			head = Instance.new("Part")
			head.Name = "Head"
			head.Parent = player.Character
		end
		return head
	end
	it("keeps the native avatar until the sprite image loads", function()
		local head = headOf()
		world.assetFetchStatus = Enum.AssetFetchStatus.Failure
		Visibility.update()
		world.advance(0.1)
		expect(Visibility.get(player).ready).toBe(false)
		expect(head.LocalTransparencyModifier).toBe(0)
		expect(Visibility.get(player).sprite.gui.Enabled).toBe(false)
		world.assetFetchStatus = nil
		world.advance(Look.retrySeconds + 0.1)
		Visibility.update()
		world.advance(0.1)
		expect(Visibility.get(player).ready).toBe(true)
		expect(head.LocalTransparencyModifier).toBe(1)
		expect(Visibility.get(player).sprite.gui.Enabled).toBe(true)
	end)
	it("stands on the floor and shows the class's sprite", function()
		local entry = Visibility.get(player)
		local gui = entry.sprite.gui
		expect(entry.sprite.picture.Image).toBe((Portraits :: any).NightWatch)
		expect(gui.AlwaysOnTop).toBe(false)
		-- the root part hangs HipHeight + half its size above the floor
		assert(math.abs(gui.StudsOffsetWorldSpace.Y + 3) < 0.001)
	end)
	it("swaps the picture on a class change and never adds a second figure", function()
		local entry = Visibility.get(player)
		local sprite = entry.sprite
		assert(Run.selectClass(player, "SparkMage"))
		world.advance(0.1)
		Visibility.update()
		world.advance(0.1)
		expect(Visibility.get(player).sprite).toBe(sprite)
		expect(sprite.picture.Image).toBe((Portraits :: any).SparkMage)
	end)
	it("removes the sprite and shows the avatar again when the player's character goes", function()
		local head = headOf()
		local gui = Visibility.get(player).sprite.gui
		Visibility.forget(player)
		expect(Visibility.get(player)).toBe(nil)
		expect(head.LocalTransparencyModifier).toBe(0)
		expect(gui.Parent).toBe(nil)
	end)
end)
