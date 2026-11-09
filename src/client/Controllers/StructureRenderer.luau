--!strict
-- B12 cosmetic pooled structures and attack rays. Never decides hits, healing or movement.
-- Since Paket 22 both feeds arrive as compact buffers (Net/StructureFeed); the snapshot only comes when structures
-- appear or vanish, and orbiting companions circle their owner's character every frame with the server's angle
-- (server time * orbitSpeed + id, as in StructureService).
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local RunService = game:GetService("RunService")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local StructureFeed = require(Shared.Net.StructureFeed)
local Kit = require(script.Parent.WeaponRenderer.VisualKit)
local WorldSprite = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("WorldSprite")
)
local Images = require(script.Parent.Parent.UI.ItemImages)
local Renderer = {}
local folder: Folder
local live = {}
local orbits: { [number]: { parts: any, ownerId: number, id: number } } = {}
local flashes = {}
local C = Config.Structures
local FLOOR_Y = Config.Map.arena.center.Y
local Sprites = Config.Sprites
local pool = Kit.objectPool(function()
	local sprite = WorldSprite.create({ name = "Structure", image = "", studs = 4, ground = 0 })
	WorldSprite.outline(sprite)
	return { sprite = sprite, anchor = sprite.anchor :: BasePart, hover = 0 }
end, function(parts)
	return { parts.anchor }
end)
local beamPool = Kit.objectPool(function()
	return { Kit.part("StructureRay", Enum.PartType.Block, Vector3.new(0.12, 0.12, 1), Color3.new(1, 1, 1)) }
end, function(parts)
	return parts
end)

local function place(parts: any, x: number, z: number)
	parts.anchor.CFrame = CFrame.new(x, FLOOR_Y + parts.hover, z)
end

local function ownerRoot(userId: number): Vector3?
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function onStructures(packet: any)
	if typeof(packet) ~= "buffer" then
		return
	end
	local seen = {}
	for _, row in StructureFeed.decodeStructures(packet) do
		local def = C.kinds[row.kind]
		if not def then
			continue
		end
		seen[row.id] = true
		local parts = live[row.id]
		if not parts then
			parts = pool:acquire(folder)
			live[row.id] = parts
			parts.hover = Sprites.structureHover[def.mode] or 0
			local art = Sprites.structures[row.kind]
			local image = Images[row.kind]
			if art then
				WorldSprite.setImage(parts.sprite, {
					name = "Structure",
					image = image or art.image,
					studs = if image then C.spriteSize else art.studs,
					ground = if image then 0 else art.ground,
					center = if image then 0.5 else art.center,
					pixels = if image then 96 else art.pixels,
				})
			end
		end
		place(parts, row.x, row.z)
		orbits[row.id] = if def.mode == "Orbit" then { parts = parts, ownerId = row.ownerId, id = row.id } else nil
	end
	for id, parts in live do
		if not seen[id] then
			pool:release(parts)
			live[id] = nil
			orbits[id] = nil
		end
	end
end

local function onBeams(packet: any)
	if typeof(packet) ~= "buffer" then
		return
	end
	for _, row in StructureFeed.decodeBeams(packet) do
		if #flashes >= C.maxActive * 2 then
			break
		end
		local def = C.kinds[row.kind]
		if not def then
			continue
		end
		local a = Vector3.new(row.x, FLOOR_Y + 1.5, row.z)
		local b = Vector3.new(row.tx, a.Y, row.tz)
		if (b - a).Magnitude <= 0 then
			continue
		end
		local parts = beamPool:acquire(folder)
		parts[1].Size = Vector3.new(0.12, 0.12, (b - a).Magnitude)
		parts[1].CFrame = CFrame.lookAt((a + b) / 2, b)
		parts[1].Color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
		table.insert(flashes, { parts = parts, left = C.beamSeconds })
	end
end

function Renderer.init()
	folder = Instance.new("Folder")
	folder.Name = "LanternfallStructures"
	folder.Parent = workspace
	Net.onClient("Structures", onStructures)
	Net.onClient("StructureBeams", onBeams)
	RunService.RenderStepped:Connect(function(dt)
		for i = #flashes, 1, -1 do
			flashes[i].left -= dt
			if flashes[i].left <= 0 then
				beamPool:release(flashes[i].parts)
				table.remove(flashes, i)
			end
		end
		if next(orbits) then
			local now = workspace:GetServerTimeNow()
			for _, orbit in orbits do
				local root = ownerRoot(orbit.ownerId)
				if root then
					local angle = now * C.orbitSpeed + orbit.id
					place(
						orbit.parts,
						root.X + math.cos(angle) * C.orbitRadius,
						root.Z + math.sin(angle) * C.orbitRadius
					)
				end
			end
		end
	end)
end
return Renderer
