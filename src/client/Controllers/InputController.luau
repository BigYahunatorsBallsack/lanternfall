--!strict
-- Player input (DESIGN.md section 4): walking stays on Roblox's default controls (WASD, left stick,
-- touch thumbstick), jumping is replaced by the dash on Space, gamepad A and a touch/click button.
-- The client moves its own character for the dash at once and tells the server (RequestDash), which
-- checks the cooldown and grants the short invulnerability. Reads RunStateController and
-- PlayerStateController.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local PlayerStateController = require(script.Parent.PlayerStateController)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local DashConfig = Config.Player.dash
local ACTION_NAME = "LanternfallDash"
local ATTACHMENT_NAME = "LanternfallDashAttachment"
local BUTTON_SIZE_TOUCH = 120
local BUTTON_SIZE_DESKTOP = 84

local InputController = {}

local dashing = false
local button: TextButton
local cooldownFill: Frame

local function now(): number
	return workspace:GetServerTimeNow()
end

local function canDash(): boolean
	local info = RunStateController.getLocalPlayer()
	if RunStateController.getView() == "Run" and info and info.state ~= nil and info.state ~= "Alive" then
		return false
	end
	local state = RunStateController.get()
	if state and state.phase == "Shop" and info and info.participant then
		return false -- the shop between waves is a screen of its own
	end
	local vitals = PlayerStateController.getLocal()
	if vitals and vitals.choosing and Config.Run.levelUp.freezeWhileChoosing then
		return false -- standing still while picking a level-up card
	end
	return not dashing and now() >= PlayerStateController.getDashReadyAt()
end

-- Walking direction, or where the character faces when standing still. Flat and of length 1.
local function dashDirection(humanoid: Humanoid, root: BasePart): Vector3?
	local move = humanoid.MoveDirection
	local direction = Vector3.new(move.X, 0, move.Z)
	if direction.Magnitude < 0.1 then
		local look = root.CFrame.LookVector
		direction = Vector3.new(look.X, 0, look.Z)
	end
	if direction.Magnitude < 0.1 then
		return nil
	end
	return direction.Unit
end

local function tryDash()
	if not canDash() then
		return
	end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 and humanoid.WalkSpeed > 0) then
		return
	end
	local direction = dashDirection(humanoid, root)
	if not direction then
		return
	end

	dashing = true
	PlayerStateController.predictDash(now() + DashConfig.cooldown)
	Net.fireServer("RequestDash", direction)

	local attachment = root:FindFirstChild(ATTACHMENT_NAME)
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = ATTACHMENT_NAME
		attachment.Parent = root
	end
	-- Pushes along the floor only, so gravity and walls still work; walls and ruins stop the dash.
	local speed = DashConfig.distance / DashConfig.duration
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "LanternfallDash"
	velocity.Attachment0 = attachment :: Attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	velocity.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * speed
	velocity.MaxForce = math.huge
	velocity.Parent = root

	task.delay(DashConfig.duration, function()
		velocity:Destroy()
		dashing = false
	end)
end

local function onDashAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		tryDash()
	end
	return Enum.ContextActionResult.Sink -- also swallows the default jump on Space and A
end

local function onCharacterAdded(character: Model)
	dashing = false
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		-- The character is simulated on this client, so jumping must be switched off here too.
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
end

local function buildButton()
	local screen = Widgets.screen("Dash", 1)
	screen.Enabled = true
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local size = if touch then BUTTON_SIZE_TOUCH else BUTTON_SIZE_DESKTOP
	button = Widgets.button({
		Name = "DashButton",
		Text = if touch then "DASH" else "DASH\nSpace",
		TextSize = if touch then 26 else 18,
		AnchorPoint = Vector2.new(1, 1),
		Position = if touch then UDim2.new(1, -40, 1, -60) else UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.accent,
		TextColor3 = Theme.accentText,
		AutoButtonColor = false,
		Parent = screen,
	}, tryDash)
	button:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	-- Dark overlay that shrinks from the top while the dash recharges.
	cooldownFill = Widgets.create("Frame", {
		Name = "Cooldown",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.35,
		ZIndex = 2,
		Parent = button,
	}, { Widgets.corner(UDim.new(0.5, 0)) })
end

local function updateButton()
	local remaining = math.max(0, PlayerStateController.getDashReadyAt() - now())
	local fraction = math.clamp(remaining / DashConfig.cooldown, 0, 1)
	local target = UDim2.fromScale(1, fraction)
	if cooldownFill.Size ~= target then
		cooldownFill.Size = target
	end
end

function InputController.init()
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false) -- HP is in our HUD
	RunStateController.Changed:Connect(function(state)
		if state.phase == "Countdown" then
			PlayerStateController.clearPrediction() -- the server resets the cooldown at run start
		end
	end)
end

function InputController.start()
	buildButton()
	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		onDashAction,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA
	)
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	RunService.Heartbeat:Connect(updateButton)
end

-- For the smoke test and later tutorials (WP19).
InputController.dash = tryDash

return InputController
