--!strict
-- Cosmetic Dig Site phases from authoritative snapshots; no client input or progress decisions.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config.Digging)
local Map = require(Shared.Config.Map)
local Images: any = require(Shared.Config.SpriteImages)
local Net = require(Shared.Net)
local WorldSprite = require(Shared.Util.WorldSprite)
local Renderer = {}
local folder: Folder
local live: { [number]: any } = {}
local pool: { any } = {}
local function release(id: number)
	local sprite = live[id]
	if sprite then
		sprite.anchor.Parent = nil
		table.insert(pool, sprite)
		live[id] = nil
	end
end
local function receive(rows: { any })
	local seen = {}
	for index, row in rows do
		if index > C.maxSites then
			break
		end
		seen[row.id] = true
		local phase = if row.dug then C.frames - 1 else math.floor(math.clamp(row.progress, 0, 1) * (C.frames - 1))
		local art = Images.digging and Images.digging[`DigSite{phase}`]
		if not art then
			release(row.id)
			continue
		end -- real original uploads are required; never fabricate an asset id
		local spec =
			{ name = "DigSite", image = art.image, studs = C.visualSize, ground = 0.5, center = 0.5, depth = C.depth }
		local sprite = live[row.id]
		if not sprite then
			sprite = if #pool > 0 then table.remove(pool) else WorldSprite.create(spec)
			live[row.id] = sprite
		end
		WorldSprite.setImage(sprite, spec)
		sprite.anchor.CFrame = CFrame.new(row.x, Map.arena.center.Y, row.z)
		sprite.anchor.Parent = folder
	end
	for id in live do
		if not seen[id] then
			release(id)
		end
	end
end
function Renderer.init()
	folder = Instance.new("Folder")
	folder.Name = "LanternfallDigSites"
	folder.Parent = workspace
	Net.onClient("DigSites", receive)
end
return Renderer
