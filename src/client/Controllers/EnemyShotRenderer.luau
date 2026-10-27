--!strict
-- Draws enemy projectiles (Spitter shots, DESIGN.md section 7) from the server's EnemyShots events: each glowing
-- ball flies in server time from where it was fired and vanishes at its range or where an "ended" entry says it hit
-- a player or an obstacle. Parts are pooled (WeaponRenderer/VisualKit) and moved with one workspace:BulkMoveTo per
-- frame. Active only while the local player is in a running run (RunStateController). The server decides every hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local RunStateController = require(script.Parent.RunStateController)
local VisualKit = require(script.Parent.WeaponRenderer.VisualKit)

local FOLDER_NAME = "LanternfallEnemyShots"
local SHOT_COLOR = Color3.fromRGB(255, 92, 200) -- the Spitter's mouth
local SHOT_SIZE = 1.3 -- studs, a bit larger than the hit circle so it reads clearly
local HEIGHT = 2 -- studs above the floor
local FADE_STUDS = 4 -- the last studs before the range fade out

type Shot = {
	part: BasePart?,
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

local pool = VisualKit.pool(function()
	return VisualKit.part("EnemyShot", Enum.PartType.Ball, Vector3.one * SHOT_SIZE, SHOT_COLOR)
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
	if shot.part then
		pool:release(shot.part)
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
			part = nil,
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
		if distance >= math.min(shot.range, shot.stopAt or math.huge) then
			remove(id, shot)
			continue
		end
		local part = shot.part
		if not part then
			part = pool:acquire(getFolder())
			shot.part = part
		end
		local ball = part :: BasePart
		ball.Transparency = math.clamp(1 - (shot.range - distance) / FADE_STUDS, 0, 1)
		count += 1
		partList[count] = ball
		cframeList[count] = CFrame.new(shot.x + shot.dx * distance, floorY + HEIGHT, shot.z + shot.dz * distance)
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
