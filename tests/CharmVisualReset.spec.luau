--!strict
-- Charmed outline state must not leak from a pooled friendly sprite into a later hostile actor.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Models = require(folderProxy("src/client", "Client").Controllers.EnemyRenderer.SpriteModels)
describe("Charmed visual reuse", function()
	it("restores the ordinary outline and status when the pooled model resets", function()
		local visual = Models.build(Config.Enemies.types.Shadeling.typeId)
		Models.setStatus(visual, false, false, false, true)
		expect(visual.charmed).toBe(true)
		local blue = Color3.fromRGB(table.unpack(require(Shared.Config.Charm).color))
		for _, label in visual.sprite.outline do
			for _, channel in { "R", "G", "B" } do
				expect(label.ImageColor3[channel]).toBe(blue[channel])
			end
		end
		Models.reset(visual)
		expect(visual.charmed).toBe(false)
		local normal = Color3.fromRGB(table.unpack(Config.Sprites.outline.color))
		for _, label in visual.sprite.outline do
			for _, channel in { "R", "G", "B" } do
				expect(label.ImageColor3[channel]).toBe(normal[channel])
			end
		end
	end)
end)
