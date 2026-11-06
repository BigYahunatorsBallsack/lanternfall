--!strict
-- Exercises primary-stat and level-up artwork through the existing Icons callers, including cache and reroll.
local world = loadHelper("tests/helpers/RobloxMock.luau")
world.addPlayer("Owner", 1, true)
local Client = folderProxy("src/client", "Client")
local Icons = require(Client.UI.Icons)
local Art = require(Client.UI.PrimaryStatArt)
local Images = require(Client.UI.StatImages)
local Stats = require(game:GetService("ReplicatedStorage").Shared.Config.Stats)

local function holder(screenName)
	local screen = Instance.new("ScreenGui")
	screen.Name = screenName
	local container = Instance.new("Frame")
	container.Parent = screen
	local icon = Instance.new("Frame")
	icon.Parent = container
	return icon
end

describe("Original primary-stat artwork", function()
	it("has distinct uploaded stat and upgrade images for every primary upgrade", function()
		local count = 0
		for _, stat in Stats.order do
			if stat.upgrade then
				count += 1
				assert(Art.stats[stat.id]:match("^rbxassetid://[1-9]%d+$"))
				assert(Art.upgrades[stat.id]:match("^rbxassetid://[1-9]%d+$"))
				expect(Art.stats[stat.id] == Art.upgrades[stat.id]).toBe(false)
				expect(Images[stat.id]).toBe(Art.stats[stat.id])
			end
		end
		expect(count).toBe(16)
	end)

	it("uses the card illustrations on the LevelUp screen and symbols on the Stats screen", function()
		local cardHolder = holder("LevelUp")
		local statHolder = holder("Stats")
		for id, image in Art.upgrades do
			local card = Icons.draw(cardHolder, "stat", id)
			local row = Icons.draw(statHolder, "stat", id)
			expect(card.StatArt.Image).toBe(image)
			expect(row.StatArt.Image).toBe(Art.stats[id])
			expect(card.Fallback.Visible).toBe(false)
			expect(row.Fallback.Visible).toBe(false)
		end
	end)

	it("keeps the illustration when the same card rerenders and replaces it after a reroll", function()
		local icon = holder("LevelUp")
		local first = Icons.draw(icon, "stat", "maxHp")
		expect(Icons.draw(icon, "stat", "maxHp")).toBe(first)
		local rerolled = Icons.draw(icon, "stat", "hpRegen")
		expect(first.Parent).toBe(nil)
		expect(rerolled.StatArt.Image).toBe(Art.upgrades.hpRegen)
		expect(#icon:GetChildren()).toBe(1)
	end)

	it("preserves all secondary images without inventing secondary upgrade illustrations", function()
		local icon = holder("Stats")
		for _, stat in Stats.order do
			assert(Images[stat.id] ~= nil)
			if not stat.upgrade then
				expect(Art.upgrades[stat.id]).toBe(nil)
				local row = Icons.draw(icon, "stat", stat.id)
				expect(row.StatArt.Image).toBe(Images[stat.id])
			end
		end
	end)

	it("updates the cached image when a holder moves between the two screens", function()
		local icon = holder("LevelUp")
		local original = Icons.draw(icon, "stat", "maxHp")
		local statsScreen = Instance.new("ScreenGui")
		statsScreen.Name = "Stats"
		icon.Parent = statsScreen
		local moved = Icons.draw(icon, "stat", "maxHp")
		expect(original.Parent).toBe(nil)
		expect(moved.StatArt.Image).toBe(Art.stats.maxHp)
	end)

	it("keeps the existing crate item art on the same LevelUp screen", function()
		local itemImages = require(Client.UI.ItemImages)
		local itemId, image = next(itemImages)
		assert(itemId and image)
		local icon = holder("LevelUp")
		local item = Icons.draw(icon, "item", itemId)
		expect(item.ItemArt.Image).toBe(image)
	end)
end)
