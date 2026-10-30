--!strict
-- Draws red crosses on the arena floor where a spawn group will appear (DESIGN.md section 7, since B9), from the
-- server's SpawnMarkers events (SpawnDirector). Each cross pulses until the enemies come, then goes back to its pool.
-- Crosses are placed once; only their transparency changes each frame. The server decides every spawn; this only
-- shows it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local VisualKit = require(script.Parent.WeaponRenderer.VisualKit)

local FOLDER_NAME = "LanternfallSpawnMarkers"
local COLOR = Color3.fromRGB(230, 48, 48)
local ARM = Vector3.new(2.6, 0.08, 0.45) -- one bar of the cross, studs
local PULSES_PER_SECOND = 3
local MAX_MARKERS = 200 -- more at once are not drawn (performance budget)

type Marker = { parts: { BasePart }, spawnsAt: number }

local SpawnMarkerRenderer = {}

local floorY = Config.Map.arena.center.Y
local folder: Folder? = nil
local markers: { Marker } = {}

local pool = VisualKit.objectPool(function(): { BasePart }
	local first = VisualKit.part("SpawnMarker", Enum.PartType.Block, ARM, COLOR)
	local second = VisualKit.part("SpawnMarker", Enum.PartType.Block, ARM, COLOR)
	return { first, second }
end, function(parts: { BasePart }): { BasePart }
	return parts
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

local function onMarkers(event: Types.SpawnMarkers)
	if typeof(event) ~= "table" or typeof(event.points) ~= "table" or typeof(event.spawnsAt) ~= "number" then
		return
	end
	local points = event.points
	for k = 1, #points - 1, 2 do
		if #markers >= MAX_MARKERS then
			return
		end
		local x, z = points[k], points[k + 1]
		if typeof(x) == "number" and typeof(z) == "number" then
			local parts = pool:acquire(getFolder())
			local at = CFrame.new(x, floorY + ARM.Y / 2 + 0.02, z)
			parts[1].CFrame = at * CFrame.Angles(0, math.rad(45), 0)
			parts[2].CFrame = at * CFrame.Angles(0, math.rad(-45), 0)
			table.insert(markers, { parts = parts, spawnsAt = event.spawnsAt })
		end
	end
end

local function render()
	if #markers == 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	local pulse = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(now * PULSES_PER_SECOND * 2 * math.pi))
	for index = #markers, 1, -1 do
		local marker = markers[index]
		if now >= marker.spawnsAt then
			pool:release(marker.parts)
			markers[index] = markers[#markers]
			markers[#markers] = nil
		else
			for _, part in marker.parts do
				part.Transparency = pulse
			end
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
