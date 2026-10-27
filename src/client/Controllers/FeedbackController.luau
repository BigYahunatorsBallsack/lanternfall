--!strict
-- Small feel effects around the local player (DESIGN.md section 14, hit feedback): a camera shake when they lose HP
-- (PlayerStateController) and a golden ring of light around their character on every team level-up
-- (ProgressController). Strengths in Config.Feedback.shake. Active only in a running run (RunStateController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local CameraController = require(script.Parent.CameraController)
local PlayerStateController = require(script.Parent.PlayerStateController)
local ProgressController = require(script.Parent.ProgressController)
local RunStateController = require(script.Parent.RunStateController)

local RING_COLOR = Color3.fromRGB(255, 205, 90)
local RING_START = 3 -- studs across
local RING_END = 22
local RING_SECONDS = 0.55
local RING_HEIGHT = 0.3 -- studs above the floor
local RING_THICKNESS = 0.2

local FeedbackController = {}

local ring: BasePart? = nil

local function inRun(): boolean
	return RunStateController.getView() == "Run"
end

local function getRing(): BasePart
	local current = ring
	if current then
		return current
	end
	local part = Instance.new("Part")
	part.Name = "LanternfallLevelRing"
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.Neon
	part.Color = RING_COLOR
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(RING_THICKNESS, RING_START, RING_START)
	part.Parent = workspace
	ring = part
	return part
end

-- A flat disc of light that grows out of the character and fades.
local function playRing()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local part = getRing()
	local floor = Config.Map.arena.center.Y + RING_HEIGHT
	local position = root.Position
	-- a cylinder's axis is X: lay it flat
	part.CFrame = CFrame.new(position.X, floor, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	part.Size = Vector3.new(RING_THICKNESS, RING_START, RING_START)
	part.Transparency = 0.2
	TweenService:Create(part, TweenInfo.new(RING_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(RING_THICKNESS, RING_END, RING_END),
		Transparency = 1,
	}):Play()
end

-- Lifecycle -------------------------------------------------------------------------

function FeedbackController.init()
	PlayerStateController.Changed:Connect(
		function(userId: number, vitals: Types.PlayerVitals, previous: Types.PlayerVitals?)
			if userId == Players.LocalPlayer.UserId and previous and vitals.hp < previous.hp and inRun() then
				CameraController.shake(Config.Feedback.shake.playerHit)
			end
		end
	)
	ProgressController.TeamChanged:Connect(function(progress: Types.TeamProgress, previous: Types.TeamProgress?)
		if previous and progress.level > previous.level and inRun() then
			playRing()
		end
	end)
end

return FeedbackController
