--!strict
-- Draws red crosses on the arena floor where a spawn group will appear (DESIGN.md section 7, since B9), from the
-- server's SpawnMarkers events (SpawnDirector). Each cross is a thick brush-like X with a dark rim on a flat floor
-- canvas (Config/Sprites spawnMarker): it pops in, blinks pale until the enemies come, then goes back to its pool. The
-- server decides every spawn; this only shows it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local Look = require(Shared:WaitForChild("Config"):WaitForChild("Sprites")).spawnMarker

local VisualKit = require(script.Parent.WeaponRenderer.VisualKit)

local FOLDER_NAME = "LanternfallSpawnMarkers"
local COLOR = Color3.fromRGB(table.unpack(Look.color))
local OUTLINE_COLOR = Color3.fromRGB(table.unpack(Look.outlineColor))
local PALE_COLOR = Color3.fromRGB(table.unpack(Look.paleColor))
local PALE_OUTLINE_COLOR = Color3.fromRGB(table.unpack(Look.paleOutlineColor))
local CANVAS_STUDS = Look.size * 1.2 -- room for tilt, longer bars and the rim
local THICKNESS = 0.05 -- studs of the invisible floor part
local LIFT = 0.04 -- studs above the floor, clear of floor tiles
local PILL = UDim.new(0.5, 0) -- round bar ends

type Cross = {
	part: Part,
	scale: UIScale,
	bars: { Frame }, -- outline frames first, then the red ones
}

type Marker = { cross: Cross, spawnsAt: number, shownAt: number }

local SpawnMarkerRenderer = {}

local floorY = Config.Map.arena.center.Y
local folder: Folder? = nil
local markers: { Marker } = {}
local random = Random.new()

local function bar(parent: Instance, color: Color3, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Bar"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = order
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = PILL
	corner.Parent = frame
	return frame
end

local function build(): Cross
	local part = Instance.new("Part")
	part.Name = "SpawnMarker"
	part.Size = Vector3.new(CANVAS_STUDS, THICKNESS, CANVAS_STUDS)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Cross"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = Look.pixelsPerStud
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = part

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = holder

	local bars = {
		bar(holder, OUTLINE_COLOR, 1),
		bar(holder, OUTLINE_COLOR, 1),
		bar(holder, COLOR, 2),
		bar(holder, COLOR, 2),
	}
	return { part = part, scale = scale, bars = bars }
end

local pool = VisualKit.objectPool(build, function(cross: Cross): { BasePart }
	return { cross.part }
end)

local function getFolder(): Folder
	local current = folder
	if current then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = workspace
	folder = created
	return created
end

-- A fresh look for a reused cross: its own small tilt and bar lengths, so a group does not look stamped.
local function shape(cross: Cross)
	local tilt = random:NextNumber(-Look.tiltDegrees, Look.tiltDegrees)
	local rim = Look.outlineStuds * 2
	for index = 1, 2 do
		local length = Look.size * (1 + random:NextNumber(-Look.lengthJitter, Look.lengthJitter))
		local rotation = tilt + (if index == 1 then 45 else -45)
		local outline, red = cross.bars[index], cross.bars[index + 2]
		outline.Size = UDim2.fromScale((length + rim) / CANVAS_STUDS, (Look.barStuds + rim) / CANVAS_STUDS)
		red.Size = UDim2.fromScale(length / CANVAS_STUDS, Look.barStuds / CANVAS_STUDS)
		outline.Rotation = rotation
		red.Rotation = rotation
	end
	cross.scale.Scale = Look.popScale
end

local function onMarkers(event: Types.SpawnMarkers)
	if typeof(event) ~= "table" or typeof(event.points) ~= "table" or typeof(event.spawnsAt) ~= "number" then
		return
	end
	local points = event.points
	local now = workspace:GetServerTimeNow()
	for k = 1, #points - 1, 2 do
		if #markers >= Look.maxShown then
			return
		end
		local x, z = points[k], points[k + 1]
		if typeof(x) == "number" and typeof(z) == "number" then
			local cross = pool:acquire(getFolder())
			shape(cross)
			cross.part.CFrame = CFrame.new(x, floorY + THICKNESS / 2 + LIFT, z)
			table.insert(markers, { cross = cross, spawnsAt = event.spawnsAt, shownAt = now })
		end
	end
end

local function render()
	if #markers == 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	local wave = 0.5 + 0.5 * math.sin(now * Look.pulsesPerSecond * 2 * math.pi)
	local pale = wave * Look.paleShare
	local color = COLOR:Lerp(PALE_COLOR, pale)
	local outlineColor = OUTLINE_COLOR:Lerp(PALE_OUTLINE_COLOR, pale)
	for index = #markers, 1, -1 do
		local marker = markers[index]
		local cross = marker.cross
		if now >= marker.spawnsAt then
			pool:release(cross)
			markers[index] = markers[#markers]
			markers[#markers] = nil
		else
			local grow = math.clamp((now - marker.shownAt) / Look.popSeconds, 0, 1)
			if cross.scale.Scale < 1 then
				local eased = 1 - (1 - grow) ^ 3
				cross.scale.Scale = Look.popScale + (1 - Look.popScale) * eased
			end
			local bars = cross.bars
			bars[1].BackgroundColor3 = outlineColor
			bars[2].BackgroundColor3 = outlineColor
			bars[3].BackgroundColor3 = color
			bars[4].BackgroundColor3 = color
		end
	end
end

-- Lifecycle -------------------------------------------------------------------------

function SpawnMarkerRenderer.init()
	Net.onClient("SpawnMarkers", onMarkers)
end

function SpawnMarkerRenderer.start()
	RunService.RenderStepped:Connect(render)
end

-- Queries ---------------------------------------------------------------------------

-- Crosses on the floor right now (tests).
function SpawnMarkerRenderer.getCount(): number
	return #markers
end

return SpawnMarkerRenderer
