--!strict
-- Capture mode for icons, thumbnails and clips (Paket 24, Config.Launch.capture). Admins only (player attribute
-- "LanternfallAdmin"): the toggle key (or the debug panel button) hides every menu of PlayerGui and Roblox's own
-- buttons, the shot key cycles the camera shots (CameraController.setShot). A small hint shows after each key press
-- and fades, so the picture stays clean. Started by the client bootstrap; DebugController calls toggle().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local CameraController = require(script.Parent.CameraController)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local ADMIN_ATTRIBUTE = "LanternfallAdmin"
local HINT_NAME = "CaptureHint"

local CaptureController = {}

local active = false
local shotIndex = 1
local hidden: { ScreenGui } = {} -- menus this mode switched off, switched on again when it ends
local addedConnection: RBXScriptConnection? = nil
local hintScreen: ScreenGui? = nil
local hintLabel: TextLabel? = nil
local hintToken = 0

local function isAdmin(): boolean
	return Players.LocalPlayer:GetAttribute(ADMIN_ATTRIBUTE) == true
end

local function setCoreGui(enabled: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, enabled)
	end)
end

local function hint(text: string)
	if not hintScreen then
		local screen = Widgets.screen(HINT_NAME, 100)
		hintLabel = Widgets.label({
			Name = "Hint",
			Text = "",
			TextSize = 16,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.fromOffset(520, 24),
			Parent = screen,
		})
		hintScreen = screen
	end
	local screen = hintScreen :: ScreenGui
	local label = hintLabel :: TextLabel
	label.Text = text
	screen.Enabled = true
	hintToken += 1
	local token = hintToken
	task.delay(Config.Launch.capture.hintSeconds, function()
		if token == hintToken then
			screen.Enabled = false
		end
	end)
end

local function hide(gui: Instance)
	if gui:IsA("ScreenGui") and gui.Name ~= HINT_NAME and gui.Enabled then
		gui.Enabled = false
		table.insert(hidden, gui)
	end
end

local function shotName(): string
	return Config.Launch.capture.shots[shotIndex].name
end

function CaptureController.isActive(): boolean
	return active
end

-- Capture mode on or off. Ignored for players without admin rights.
function CaptureController.toggle()
	if not isAdmin() then
		return
	end
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end
	active = not active
	if active then
		for _, child in playerGui:GetChildren() do
			hide(child)
		end
		-- menus opened later (a level-up, the shop) stay hidden too
		addedConnection = playerGui.ChildAdded:Connect(function(child)
			task.defer(hide, child)
		end)
		setCoreGui(false)
		hint(
			`Capture mode: {shotName()} ({Config.Launch.capture.shotKey} next shot, `
				.. `{Config.Launch.capture.toggleKey} back)`
		)
	else
		if addedConnection then
			addedConnection:Disconnect()
			addedConnection = nil
		end
		for _, gui in hidden do
			if gui.Parent then
				gui.Enabled = true
			end
		end
		table.clear(hidden)
		setCoreGui(true)
		shotIndex = 1
		CameraController.setShot(nil)
		hint("Capture mode off")
	end
end

-- The next camera shot (only while capture mode is on).
function CaptureController.nextShot()
	if not active then
		return
	end
	local shots = Config.Launch.capture.shots
	shotIndex = shotIndex % #shots + 1
	CameraController.setShot(shots[shotIndex])
	hint(`Shot: {shotName()}`)
end

function CaptureController.start()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode.Name == Config.Launch.capture.toggleKey then
			CaptureController.toggle()
		elseif input.KeyCode.Name == Config.Launch.capture.shotKey then
			CaptureController.nextShot()
		end
	end)
end

return CaptureController
