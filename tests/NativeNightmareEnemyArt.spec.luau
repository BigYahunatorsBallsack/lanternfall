--!strict
-- Code-only Nightmare identities remain visible with declared existing art; no asset ID or native-art readiness is invented.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Kinds = require(Shared.Util.EnemyKinds)
local Models = require(folderProxy("src/client", "Client").Controllers.EnemyRenderer.SpriteModels)
describe("Pending Nightmare enemy art", function()
	it("marks every new original image pending and resolves a visible declared fallback", function()
		for _, id in require(Shared.Config.NightmareEnemies).implemented do
			local kind = Kinds.get(id)
			expect(kind.nativeArtPending).toBe(true)
			expect(Config.Sprites.enemyImages[id]).toBe(nil)
			local art = Models.artOf(kind)
			expect(art.image).toBe(Config.Sprites.enemyImages[kind.look].image)
			expect(art.image ~= "").toBe(true)
			expect(Models.build(kind.typeId).sprite.picture.Image).toBe(art.image)
		end
		expect(#Config.Difficulty.levels).toBe(6)
	end)
end)
