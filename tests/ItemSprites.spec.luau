--!strict
-- Original sprite coverage, inventory binding and deployed structure pooling without other client controllers.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Feed = require(Shared.Net.StructureFeed)
local Client = folderProxy("src/client", "Client")
local Images = require(Client.UI.ItemImages)
local Icons = require(Client.UI.Icons)
local Renderer = require(Client.Controllers.StructureRenderer)
local player = world.addPlayer("Owner", 1, true)
Net.initServer()
Renderer.init()

describe("Original item sprites", function()
	it("has exactly one uploaded sprite for every catalog entry", function()
		local count = 0
		for id, uri in Images do
			assert(Config.Items.byId[id], `Orphan sprite {id}`)
			assert(string.match(uri, "^rbxassetid://%d+$"))
			count += 1
		end
		expect(count).toBe(#Config.Items.list)
	end)
	it("binds each inventory illustration to its original uploaded sprite", function()
		local holder = Instance.new("Frame")
		for _, item in Config.Items.list do
			local illustration = Icons.draw(holder, "item", item.id)
			local picture = assert(illustration:FindFirstChild("ItemArt"))
			expect(picture.Image).toBe(Images[item.id])
		end
		holder:Destroy()
	end)
	it("uses original sprites for all nine deployed structures and reuses their pooled anchors", function()
		local rows = {}
		for id in Config.Structures.kinds do
			table.insert(rows, { id = #rows + 1, ownerId = player.UserId, kind = id, x = #rows * 5, z = 0 })
		end
		Net.fireAllClients("Structures", Feed.encodeStructures(rows))
		local folder = assert(workspace:FindFirstChild("LanternfallStructures"))
		local seen = {}
		for _, part in folder:GetChildren() do
			expect(part.Transparency).toBe(1)
			local board = part:FindFirstChild("Structure")
			if board then
				expect(board.Enabled).toBe(true)
				expect(board.Picture.ImageRectSize.X).toBe(96)
				expect(board.Picture.ImageRectSize.Y).toBe(96)
				expect(board.StudsOffset.Y).toBe(Config.Structures.spriteSize / 2)
				seen[board.Picture.Image] = true
			end
		end
		for id in Config.Structures.kinds do
			assert(seen[Images[id]], id)
		end
		Net.fireAllClients("Structures", Feed.encodeStructures({}))
		expect(#folder:GetChildren()).toBe(0)
		Net.fireAllClients("Structures", Feed.encodeStructures(rows))
		expect(#folder:GetChildren()).toBe(#rows)
	end)
	it("keeps a visible stat fallback when Roblox refuses an item image", function()
		local provider = game:GetService("ContentProvider")
		local preload = rawget(provider, "PreloadAsync")
		rawset(provider, "PreloadAsync", function(_, _, callback)
			callback(Images.Bellows, Enum.AssetFetchStatus.Failure)
		end)
		local holder = Instance.new("Frame")
		local illustration = Icons.draw(holder, "item", "Bellows")
		world.step()
		expect(illustration.Fallback.Visible).toBe(true)
		rawset(provider, "PreloadAsync", preload)
		holder:Destroy()
	end)
	it("has no isolated item-renderer runtime errors", function()
		expect(#world.errors).toBe(0)
	end)
end)
