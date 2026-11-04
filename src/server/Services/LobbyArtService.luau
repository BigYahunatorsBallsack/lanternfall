--!strict
-- Builds the visual lobby dressing after MapService creates the playable floor and portal prompts.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlaceService = require(script.Parent.PlaceService)

local art = Config.LobbyArt
local lobby = Config.Map.lobby

local LobbyArtService = {}

local function rgb(channels: { number }): Color3
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

local function ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	ghost(part)
	part.Parent = parent
	return part
end

local function makeMesh(parent: Instance, name: string, data: any, cframe: CFrame, tint: Color3): Part
	local part = makePart(parent, name, data.size, cframe, tint, Enum.Material.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = data.mesh
	mesh.TextureId = data.texture
	mesh.Scale =
		Vector3.new(data.size.X / data.sourceSize.X, data.size.Y / data.sourceSize.Y, data.size.Z / data.sourceSize.Z)
	mesh.VertexColor = Vector3.new(tint.R, tint.G, tint.B)
	mesh.Parent = part
	return part
end

local function addLight(parent: Instance, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	CollectionService:AddTag(light, Config.Graphics.optionalLightTag)
end

local function disc(parent: Instance, name: string, diameter: number, height: number, color: Color3)
	local discPart = makePart(
		parent,
		name,
		Vector3.new(0.08, diameter, diameter),
		CFrame.new(lobby.center + Vector3.new(0, height, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		Enum.Material.Slate
	)
	discPart.Shape = Enum.PartType.Cylinder
end

local function buildSpawn(parent: Model, lobbyModel: Model)
	local colors = art.colors
	local spawn = art.spawn
	local pad = lobbyModel:FindFirstChild("LobbySpawn")
	if pad and pad:IsA("SpawnLocation") then
		pad.Color = rgb(colors.stoneDark)
		pad.Material = Enum.Material.Slate
	end

	disc(parent, "OuterRing", spawn.outerRingDiameter, 0.1, rgb(colors.brassDark))
	disc(parent, "OuterInlay", spawn.outerRingDiameter - 1.2, 0.16, rgb(colors.stone))
	disc(parent, "SquareTop", spawn.innerRingDiameter, 1.05, rgb(colors.brass))
	disc(parent, "CenterStone", spawn.innerRingDiameter - 1.1, 1.11, rgb(colors.stone))
	disc(parent, "SigilRing", spawn.sigilRingDiameter, 1.18, rgb(colors.brassDark))
	disc(parent, "SigilCore", spawn.sigilCoreDiameter, 1.23, rgb(colors.stone))
	for index = 1, spawn.sigilRayCount do
		local angle = 2 * math.pi * (index - 1) / spawn.sigilRayCount
		local x = math.sin(angle) * spawn.sigilRayRadius
		local z = math.cos(angle) * spawn.sigilRayRadius
		makePart(
			parent,
			`SunRay{index}`,
			spawn.sigilRaySize,
			CFrame.new(lobby.center + Vector3.new(x, 1.19, z)) * CFrame.Angles(0, angle, 0),
			rgb(colors.brass),
			Enum.Material.Metal
		)
	end
	makePart(
		parent,
		"LanternMark",
		Vector3.new(1.6, 0.09, 3.2),
		CFrame.new(lobby.center + Vector3.new(0, 1.3, 0)),
		rgb(colors.amber),
		Enum.Material.Neon
	)
	for index = 1, spawn.runeCount do
		local angle = 2 * math.pi * (index - 1) / spawn.runeCount
		local x = math.sin(angle) * spawn.runeRadius
		local z = math.cos(angle) * spawn.runeRadius
		makePart(
			parent,
			`Rune{index}`,
			spawn.runeSize,
			CFrame.new(lobby.center + Vector3.new(x, 0.23, z)) * CFrame.Angles(0, angle, 0),
			rgb(colors.amber),
			Enum.Material.Neon
		)
	end

	local base = lobby.center + spawn.beaconOffset
	local beacon = Instance.new("Model")
	beacon.Name = "VigilBeacon"
	for _, item in art.meshes.beacon do
		makeMesh(beacon, item.name, item, CFrame.new(base + item.offset), Color3.new(1, 1, 1))
	end
	local glow = makePart(
		beacon,
		"AmberCore",
		Vector3.new(1.5, 3.2, 1.5),
		CFrame.new(base + Vector3.new(0, 6.3, 0)),
		rgb(colors.amber),
		Enum.Material.Neon
	)
	glow.Transparency = 0.7
	addLight(glow, rgb(colors.amber), 24, 1.2)
	beacon.Parent = parent
end

local function buildPaths(parent: Model)
	local paths = art.paths
	local start = lobby.center + Vector3.new(0, 0, paths.startZ)
	for _, portal in Config.Places.portals do
		local target = lobby.center + portal.offset + Vector3.new(0, 0, paths.endDistance)
		for index = 1, paths.slabsPerPath do
			local alpha = index / (paths.slabsPerPath + 1)
			local position = start:Lerp(target, alpha) + Vector3.new(0, 0.09, 0)
			local slab = makePart(
				parent,
				`{portal.mode}Path{index}`,
				paths.slabSize,
				CFrame.lookAt(position, Vector3.new(target.X, position.Y, target.Z)),
				if index % 2 == 0 then rgb(art.colors.stoneLight) else rgb(art.colors.stone),
				Enum.Material.Slate
			)
			slab.Transparency = 0.08
		end
	end
end

local function portalColor(mode: string): Color3
	if mode == "Party" then
		return Color3.fromRGB(152, 102, 218)
	elseif mode == "QuickJoin" then
		return Color3.fromRGB(96, 214, 200)
	end
	return rgb(art.colors.amber)
end

local function buildPortals(parent: Model, lobbyModel: Model)
	local settings = art.portals
	for _, portal in Config.Places.portals do
		local base = lobby.center + portal.offset
		local facing = CFrame.lookAt(base, Vector3.new(lobby.center.X, base.Y, lobby.center.Z))
		local color = portalColor(portal.mode)
		local model = Instance.new("Model")
		model.Name = `{portal.mode}GatewayArt`
		local original = lobbyModel:FindFirstChild(`Portal{portal.mode}`)
		if original then
			local gate = original:FindFirstChild("Gate")
			if gate and gate:IsA("BasePart") then
				gate.Size = settings.gateSize
				gate.CFrame = gate.CFrame * CFrame.new(settings.gateInset)
				gate.Transparency = settings.gateTransparency
			end
			for _, child in original:GetChildren() do
				if child:IsA("BasePart") and child ~= gate then
					child.Transparency = 1
					child.CastShadow = false
				end
			end
		end

		makePart(
			model,
			"Landing",
			settings.landingSize,
			facing * CFrame.new(0, settings.landingSize.Y / 2, -settings.landingDepth),
			rgb(art.colors.stoneDark),
			Enum.Material.Slate
		)
		makeMesh(
			model,
			"CarvedArch",
			art.meshes.arch,
			facing * CFrame.new(0, art.meshes.arch.size.Y / 2, 0),
			rgb(art.colors.stoneLight)
		)
		local emblem = makePart(
			model,
			"Emblem",
			settings.emblemSize,
			facing * CFrame.new(0, art.meshes.arch.size.Y - 2.1, -2.1),
			color,
			Enum.Material.Neon
		)
		emblem.Shape = Enum.PartType.Ball
		addLight(emblem, color, settings.glowRange, settings.glowBrightness)
		model.Parent = parent
	end
end

local function buildLamps(parent: Model)
	for index, offset in art.lamps.positions do
		local model = Instance.new("Model")
		model.Name = `StreetLantern{index}`
		local base = lobby.center + offset
		for _, item in art.meshes.lamp do
			local part = makeMesh(model, item.name, item, CFrame.new(base + item.offset), Color3.new(1, 1, 1))
			if item.name == "Cage" then
				addLight(part, rgb(art.colors.amber), art.lamps.range, art.lamps.brightness)
			end
		end
		model.Parent = parent
	end
end

local function hideLegacyLamps(lobbyModel: Model)
	local legacy = lobbyModel:FindFirstChild("Decor")
	if not legacy then
		return
	end
	for _, descendant in legacy:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Light") then
			descendant.Enabled = false
		end
	end
end

local function buildPerimeter(parent: Model)
	local edge = lobby.size / 2 - art.perimeter.margin
	local height = art.perimeter.parapetHeight
	local thickness = art.perimeter.parapetThickness
	for _, side in
		{
			{ "North", Vector3.new(lobby.size, height, thickness), Vector3.new(0, height / 2, -edge) },
			{ "South", Vector3.new(lobby.size, height, thickness), Vector3.new(0, height / 2, edge) },
			{ "West", Vector3.new(thickness, height, lobby.size), Vector3.new(-edge, height / 2, 0) },
			{ "East", Vector3.new(thickness, height, lobby.size), Vector3.new(edge, height / 2, 0) },
		}
	do
		makePart(
			parent,
			`Parapet{side[1]}`,
			side[2],
			CFrame.new(lobby.center + side[3]),
			rgb(art.colors.stoneDark),
			Enum.Material.Slate
		)
	end
	local tower = art.perimeter.cornerTowerSize
	for _, x in { -edge + tower.X / 2, edge - tower.X / 2 } do
		for _, z in { -edge + tower.Z / 2, edge - tower.Z / 2 } do
			local base = lobby.center + Vector3.new(x, tower.Y / 2, z)
			makePart(parent, "CornerRuin", tower, CFrame.new(base), rgb(art.colors.stone), Enum.Material.Slate)
			makePart(
				parent,
				"CornerCap",
				Vector3.new(tower.X + 0.6, 0.5, tower.Z + 0.6),
				CFrame.new(base + Vector3.new(0, tower.Y / 2 + 0.25, 0)),
				rgb(art.colors.brassDark),
				Enum.Material.Metal
			)
		end
	end
end

function LobbyArtService.start()
	local map = workspace:WaitForChild("LanternfallMap", 15)
	if not map then
		warn("[Lanternfall] Lobby art: MapService did not create the map")
		return
	end
	local lobbyModel = map:WaitForChild("Lobby", 5)
	if not lobbyModel or not lobbyModel:IsA("Model") or lobbyModel:FindFirstChild("LobbyArt") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "LobbyArt"
	buildSpawn(model, lobbyModel)
	buildPerimeter(model)
	buildLamps(model)
	if PlaceService.isHub() then
		buildPaths(model)
		buildPortals(model, lobbyModel)
	end
	hideLegacyLamps(lobbyModel)
	model.Parent = lobbyModel
end

return LobbyArtService
