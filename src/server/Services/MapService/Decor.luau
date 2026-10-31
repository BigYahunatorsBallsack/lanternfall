--!strict
-- Map dressing and mood of "The Ruined City" (Paket 21, DESIGN.md section 14), built once by MapService: dusk lighting
-- with violet haze, brass bands and broken caps on the ruin pillars, a brass sunburst around the start circle,
-- cracked slabs on the floor, lamp posts, broken walls and glowing obelisks beyond the fog wall, embers drifting over
-- the arena and lamps around the lobby. Only looks: everything inside the arena is walk-through and flat, everything
-- solid stands outside the walls. Numbers in Config.Map.lighting and Config.Map.decor.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BRASS = Color3.fromRGB(181, 140, 72)
local DARK_BRASS = Color3.fromRGB(120, 92, 52)
local STONE = Color3.fromRGB(78, 72, 86)
local DARK_STONE = Color3.fromRGB(52, 48, 60)
local SLAB = Color3.fromRGB(72, 68, 80)
local LAMP_GLOW = Color3.fromRGB(255, 190, 96)
local RUNE_GLOW = Color3.fromRGB(150, 96, 230)
local OBELISK_GLOW = Color3.fromRGB(120, 220, 210)
local MOTE_COLOR = Color3.fromRGB(255, 186, 92)
local MOTE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds" -- ships with every Roblox client

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

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Brightness = brightness
	pointLight.Shadows = false
	pointLight.Parent = parent
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
	grade.Parent = Lighting

	local bloom = Lighting:FindFirstChild("LanternfallBloom") or Instance.new("BloomEffect")
	bloom.Name = "LanternfallBloom"
	local glow = bloom :: BloomEffect
	glow.Intensity = settings.bloom.intensity
	glow.Size = settings.bloom.size
	glow.Threshold = settings.bloom.threshold
	glow.Parent = Lighting
end

-- Brass band, broken cap and a glowing rune ring at the foot of every ruin pillar.
local function dressPillars(model: Model, center: Vector3)
	local arena = Config.Map.arena
	local height = arena.obstacleHeight
	for index, obstacle in arena.obstacles do
		local base = center + Vector3.new(obstacle.x, 0, obstacle.z)
		local diameter = obstacle.radius * 2
		local band = part(
			model,
			`Ruin{index}Band`,
			Vector3.new(1.2, diameter + 0.6, diameter + 0.6),
			upright(base + Vector3.new(0, height * 0.35, 0)),
			BRASS,
			Enum.Material.Metal
		)
		band.Shape = Enum.PartType.Cylinder
		ghost(band)
		local cap = part(
			model,
			`Ruin{index}Cap`,
			Vector3.new(diameter + 1.5, 1.4, diameter + 1.5),
			CFrame.new(base + Vector3.new(0, height + 0.5, 0))
				* CFrame.Angles(math.rad(8), math.rad(index * 37), math.rad(-6)),
			DARK_STONE,
			Enum.Material.Slate
		)
		ghost(cap)
		local rune = part(
			model,
			`Ruin{index}Rune`,
			Vector3.new(0.1, diameter + 3, diameter + 3),
			upright(base + Vector3.new(0, 0.06, 0)),
			RUNE_GLOW,
			Enum.Material.Neon
		)
		rune.Shape = Enum.PartType.Cylinder
		rune.Transparency = 0.7
		ghost(rune)
	end
end

-- Brass disc under the start circle with rays like an art deco sunburst.
local function sunburst(model: Model, center: Vector3)
	local decor = Config.Map.decor
	local radius = Config.Map.arena.spawnRadius
	local disc = part(
		model,
		"SunburstDisc",
		Vector3.new(0.08, radius * 2 + 4, radius * 2 + 4),
		upright(center + Vector3.new(0, 0.04, 0)),
		DARK_BRASS,
		Enum.Material.Metal
	)
	disc.Shape = Enum.PartType.Cylinder
	ghost(disc)
	for ray = 1, decor.sunburstRays do
		local angle = 2 * math.pi * ray / decor.sunburstRays
		local length = if ray % 2 == 0 then decor.sunburstLength else decor.sunburstLength * 0.6
		local mid = radius + 2 + length / 2
		local position = center + Vector3.new(math.cos(angle) * mid, 0.07, math.sin(angle) * mid)
		local strip = part(
			model,
			`Ray{ray}`,
			Vector3.new(length, 0.06, if ray % 2 == 0 then 1.2 else 0.7),
			CFrame.new(position) * CFrame.Angles(0, -angle, 0),
			BRASS,
			Enum.Material.Metal
		)
		ghost(strip)
	end
end

local function floorSlabs(model: Model, center: Vector3, random: Random)
	local decor = Config.Map.decor
	local half = Config.Map.arena.size / 2 - 6
	for index = 1, decor.floorSlabs do
		local x = random:NextNumber(-half, half)
		local z = random:NextNumber(-half, half)
		local size = Vector3.new(random:NextNumber(5, 12), 0.08, random:NextNumber(5, 12))
		local slab = part(
			model,
			`Slab{index}`,
			size,
			CFrame.new(center + Vector3.new(x, 0.04, z)) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0),
			SLAB:Lerp(DARK_STONE, random:NextNumber(0, 0.6)),
			Enum.Material.Slate
		)
		ghost(slab)
	end
end

-- A brass post with a caged lantern and a warm light.
local function lampPost(model: Model, name: string, base: Vector3, height: number, range: number)
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
	light(core, LAMP_GLOW, range, 1.5)
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

-- Lamp posts evenly along the outside of each arena wall.
local function borderLamps(model: Model, center: Vector3)
	local decor = Config.Map.decor
	local arena = Config.Map.arena
	local offset = arena.size / 2 + Config.Map.wallThickness + decor.lampDistance
	local count = decor.lampsPerSide
	local index = 0
	for side = 0, 3 do
		local angle = side * math.pi / 2
		local normal = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local along = Vector3.new(-normal.Z, 0, normal.X)
		for slot = 1, count do
			index += 1
			local t = (slot - 0.5) / count - 0.5
			local base = center + normal * offset + along * (t * arena.size)
			lampPost(model, `Lamp{index}`, base, decor.lampHeight, decor.lampLightRange)
		end
	end
end

-- Broken walls and tumbled blocks in a band beyond the fog wall.
local function backdrop(model: Model, center: Vector3, random: Random)
	local decor = Config.Map.decor
	local half = Config.Map.arena.size / 2 + Config.Map.wallThickness
	local near, far = decor.backdropDepth[1], decor.backdropDepth[2]
	for index = 1, decor.backdropRuins do
		local side = index % 4
		local angle = side * math.pi / 2
		local normal = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local along = Vector3.new(-normal.Z, 0, normal.X)
		local depth = random:NextNumber(near, far)
		local position = center + normal * (half + depth) + along * random:NextNumber(-half, half)
		local wall = random:NextNumber() < 0.6
		local size = if wall
			then Vector3.new(random:NextNumber(10, 26), random:NextNumber(8, 24), random:NextNumber(2, 4))
			else Vector3.new(random:NextNumber(4, 9), random:NextNumber(3, 8), random:NextNumber(4, 9))
		local tilt =
			CFrame.Angles(random:NextNumber(-0.12, 0.12), random:NextNumber(0, math.pi), random:NextNumber(-0.12, 0.12))
		local ruin = part(
			model,
			`Backdrop{index}`,
			size,
			CFrame.new(position + Vector3.new(0, size.Y / 2 - 0.5, 0)) * tilt,
			STONE:Lerp(DARK_STONE, random:NextNumber(0, 1)),
			if wall then Enum.Material.Brick else Enum.Material.Slate
		)
		ruin.CastShadow = false
	end
end

-- A tall obelisk with a glowing crack and a sunburst crown at each corner.
local function obelisks(model: Model, center: Vector3)
	if not Config.Map.decor.obelisks then
		return
	end
	local offset = Config.Map.arena.size / 2 + Config.Map.wallThickness + 14
	for corner = 1, 4 do
		local angle = corner * math.pi / 2 + math.pi / 4
		local base = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (offset * math.sqrt(2))
		local body = part(
			model,
			`Obelisk{corner}`,
			Vector3.new(6, 34, 6),
			CFrame.new(base + Vector3.new(0, 17, 0)) * CFrame.Angles(0, angle, 0),
			DARK_STONE,
			Enum.Material.Slate
		)
		body.CastShadow = false
		local crack = part(
			model,
			`Obelisk{corner}Crack`,
			Vector3.new(6.2, 22, 0.6),
			CFrame.new(base + Vector3.new(0, 16, 0)) * CFrame.Angles(0, angle + math.pi / 4, 0),
			OBELISK_GLOW,
			Enum.Material.Neon
		)
		ghost(crack)
		local crown = part(
			model,
			`Obelisk{corner}Crown`,
			Vector3.new(8, 2, 8),
			CFrame.new(base + Vector3.new(0, 35, 0)) * CFrame.Angles(0, angle + math.pi / 4, 0),
			BRASS,
			Enum.Material.Metal
		)
		crown.CastShadow = false
		light(crack, OBELISK_GLOW, 30, 1.2)
	end
end

-- Slow embers drifting up over the whole arena from one emitter.
local function motes(model: Model, center: Vector3)
	local settings = Config.Map.decor.motes
	if settings.rate <= 0 then
		return
	end
	local size = Config.Map.arena.size
	local area = part(
		model,
		"Motes",
		Vector3.new(size, 1, size),
		CFrame.new(center + Vector3.new(0, 2, 0)),
		MOTE_COLOR,
		Enum.Material.SmoothPlastic
	)
	area.Transparency = 1
	ghost(area)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Embers"
	emitter.Texture = MOTE_TEXTURE
	emitter.Color = ColorSequence.new(MOTE_COLOR)
	emitter.LightEmission = 1
	emitter.Rate = settings.rate
	emitter.Lifetime = NumberRange.new(settings.lifetime[1], settings.lifetime[2])
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Acceleration = Vector3.new(0.4, 0.6, 0.2)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Parent = area
end

function Decor.buildArena(arenaModel: Model)
	local center = Config.Map.arena.center
	local random = Random.new(Config.Map.decor.seed)
	local model = Instance.new("Model")
	model.Name = "Decor"
	dressPillars(model, center)
	sunburst(model, center)
	floorSlabs(model, center, random)
	borderLamps(model, center)
	backdrop(model, center, random)
	obelisks(model, center)
	motes(model, center)
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
		lampPost(model, `Lamp{index}`, base, Config.Map.decor.lampHeight * 0.7, Config.Map.decor.lampLightRange * 0.8)
	end
	model.Parent = lobbyModel
end

return Decor
