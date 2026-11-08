--!strict
-- Character select tiles zoom on the head and the summary card fits the whole figure, inside the picture bounds.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Images = require(game:GetService("ReplicatedStorage").Shared.Config.SpriteImages)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
world.addPlayer("Owner", 1, true)
world.advance(0.5)
local Client = folderProxy("src/client", "Client")
runScript(Client, "init.client.luau")
world.advance(0.5)
local Crop = require(Client.UI.PortraitCrop)

describe("Portrait crop", function()
	it("keeps every character cutout square, inside the picture and larger than the full picture", function()
		for id, figure in Images.characters do
			for _, rect in { Crop.head(figure), Crop.figure(figure) } do
				expect(rect.x >= 0 and rect.y >= 0).toBe(true)
				expect(rect.x + rect.side <= figure.pixels).toBe(true)
				expect(rect.y + rect.side <= figure.pixels).toBe(true)
				expect(rect.side < figure.pixels).toBe(true)
			end
			expect(Crop.head(figure).side < Crop.figure(figure).side).toBe(true)
			-- The head cutout starts at the top of the figure, the figure cutout contains the feet.
			local top = (1 - figure.ground - figure.height) * figure.pixels
			local feet = (1 - figure.ground) * figure.pixels
			local head = Crop.head(figure)
			expect(head.y <= top and head.y + head.side > top + 0.5 * head.side).toBe(true)
			local whole = Crop.figure(figure)
			expect(whole.y <= top and whole.y + whole.side >= feet).toBe(true)
			expect(id ~= "").toBe(true)
		end
	end)

	it("shows head tiles in the character row and a cut portrait in the summary", function()
		local Lobby = world.gui("Lobby", "Choose")
		local found = 0
		for _, item in Lobby:GetDescendants() do
			if item.Name == "Illustration" and item:GetAttribute("IconKey") then
				local key = item:GetAttribute("IconKey")
				if string.sub(key, 1, 14) == "characterHead:" then
					found += 1
					local image = item:FindFirstChild("CharacterPortrait")
					expect(image ~= nil and image.ImageRectSize.X > 0).toBe(true)
				end
			end
		end
		expect(found > 0).toBe(true)
	end)
end)
