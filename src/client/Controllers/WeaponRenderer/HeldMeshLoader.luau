--!strict
-- Loads authored weapon meshes in the background when an equipped weapon first appears. HeldModels keeps its
-- inexpensive primitive silhouette until the textured parts are ready, then pools clones of these prototypes.

local MeshCatalog = require(script.Parent.HeldMeshCatalog)

export type Piece = { part: BasePart, offset: CFrame }

local ready: { [string]: { Piece } } = {}
local loading: { [string]: boolean } = {}
local retryAt: { [string]: number } = {}

local HeldMeshLoader = {}

function HeldMeshLoader.has(id: string): boolean
	return MeshCatalog[id] ~= nil
end

function HeldMeshLoader.prototypes(id: string): { Piece }?
	return ready[id]
end

function HeldMeshLoader.request(id: string)
	local look = MeshCatalog[id]
	if
		not look
		or not Content
		or not Content.fromUri
		or ready[id]
		or loading[id]
		or os.clock() < (retryAt[id] or 0)
	then
		return
	end
	loading[id] = true
	task.spawn(function()
		local pieces: { Piece } = {}
		local ok, err = pcall(function()
			local assetService = game:GetService("AssetService")
			local contentProvider = game:GetService("ContentProvider")
			for _, spec in look.pieces do
				local part = assetService:CreateMeshPartAsync(Content.fromUri(spec.mesh), {
					CollisionFidelity = Enum.CollisionFidelity.Box,
				})
				part.Name = spec.name
				part.Size = spec.size
				part.TextureID = spec.texture
				part.Color = Color3.new(1, 1, 1)
				part.Material = Enum.Material.SmoothPlastic
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				table.insert(pieces, { part = part, offset = look.pose * spec.offset })
			end
			local parts = {}
			for _, piece in pieces do
				table.insert(parts, piece.part)
			end
			local failedAsset: string? = nil
			contentProvider:PreloadAsync(parts, function(contentId, status)
				if status ~= Enum.AssetFetchStatus.Success and not failedAsset then
					failedAsset = tostring(contentId)
				end
			end)
			if failedAsset then
				error(`asset fetch failed: {failedAsset}`)
			end
		end)
		loading[id] = nil
		if ok then
			ready[id] = pieces
		else
			for _, piece in pieces do
				piece.part:Destroy()
			end
			retryAt[id] = os.clock() + 20
			warn(`Held weapon mesh {id} could not load: {err}`)
		end
	end)
end

return HeldMeshLoader
