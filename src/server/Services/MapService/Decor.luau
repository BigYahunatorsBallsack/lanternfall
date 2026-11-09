--!strict
-- Soft daylight, scattered pebbles and lobby lamps for the open arena.
-- Arena decoration does not block movement.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BRASS = Color3.fromRGB(181, 140, 72)
local DARK_BRASS = Color3.fromRGB(120, 92, 52)
local DARK_STONE = Color3.fromRGB(52, 48, 60)
local SLAB = Color3.fromRGB(123, 119, 123)
local LAMP_GLOW = Color3.fromRGB(255, 190, 96)

local Decor = {}

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local created = Instance.new("Part")
	created.Name = name
	created.Anchored = true
	created.Size = size
	created.CFrame = cframe
	created.Color = color
	created.Material = material
	created.TopSurface = Enum.SurfaceType.Smooth
	created.BottomSurface = Enum.SurfaceType.Smooth
	created.Parent = parent
	return created
end

-- Pure decoration inside the play area: no collisions, no raycasts, no touches, no shadow.
local function ghost(target: BasePart)
	target.CanCollide = false
	target.CanQuery = false
	target.CanTouch = false
	target.CastShadow = false
end

-- A cylinder standing up (Roblox cylinders lie along X).
local function upright(position: Vector3): CFrame
	return CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
end

function Decor.applyLighting()
	local settings = Config.Map.lighting
	if not settings.enabled then
		return
	end
	Lighting.ClockTime = settings.clockTime
	Lighting.Brightness = settings.brightness
	Lighting.Ambient = rgb(settings.ambient)
	Lighting.OutdoorAmbient = rgb(settings.outdoorAmbient)
	Lighting.GlobalShadows = false
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	-- Effects the place file brings along would blur or tint the flat pictures; ours follow below.
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("PostEffect") then
			effect.Enabled = false
		end
	end

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = settings.atmosphere.density
	atmosphere.Offset = settings.atmosphere.offset
	atmosphere.Color = rgb(settings.atmosphere.color)
	atmosphere.Decay = rgb(settings.atmosphere.decay)
	atmosphere.Glare = settings.atmosphere.glare
	atmosphere.Haze = settings.atmosphere.haze
	atmosphere.Parent = Lighting

	local correction = Lighting:FindFirstChild("LanternfallColor") or Instance.new("ColorCorrectionEffect")
	correction.Name = "LanternfallColor"
	local grade = correction :: ColorCorrectionEffect
	grade.Contrast = settings.colorCorrection.contrast
	grade.Saturation = settings.colorCorrection.saturation
	grade.TintColor = rgb(settings.colorCorrection.tint)
	grade.Enabled = true
	grade.Parent = Lighting

	local bloom = Lighting:FindFirstChild("LanternfallBloom") or Instance.new("BloomEffect")
	bloom.Name = "LanternfallBloom"
	local glow = bloom :: BloomEffect
	glow.Intensity = settings.bloom.intensity
	glow.Size = settings.bloom.size
	glow.Threshold = settings.bloom.threshold
	glow.Enabled = true
	glow.Parent = Lighting
end

-- Pebbles add texture without blocking movement.
local function floorSlabs(model: Model, center: Vector3, random: Random)
	local decor = Config.Map.decor
	local halfX = Config.Map.arena.width / 2 - 6
	local halfZ = Config.Map.arena.depth / 2 - 6
	for index = 1, decor.floorSlabs do
		local x = random:NextNumber(-halfX, halfX)
		local z = random:NextNumber(-halfZ, halfZ)
		local size = Vector3.new(random:NextNumber(0.7, 2.8), 0.06, random:NextNumber(0.5, 2.2))
		local slab = part(
			model,
			`Slab{index}`,
			size,
			CFrame.new(center + Vector3.new(x, 0.04, z)) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0),
			SLAB:Lerp(DARK_STONE, random:NextNumber(0, 0.25)),
			Enum.Material.Slate
		)
		slab.Shape = Enum.PartType.Ball
		ghost(slab)
	end
end

-- A brass post with a caged lantern and a warm light.
local function lampPost(model: Model, name: string, base: Vector3, height: number)
	local post = part(
		model,
		`{name}Post`,
		Vector3.new(height, 0.8, 0.8),
		upright(base + Vector3.new(0, height / 2, 0)),
		DARK_BRASS,
		Enum.Material.Metal
	)
	post.Shape = Enum.PartType.Cylinder
	post.CastShadow = false
	local foot = part(
		model,
		`{name}Foot`,
		Vector3.new(2.4, 1, 2.4),
		CFrame.new(base + Vector3.new(0, 0.5, 0)),
		DARK_STONE,
		Enum.Material.Slate
	)
	foot.CastShadow = false
	local top = base + Vector3.new(0, height + 1.2, 0)
	local core = part(model, `{name}Core`, Vector3.new(1.4, 1.8, 1.4), CFrame.new(top), LAMP_GLOW, Enum.Material.Neon)
	ghost(core)
	local roof = part(
		model,
		`{name}Roof`,
		Vector3.new(2.6, 0.5, 2.6),
		CFrame.new(top + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, math.pi / 4, 0),
		BRASS,
		Enum.Material.Metal
	)
	ghost(roof)
	for side = 0, 3 do
		local angle = side * math.pi / 2 + math.pi / 4
		local bar = part(
			model,
			`{name}Bar{side}`,
			Vector3.new(0.2, 2.2, 0.2),
			CFrame.new(top + Vector3.new(math.cos(angle) * 1, 0, math.sin(angle) * 1)),
			BRASS,
			Enum.Material.Metal
		)
		ghost(bar)
	end
end

-- A dark ground skirt hides everything beyond the wall of an area `width` x `depth` studs.
local function outskirts(parent: Model, center: Vector3, width: number, depth: number, margin: number)
	local settings = Config.Map.decor.outskirts
	local border = 2 * (Config.Map.wallThickness + margin)
	local ground = part(
		parent,
		"Outskirts",
		Vector3.new(width + border, settings.thickness, depth + border),
		CFrame.new(center - Vector3.new(0, settings.drop + settings.thickness / 2, 0)),
		rgb(settings.color),
		Enum.Material.SmoothPlastic
	)
	ghost(ground)
end

-- Only light, walk-through floor detail belongs in the arena.
function Decor.buildArena(arenaModel: Model)
	local center = Config.Map.arena.center
	local random = Random.new(Config.Map.decor.seed)
	local model = Instance.new("Model")
	model.Name = "Decor"
	floorSlabs(model, center, random)
	outskirts(model, center, Config.Map.arena.width, Config.Map.arena.depth, Config.Map.decor.outskirts.margin)
	model.Parent = arenaModel
end

-- Lamp posts on an arc just inside the lobby's edge.
function Decor.buildLobby(lobbyModel: Model)
	local lobby = Config.Map.lobby
	local count = Config.Map.decor.lobbyLamps
	local model = Instance.new("Model")
	model.Name = "Decor"
	local radius = lobby.size / 2 - 4
	-- on the half away from the hub portals (they stand towards -Z)
	local first, last = math.rad(-15), math.rad(195)
	for index = 1, count do
		local angle = if count > 1 then first + (last - first) * (index - 1) / (count - 1) else math.pi / 2
		local base = lobby.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
		lampPost(model, `Lamp{index}`, base, Config.Map.decor.lampHeight * 0.7)
	end
	outskirts(lobbyModel, lobby.center, lobby.size, lobby.size, Config.Map.decor.outskirts.lobbyMargin)
	model.Parent = lobbyModel
end

return Decor
