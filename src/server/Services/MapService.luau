--!strict
-- Builds the placeholder lobby and arena from Config.Map (the real map follows in WP21) and moves
-- characters between them. Called by RunDirector; EnemySim and SpawnDirector read the arena bounds,
-- obstacles and player positions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Zone = "Lobby" | "Arena"

export type Bounds = {
	center: Vector3, -- center of the floor surface
	halfSize: number,
}

-- An obstacle as enemies see it: a circle on the floor, in world x/z.
export type Circle = { x: number, z: number, radius: number }

local MAP_NAME = "LanternfallMap"
local CHARACTER_WAIT_SECONDS = 10
local DEFAULT_ROOT_HEIGHT = 3 -- studs from the floor to the HumanoidRootPart if no Humanoid is found
local SPAWN_DROP_HEIGHT = 0.5 -- small gap so the character never spawns inside the floor

-- Placeholder look: warm stone for players' areas, violet fog walls around the arena.
local LOBBY_FLOOR_COLOR = Color3.fromRGB(122, 108, 92)
local LOBBY_PAD_COLOR = Color3.fromRGB(255, 196, 87)
local ARENA_FLOOR_COLOR = Color3.fromRGB(58, 54, 66)
local ARENA_WALL_COLOR = Color3.fromRGB(90, 50, 140)
local ARENA_WALL_TRANSPARENCY = 0.4
local ARENA_MARKER_COLOR = Color3.fromRGB(255, 196, 87)
local RUIN_COLOR = Color3.fromRGB(96, 90, 104)

local MapService = {}

local lobbySpawn: SpawnLocation? = nil
local random = Random.new()

local function layoutFor(zone: Zone)
	return if zone == "Arena" then Config.Map.arena else Config.Map.lobby
end

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Floor plus four walls around a square area.
local function buildArea(
	parent: Instance,
	name: string,
	center: Vector3,
	size: number,
	wallHeight: number,
	floorColor: Color3,
	wallColor: Color3,
	wallTransparency: number
): Model
	local model = Instance.new("Model")
	model.Name = name

	local thickness = Config.Map.floorThickness
	local floor = makePart(
		model,
		"Floor",
		Vector3.new(size, thickness, size),
		CFrame.new(center - Vector3.new(0, thickness / 2, 0)),
		floorColor
	)
	floor.Material = Enum.Material.Slate

	local wall = Config.Map.wallThickness
	local offset = size / 2 + wall / 2
	local y = wallHeight / 2
	local sides = {
		{ "WallNorth", Vector3.new(size + 2 * wall, wallHeight, wall), Vector3.new(0, y, -offset) },
		{ "WallSouth", Vector3.new(size + 2 * wall, wallHeight, wall), Vector3.new(0, y, offset) },
		{ "WallWest", Vector3.new(wall, wallHeight, size), Vector3.new(-offset, y, 0) },
		{ "WallEast", Vector3.new(wall, wallHeight, size), Vector3.new(offset, y, 0) },
	}
	for _, side in sides do
		local part = makePart(model, side[1], side[2], CFrame.new(center + side[3]), wallColor)
		part.Transparency = wallTransparency
		part.CastShadow = false
		if wallTransparency < 1 then
			part.Material = Enum.Material.ForceField
		end
	end

	model.Parent = parent
	return model
end

local function buildMap(): Folder
	local folder = Instance.new("Folder")
	folder.Name = MAP_NAME

	local lobby = Config.Map.lobby
	local lobbyModel =
		buildArea(folder, "Lobby", lobby.center, lobby.size, lobby.wallHeight, LOBBY_FLOOR_COLOR, LOBBY_FLOOR_COLOR, 1)

	local pad = Instance.new("SpawnLocation")
	pad.Name = "LobbySpawn"
	pad.Anchored = true
	pad.Size = Vector3.new(lobby.spawnRadius * 2, 1, lobby.spawnRadius * 2)
	pad.CFrame = CFrame.new(lobby.center + Vector3.new(0, 0.5, 0))
	pad.Color = LOBBY_PAD_COLOR
	pad.Material = Enum.Material.SmoothPlastic
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.Neutral = true
	pad.Duration = 0 -- no spawn force field
	pad.Parent = lobbyModel
	local light = Instance.new("PointLight")
	light.Color = LOBBY_PAD_COLOR
	light.Range = lobby.size / 2
	light.Parent = pad
	lobbySpawn = pad

	local arena = Config.Map.arena
	local arenaModel = buildArea(
		folder,
		"Arena",
		arena.center,
		arena.size,
		arena.wallHeight,
		ARENA_FLOOR_COLOR,
		ARENA_WALL_COLOR,
		ARENA_WALL_TRANSPARENCY
	)
	local marker = makePart(
		arenaModel,
		"StartMarker",
		Vector3.new(arena.spawnRadius * 2, 0.2, arena.spawnRadius * 2),
		CFrame.new(arena.center + Vector3.new(0, 0.1, 0)),
		ARENA_MARKER_COLOR
	)
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.6
	marker.CanCollide = false
	marker.CastShadow = false

	-- Round pillars: the same circles EnemySim steers around. A cylinder's axis is X, so stand it up.
	local height = arena.obstacleHeight
	for index, obstacle in arena.obstacles do
		local pillar = makePart(
			arenaModel,
			`Ruin{index}`,
			Vector3.new(height, obstacle.radius * 2, obstacle.radius * 2),
			CFrame.new(arena.center + Vector3.new(obstacle.x, height / 2, obstacle.z))
				* CFrame.Angles(0, 0, math.pi / 2),
			RUIN_COLOR
		)
		pillar.Shape = Enum.PartType.Cylinder
		pillar.Material = Enum.Material.Cobblestone
	end

	folder.Parent = workspace
	return folder
end

local function rootHeight(character: Model, root: BasePart): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return DEFAULT_ROOT_HEIGHT
end

-- Where a character should stand: arena slots on a circle facing the center, lobby at a random spot.
local function spawnPosition(zone: Zone, slot: number, count: number): Vector3
	local layout = layoutFor(zone)
	if zone == "Arena" then
		local angle = 2 * math.pi * (slot - 1) / math.max(count, 1)
		return layout.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * layout.spawnRadius
	end
	local angle = random:NextNumber(0, 2 * math.pi)
	local distance = random:NextNumber(0, layout.spawnRadius)
	return layout.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
end

function MapService.init()
	if workspace:FindFirstChild(MAP_NAME) then
		warn(`[Lanternfall] {MAP_NAME} already exists in Workspace; building a fresh copy next to it`)
	end
	buildMap()

	local function onPlayerAdded(player: Player)
		player.RespawnLocation = lobbySpawn
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function MapService.getArenaBounds(): Bounds
	local arena = Config.Map.arena
	return { center = arena.center, halfSize = arena.size / 2 }
end

-- Arena obstacles as circles in world x/z (EnemySim steers around them, SpawnDirector avoids them).
function MapService.getObstacles(): { Circle }
	local arena = Config.Map.arena
	local circles = {}
	for _, obstacle in arena.obstacles do
		table.insert(circles, {
			x = arena.center.X + obstacle.x,
			z = arena.center.Z + obstacle.z,
			radius = obstacle.radius,
		})
	end
	return circles
end

-- Position of the player's HumanoidRootPart, or nil while the character is missing.
function MapService.getRootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

function MapService.isInZone(position: Vector3, zone: Zone): boolean
	local layout = layoutFor(zone)
	local offset = position - layout.center
	local half = layout.size / 2
	return math.abs(offset.X) <= half and math.abs(offset.Z) <= half and offset.Y >= 0 and offset.Y <= layout.wallHeight
end

-- Moves the player's character to a zone. `slot` of `count` spreads participants around the arena start.
-- Yields until the character has loaded; does nothing if the character changes meanwhile.
function MapService.placeCharacter(player: Player, zone: Zone, slot: number, count: number)
	local character = player.Character
	if not character then
		return -- CharacterAdded will place the next character
	end
	local root = character:WaitForChild("HumanoidRootPart", CHARACTER_WAIT_SECONDS)
	if not (root and root:IsA("BasePart")) then
		return
	end
	local target = spawnPosition(zone, slot, count)
	-- With StreamingEnabled the floor at the target must reach the client before the character lands.
	pcall(player.RequestStreamAroundAsync, player, target)
	task.wait() -- let the default spawn finish so it does not overwrite this move
	if player.Character ~= character or root.Parent ~= character then
		return
	end
	local position = target + Vector3.new(0, rootHeight(character, root) + SPAWN_DROP_HEIGHT, 0)
	local center = layoutFor(zone).center
	local lookAt = Vector3.new(center.X, position.Y, center.Z)
	local cframe = if (lookAt - position).Magnitude > 0.1 then CFrame.lookAt(position, lookAt) else CFrame.new(position)
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(cframe)
end

-- Places the character in the zone only if it is not already standing there (e.g. after a normal spawn).
function MapService.ensureInZone(player: Player, zone: Zone)
	local character = player.Character
	if not character then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", CHARACTER_WAIT_SECONDS)
	if not (root and root:IsA("BasePart")) then
		return
	end
	task.wait()
	if player.Character == character and not MapService.isInZone(root.Position, zone) then
		MapService.placeCharacter(player, zone, 1, 1)
	end
end

return MapService
