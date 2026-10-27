--!strict
-- Fixed top-down camera (DESIGN.md section 4, values in Config.Camera): looks north at the local
-- character from a fixed angle and distance, no rotating or zooming. Started by the client bootstrap.
-- Because the camera never turns, W/stick-up always walks up the screen. shake() adds a short wobble for big hits
-- (Config.Feedback.shake; EnemyRenderer, ChestController, FeedbackController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local CameraConfig = Config.Camera
local RENDER_STEP_NAME = "LanternfallCamera"
local SNAP_DISTANCE = 40 -- studs: a jump this far (teleport to arena or lobby) moves the camera at once
local SHAKE_FREQUENCY = 18 -- noise samples per second; higher wobbles faster

local CameraController = {}

local pitch = math.rad(CameraConfig.pitchDegrees)
-- From the focus point back and up to the camera; the camera sits south of the character.
local offset = Vector3.new(0, math.sin(pitch), math.cos(pitch)) * CameraConfig.distance
local focus: Vector3? = nil
local shakeStrength = 0 -- 0-1, see shake()
local shakeTime = 0

-- Camera offset of the current shake: smooth noise, growing with the square of the strength.
local function shakeOffset(dt: number): Vector3
	if shakeStrength <= 0 then
		return Vector3.zero
	end
	local settings = Config.Feedback.shake
	shakeTime += dt * SHAKE_FREQUENCY
	local size = settings.maxStuds * shakeStrength * shakeStrength
	shakeStrength = math.max(0, shakeStrength - settings.decayPerSecond * dt)
	return Vector3.new(math.noise(shakeTime, 0.5), math.noise(shakeTime, 7.5), math.noise(shakeTime, 13.5)) * size * 2
end

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
	local wobble = shakeOffset(dt)
	camera.CFrame = CFrame.lookAt(current + offset + wobble, current + wobble)
end

-- Adds a camera shake of `strength` (0-1; shakes add up to at most 1, then fade out).
function CameraController.shake(strength: number)
	if Config.Feedback.shake.enabled and strength > 0 then
		shakeStrength = math.min(1, shakeStrength + strength)
	end
end

function CameraController.start()
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController
