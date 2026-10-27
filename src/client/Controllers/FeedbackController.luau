--!strict
-- Small feel effects around the players (DESIGN.md section 14, hit feedback): a camera shake when the local player
-- loses HP (PlayerStateController), a golden ring of light around their character on every team level-up
-- (ProgressController), and for every player's dash a streak of light behind them with gold sparks and a puff of
-- smoke where it started (PlayerStateController.Dashed, Vfx/Bursts). Strengths in Config.Feedback.shake. Active
-- only in a running run (RunStateController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Bursts = require(script.Parent.Parent.Vfx.Bursts)
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

local DASH_TRAIL_NAME = "LanternfallDashTrail"
local DASH_COLOR = Color3.fromRGB(255, 214, 120)
local DASH_SMOKE_COLOR = Color3.fromRGB(90, 84, 96)
local DASH_TRAIL_HEIGHT = 2.6 -- studs, the streak's width across the character
local DASH_TRAIL_SECONDS = 0.25
local DASH_SPARKS = 10
local DASH_SMOKE = 4

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

-- The streak behind a character's root part, made once per character and switched on for each dash.
local function dashTrail(root: BasePart): Trail
	local existing = root:FindFirstChild(DASH_TRAIL_NAME)
	if existing and existing:IsA("Trail") then
		return existing
	end
	local top = Instance.new("Attachment")
	top.Name = "DashTrailTop"
	top.Position = Vector3.new(0, DASH_TRAIL_HEIGHT / 2, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "DashTrailBottom"
	bottom.Position = Vector3.new(0, -DASH_TRAIL_HEIGHT / 2, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = DASH_TRAIL_NAME
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(DASH_COLOR)
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Lifetime = DASH_TRAIL_SECONDS
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
	trail.Enabled = false
	trail.Parent = root
	return trail
end

local function playDash(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local floor = Config.Map.arena.center.Y
	local position = root.Position
	Bursts.emit("spark", DASH_COLOR, position, DASH_SPARKS)
	Bursts.emit("smoke", DASH_SMOKE_COLOR, Vector3.new(position.X, floor + 0.8, position.Z), DASH_SMOKE)
	local trail = dashTrail(root)
	trail:Clear()
	trail.Enabled = true
	task.delay(Config.Player.dash.duration, function()
		trail.Enabled = false
	end)
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
	PlayerStateController.Dashed:Connect(function(userId: number)
		if inRun() then
			playDash(userId)
		end
	end)
	ProgressController.TeamChanged:Connect(function(progress: Types.TeamProgress, previous: Types.TeamProgress?)
		if previous and progress.level > previous.level and inRun() then
			playRing()
		end
	end)
end

return FeedbackController
