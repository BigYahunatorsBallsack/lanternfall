--!strict
-- Small helpers that build the prototype UI in code. Used by the UI controllers. Buttons click (Audio/Sfx, Paket 21).
-- Sizes are pixels on a 1280x720 reference screen; panels made with Widgets.panel scale with the viewport.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)
local Theme = require(script.Parent.Theme)

local REFERENCE_SIZE = Vector2.new(1280, 720)
local MIN_SCALE = 0.6 -- keeps text readable on phones
local MAX_SCALE = 1.5

local Widgets = {}

local scales: { UIScale } = {}
local watchingViewport = false

local function viewportScale(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	local scale = math.min(viewport.X / REFERENCE_SIZE.X, viewport.Y / REFERENCE_SIZE.Y)
	return math.clamp(scale, MIN_SCALE, MAX_SCALE)
end

local function updateScales()
	local scale = viewportScale()
	for _, uiScale in scales do
		uiScale.Scale = scale
	end
end

local function watchViewport()
	if watchingViewport then
		return
	end
	watchingViewport = true
	local connection: RBXScriptConnection? = nil
	local function onCamera()
		if connection then
			connection:Disconnect()
		end
		local camera = workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales)
		end
		updateScales()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(onCamera)
	onCamera()
end

-- Creates an instance, sets its properties (Parent last) and parents the children to it.
function Widgets.create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Widgets.corner(radius: UDim?): UICorner
	return Widgets.create("UICorner", { CornerRadius = radius or Theme.corner })
end

function Widgets.padding(pixels: number): UIPadding
	local offset = UDim.new(0, pixels)
	return Widgets.create("UIPadding", {
		PaddingTop = offset,
		PaddingBottom = offset,
		PaddingLeft = offset,
		PaddingRight = offset,
	})
end

function Widgets.list(padding: number, direction: Enum.FillDirection?): UIListLayout
	return Widgets.create("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- ScreenGui in the PlayerGui that survives respawns. Starts hidden.
function Widgets.screen(name: string, displayOrder: number): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	return Widgets.create("ScreenGui", {
		Name = name,
		DisplayOrder = displayOrder,
		ResetOnSpawn = false,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
end

-- Dark rounded panel that scales with the screen. Grows in height with its content.
function Widgets.panel(props: { [string]: any }): Frame
	watchViewport()
	local uiScale = Widgets.create("UIScale", { Scale = viewportScale() })
	table.insert(scales, uiScale)
	local defaults = {
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = Theme.panelTransparency,
		AutomaticSize = Enum.AutomaticSize.Y,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Widgets.create("Frame", defaults, {
		uiScale,
		Widgets.corner(),
		Widgets.padding(14),
		Widgets.create("UIStroke", { Color = Theme.stroke, Thickness = 1.5 }),
	})
end

function Widgets.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.font,
		TextColor3 = Theme.text,
		TextSize = Theme.textSize,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, Theme.textSize + 6),
	}
	for key, value in props do
		defaults[key] = value
	end
	return Widgets.create("TextLabel", defaults)
end

function Widgets.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local defaults = {
		BackgroundColor3 = Theme.button,
		Font = Theme.fontBold,
		TextColor3 = Theme.text,
		TextSize = Theme.textSize,
		TextWrapped = true,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(240, 52),
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = Widgets.create("TextButton", defaults, { Widgets.corner() })
	button.Activated:Connect(function()
		Sfx.play("uiClick") -- Paket 21
		onClick()
	end)
	return button
end

-- True on small screens (phones): the HUD and the results screen use their compact layout (Paket 14).
function Widgets.isCompact(): boolean
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local viewport = camera.ViewportSize
	local settings = Config.Settings
	return viewport.X < settings.compactWidth or viewport.Y < settings.compactHeight
end

-- Gives a frame that is not a panel the same screen scale as the panels.
function Widgets.scaled(frame: GuiObject)
	watchViewport()
	local uiScale = Widgets.create("UIScale", { Scale = viewportScale(), Parent = frame })
	table.insert(scales, uiScale)
end

-- Removes every GuiObject child (rows of a list) but keeps layouts and decorations.
function Widgets.clearRows(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Widgets
