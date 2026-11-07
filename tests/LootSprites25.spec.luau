--!strict
-- Recovered original loot artwork must be bound to world drops, elite chests and currency counters.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Client = folderProxy("src/client", "Client")
local Currency = require(Client.UI.Currency)
local Orbs = require(Client.Controllers.XpOrbRenderer)
world.addPlayer("Owner", 1, true)
world.step()
Net.initServer()
Orbs.init()
local material = "rbxassetid://133949512212095"
local crate = "rbxassetid://71372348521693"

describe("Original loot sprite bindings", function()
	it("uses recovered fruit and crate artwork for both pickup and elite-chest paths", function()
		expect(Config.Sprites.pickups.Fruit.image).toBe("rbxassetid://135441353822607")
		expect(Config.Sprites.pickups.Crate.image).toBe(crate)
		expect(Config.Sprites.pickups.LegendaryCrate.image).toBe("rbxassetid://101920267109905")
		expect(Config.Sprites.chest.art.image).toBe(crate)
	end)
	it("shows the original green material in currency counters", function()
		local holder = Instance.new("Frame")
		local icon = Currency.mount(holder, 32)
		local picture = assert(icon:FindFirstChild("Material"), "Currency still uses the old drawn shard")
		expect(picture.Image).toBe(material)
		holder:Destroy()
	end)
	it("keeps small and accumulated ground materials green and uses the same image as the counter", function()
		Net.fireAllClients("XpOrbs", {
			orbs = { 1, 20, 30, 1, 2, 25, 30, 4, 3, 30, 30, 20 },
			collected = {},
		})
		local folder = assert(workspace:FindFirstChild("LanternfallXpOrbs"))
		expect(#folder:GetChildren()).toBe(3)
		for _, anchor in folder:GetChildren() do
			local picture = anchor.XpOrb.Picture
			expect(picture.Image).toBe(material)
			expect(picture.ImageColor3.R).toBe(1)
			expect(picture.ImageColor3.G).toBe(1)
			expect(picture.ImageColor3.B).toBe(1)
		end
		expect(#world.errors).toBe(0)
	end)
end)
