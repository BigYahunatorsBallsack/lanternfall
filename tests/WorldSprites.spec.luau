--!strict
-- 2D presentation: the shared sprite placement and enemy sprites with the former model's functions (Paket 25).
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local EnemyKinds = require(Shared.Util.EnemyKinds)
local WorldSprite = require(Shared.Util.WorldSprite)
local client = folderProxy("src/client", "Client")
local SpriteModels = require(client.Controllers.EnemyRenderer.SpriteModels)

local Sprites = Config.Sprites

describe("WorldSprite", function()
	it("never draws over walls and keeps every sprite on one layer", function()
		local sprite = WorldSprite.create({ name = "T", image = "rbxassetid://1", studs = 4, ground = 0.25 })
		expect(sprite.gui.AlwaysOnTop).toBe(false)
		expect(sprite.gui.StudsOffset.Z).toBe(Sprites.depthBias)
		expect((sprite.anchor :: BasePart).CanCollide).toBe(false)
		expect((sprite.anchor :: BasePart).Transparency).toBe(1)
	end)
	it("puts the ground line of the picture on the anchor", function()
		for _, ground in { 0, 0.18, 0.5 } do
			local studs = 6
			local sprite = WorldSprite.create({ name = "T", image = "", studs = studs, ground = ground })
			local side = studs * Sprites.canvasMargin
			-- from the middle of the billboard down to the ground line, along the picture
			local fromTop = sprite.picture.Position.Y.Scale * side
			local belowCenter = fromTop - side / 2
			assert(math.abs(belowCenter - sprite.gui.StudsOffset.Y) < 0.0001)
		end
	end)
	it("mirrors with a negative image rectangle and back", function()
		local sprite = WorldSprite.create({ name = "T", image = "", studs = 4, pixels = 512, center = 0.6 })
		WorldSprite.setFlip(sprite, true)
		expect(sprite.picture.ImageRectSize.X).toBe(-512)
		expect(sprite.picture.ImageRectOffset.X).toBe(512)
		assert(math.abs(sprite.picture.AnchorPoint.X - 0.4) < 0.0001)
		WorldSprite.setFlip(sprite, false)
		expect(sprite.picture.ImageRectSize.X).toBe(512)
		assert(math.abs(sprite.picture.AnchorPoint.X - 0.6) < 0.0001)
	end)
	it("ignores pose changes too small to see", function()
		local sprite = WorldSprite.create({ name = "T", image = "", studs = 4 })
		local before = sprite.picture.Size
		WorldSprite.pose(sprite, 1 + Sprites.poseScaleStep / 2, 1, 0)
		expect(sprite.picture.Size).toBe(before)
		WorldSprite.pose(sprite, 1.1, 0.9, 5)
		assert(sprite.picture.Size ~= before)
		expect(sprite.picture.Rotation).toBe(5)
	end)
end)

describe("Enemy sprites", function()
	local function eachType(callback: (kind: any, typeId: number) -> ())
		for _, list in { Config.Enemies.types, Config.Enemies.bosses or {}, Config.Enemies.champions or {} } do
			for _, kind in list do
				callback(kind, kind.typeId)
			end
		end
	end
	it("has a sprite for every enemy kind", function()
		eachType(function(kind)
			local art = Sprites.enemies[kind.id]
			assert(art, `{kind.id} has no sprite`)
			assert(art.image ~= "", `{kind.id} has no image`)
			assert(art.studs > 0, kind.id)
		end)
	end)
	it("has a sprite for every Gloom Elite", function()
		for id in Config.Enemies.types do
			local art = Sprites.elites[id]
			assert(art and art.image ~= "", `Gloom {id} has no sprite`)
		end
	end)
	it("moves only a few parts per enemy", function()
		eachType(function(_, typeId)
			local visual = SpriteModels.build(typeId)
			local count = SpriteModels.pose(visual, CFrame.new(0, 0, 0), 0.5, 1, 1, 0.3, {}, {}, 0)
			assert(count <= 3, `{visual.model.Name} moves {count} parts`)
		end)
	end)
	it("keeps the Body part other modules look for", function()
		local visual = SpriteModels.build(Config.Enemies.types.Shadeling.typeId)
		expect(visual.model:FindFirstChild("Body", true)).toBe(visual.body)
	end)
	it("shows a charger's warning only during the wind-up and tints it red", function()
		local charger = SpriteModels.build(Config.Enemies.types.Charger.typeId)
		local telegraph = charger.telegraph :: BasePart
		expect(telegraph.Transparency).toBe(1)
		SpriteModels.setMode(charger, SpriteModels.MODE_WINDUP)
		assert(telegraph.Transparency < 1)
		expect(charger.sprite.picture.ImageColor3).toBe(Sprites.enemy.rushTint)
		SpriteModels.setMode(charger, SpriteModels.MODE_RUSH)
		expect(telegraph.Transparency).toBe(1)
		SpriteModels.reset(charger)
		expect(charger.sprite.picture.ImageColor3).toBe(Color3.new(1, 1, 1))
	end)
	it("flashes on hits and returns to its status color", function()
		local visual = SpriteModels.build(Config.Enemies.types.Shadeling.typeId)
		SpriteModels.setFlash(visual, true)
		expect(visual.sprite.gui.Brightness).toBe(Sprites.enemy.flashBrightness)
		SpriteModels.setFlash(visual, false)
		expect(visual.sprite.gui.Brightness).toBe(1)
		SpriteModels.setStatus(visual, true, false, false)
		assert(visual.sprite.picture.ImageColor3 ~= Color3.new(1, 1, 1))
		SpriteModels.reset(visual)
		expect(visual.sprite.picture.ImageColor3).toBe(Color3.new(1, 1, 1))
	end)
	it("gives elites their crown, HP bar, affix name, Armored steel and Summoning wisps", function()
		local elite = SpriteModels.build(Config.Enemies.types.Brute.typeId + Config.Enemies.elite.typeIdOffset)
		assert(elite.crown and elite.hpBar and elite.affixLabel and elite.trail)
		for index, affix in Config.Enemies.elite.affixes do
			SpriteModels.setAffix(elite, index)
			expect((elite.affixLabel :: TextLabel).Visible).toBe(true)
			expect((elite.trail :: Trail).Enabled).toBe(affix.id == "Swift")
			expect(elite.wisps[1].gui.Enabled).toBe(affix.id == "Summoner")
			if affix.id == "Armored" then
				expect(elite.sprite.picture.ImageColor3).toBe(Sprites.enemy.steelTint)
			end
		end
	end)
	it("turns to the side it walks to", function()
		local visual = SpriteModels.build(Config.Enemies.types.Shadeling.typeId)
		local pixels = visual.sprite.pixels
		local base = EnemyKinds.get("Shadeling")
		assert(base)
		SpriteModels.pose(visual, CFrame.lookAt(Vector3.zero, Vector3.new(-1, 0, 0)), 0, 0, 0, 0, {}, {}, 0)
		expect(visual.sprite.flipped).toBe(true)
		SpriteModels.pose(visual, CFrame.lookAt(Vector3.zero, Vector3.new(1, 0, 0)), 0, 0, 0, 0, {}, {}, 0)
		expect(visual.sprite.flipped).toBe(false)
		expect(visual.sprite.pixels).toBe(pixels)
	end)
end)
