--!strict
-- Fixed top-down camera (DESIGN.md section 4, values in Config.Camera): looks north at the local
-- character from a fixed angle and distance, no rotating or zooming. Started by the client bootstrap.
-- Because the camera never turns, W/stick-up always walks up the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local CameraConfig = Config.Camera
local RENDER_STEP_NAME = "LanternfallCamera"
local SNAP_DISTANCE = 40 -- studs: a jump this far (teleport to arena or lobby) moves the camera at once

local CameraController = {}

local pitch = math.rad(CameraConfig.pitchDegrees)
-- From the focus point back and up to the camera; the camera sits south of the character.
local offset = Vector3.new(0, math.sin(pitch), math.cos(pitch)) * CameraConfig.distance
local focus: Vector3? = nil

local function targetPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + Vector3.new(0, CameraConfig.targetHeightOffset, 0)
	end
	return nil
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if camera.FieldOfView ~= CameraConfig.fieldOfView then
		camera.FieldOfView = CameraConfig.fieldOfView
	end

	local target = targetPosition()
	if not target then
		return -- keep looking where the character was until the next one loads
	end
	local current = focus
	if current == nil or (target - current).Magnitude > SNAP_DISTANCE then
		current = target
	else
		-- frame-rate independent smoothing
		local alpha = 1 - math.exp(-CameraConfig.followSharpness * dt)
		current += (target - current) * alpha
	end
	focus = current
	camera.CFrame = CFrame.lookAt(current + offset, current)
end

function CameraController.start()
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController
