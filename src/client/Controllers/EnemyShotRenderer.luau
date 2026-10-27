--!strict
-- Draws enemy projectiles (Spitter shots, DESIGN.md section 7) from the server's EnemyShots events: each censer
-- ember (a hot core in a pink halo with a fading trail) flies in server time from where it was fired and vanishes
-- at its range, or bursts into sparks where an "ended" entry says it hit a player or an obstacle. Parts are pooled
-- (WeaponRenderer/VisualKit) and moved with one workspace:BulkMoveTo per frame. Active only while the local player
-- is in a running run (RunStateController). The server decides every hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Bursts = require(script.Parent.Parent.Vfx.Bursts)
local RunStateController = require(script.Parent.RunStateController)
local VisualKit = require(script.Parent.WeaponRenderer.VisualKit)

local FOLDER_NAME = "LanternfallEnemyShots"
local SHOT_COLOR = Color3.fromRGB(255, 92, 200) -- the Spitter's censer
local CORE_COLOR = Color3.fromRGB(255, 220, 244)
local CORE_SIZE = 0.7 -- studs
local HALO_SIZE = 1.5 -- studs, a bit larger than the hit circle so it reads clearly
local HALO_TRANSPARENCY = 0.45
local TRAIL_WIDTH = 0.9
local TRAIL_SECONDS = 0.22
local HEIGHT = 2 -- studs above the floor
local FADE_STUDS = 4 -- the last studs before the range fade out
local HIT_SPARKS = 8

type ShotParts = { core: BasePart, halo: BasePart, trail: Trail }

type Shot = {
	parts: ShotParts?,
	x: number,
	z: number,
	dx: number,
	dz: number,
	speed: number,
	range: number,
	at: number,
	stopAt: number?, -- studs; set by an "ended" entry
}

local EnemyShotRenderer = {}

local shots: { [number]: Shot } = {}
local enabled = false
local folder: Folder? = nil
local floorY = Config.Map.arena.center.Y

local pool = VisualKit.objectPool(function(): ShotParts
	local core = VisualKit.part("EnemyShot", Enum.PartType.Ball, Vector3.one * CORE_SIZE, CORE_COLOR)
	local halo =
		VisualKit.halo("EnemyShotHalo", Enum.PartType.Ball, Vector3.one * HALO_SIZE, SHOT_COLOR, HALO_TRANSPARENCY)
	local trail = VisualKit.trail(core, SHOT_COLOR, TRAIL_WIDTH, TRAIL_SECONDS)
	trail.FaceCamera = true -- the ball never turns, so let the trail face the camera instead
	return { core = core, halo = halo, trail = trail }
end, function(parts: ShotParts): { BasePart }
	return { parts.core, parts.halo }
end)

local partList: { BasePart } = {}
local cframeList: { CFrame } = {}
local listLength = 0

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

local function remove(id: number, shot: Shot)
	if shot.parts then
		pool:release(shot.parts)
	end
	shots[id] = nil
end

local function clear()
	for id, shot in shots do
		remove(id, shot)
	end
end

local function onEvents(events: Types.EnemyShotEvents)
	if not enabled then
		return
	end
	if events.reset then
		clear()
	end
	for _, fired in events.fired do
		shots[fired.id] = {
			parts = nil,
			x = fired.x,
			z = fired.z,
			dx = fired.dx,
			dz = fired.dz,
			speed = fired.speed,
			range = fired.range,
			at = fired.at,
			stopAt = nil,
		}
	end
	local ended = events.ended
	for k = 1, #ended, 2 do
		local shot = shots[ended[k]]
		if shot then
			shot.stopAt = ended[k + 1]
		end
	end
end

local function render()
	if not enabled then
		return
	end
	local now = workspace:GetServerTimeNow()
	local count = 0
	for id, shot in shots do
		local distance = math.max(0, shot.speed * (now - shot.at))
		local stop = math.min(shot.range, shot.stopAt or math.huge)
		if distance >= stop then
			if shot.stopAt and shot.parts then
				local at = Vector3.new(shot.x + shot.dx * stop, floorY + HEIGHT, shot.z + shot.dz * stop)
				Bursts.emit("spark", SHOT_COLOR, at, HIT_SPARKS)
			end
			remove(id, shot)
			continue
		end
		local parts = shot.parts
		if not parts then
			local created = pool:acquire(getFolder())
			created.trail:Clear()
			shot.parts = created
			parts = created
		end
		local current = parts :: ShotParts
		local fade = math.clamp(1 - (shot.range - distance) / FADE_STUDS, 0, 1)
		current.core.Transparency = fade
		current.halo.Transparency = HALO_TRANSPARENCY + (1 - HALO_TRANSPARENCY) * fade
		local cframe = CFrame.new(shot.x + shot.dx * distance, floorY + HEIGHT, shot.z + shot.dz * distance)
		partList[count + 1] = current.core
		cframeList[count + 1] = cframe
		partList[count + 2] = current.halo
		cframeList[count + 2] = cframe
		count += 2
	end
	for k = count + 1, listLength do
		partList[k] = nil
		cframeList[k] = nil
	end
	listLength = count
	if count > 0 then
		workspace:BulkMoveTo(partList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function setEnabled(value: boolean)
	if value == enabled then
		return
	end
	enabled = value
	if not value then
		clear()
	end
end

-- Lifecycle -------------------------------------------------------------------------

function EnemyShotRenderer.init()
	Net.onClient("EnemyShots", onEvents)
	RunStateController.Changed:Connect(function()
		setEnabled(RunStateController.getView() == "Run")
	end)
end

function EnemyShotRenderer.start()
	setEnabled(RunStateController.getView() == "Run")
	RunService.RenderStepped:Connect(render)
end

-- Queries ---------------------------------------------------------------------------

-- Enemy projectiles on screen right now.
function EnemyShotRenderer.getCount(): number
	local count = 0
	for _ in shots do
		count += 1
	end
	return count
end

return EnemyShotRenderer
