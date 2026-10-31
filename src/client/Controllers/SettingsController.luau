--!strict
-- The settings menu (Paket 14, DESIGN.md section 13): a gear button in the top right corner opens a panel with
-- screen shake, damage numbers, the music and effects volumes and the graphics quality (Paket 22: Auto, High, Low;
-- GraphicsController decides what Auto means on this device). Changes apply at once and are sent with
-- SaveSettings once a burst of changes is over (Config.Settings); the server keeps them in the profile and sends them
-- back with ProfileInfo when the data loads. Volumes go to the SoundGroups "Music" and "Effects" in SoundService.
-- Read by CameraController (shake) and DamageNumberController; HUDController keeps its team panel below the button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local BUTTON_SIZE = 44
local MARGIN = 12
local PANEL_WIDTH = 380
local ROW_HEIGHT = 44
local TOGGLE_WIDTH = 96
local STEP_WIDTH = 44

local SettingsController = {}

-- (settings: Types.Settings): a setting changed (menu or loaded profile)
SettingsController.Changed = Signal.new()
-- Height in reference pixels the gear button takes at the top right, margins included (HUD team panel).
SettingsController.RESERVED_HEIGHT = BUTTON_SIZE + MARGIN

local current: Types.Settings = table.clone(Config.Settings.defaults) :: any
local changedAt = 0 -- os.clock() of the last change that is not sent yet; 0 = nothing to send
local screen: ScreenGui
local menu: Frame
local refreshers: { () -> () } = {}

local function soundGroup(name: string): SoundGroup
	local group = SoundService:FindFirstChild(name)
	if not (group and group:IsA("SoundGroup")) then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
	end
	return group :: SoundGroup
end

local function apply()
	soundGroup("Music").Volume = current.music
	soundGroup("Effects").Volume = current.effects
	for _, refresh in refreshers do
		refresh()
	end
	SettingsController.Changed:Fire(table.clone(current))
end

local function send()
	changedAt = 0
	Net.fireServer(
		"SaveSettings",
		current.shake,
		current.damageNumbers,
		current.music,
		current.effects,
		current.graphics
	)
end

-- Saves after Config.Settings.saveDelaySeconds without another change.
local function scheduleSave()
	local stamp = os.clock()
	changedAt = stamp
	task.delay(Config.Settings.saveDelaySeconds, function()
		if changedAt == stamp then
			send()
		end
	end)
end

local function set(key: string, value: any)
	if (current :: any)[key] == value then
		return
	end
	(current :: any)[key] = value
	apply()
	scheduleSave()
end

local function percent(value: number): string
	return `{math.round(value * 100)}%`
end

local function row(order: number, text: string): Frame
	local frame = Widgets.create("Frame", {
		Name = text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = order,
		Parent = menu,
	})
	Widgets.label({
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.5, 1),
		Parent = frame,
	})
	return frame
end

local function toggleRow(order: number, text: string, key: string)
	local frame = row(order, text)
	local button: TextButton
	button = Widgets.button({
		Name = "Toggle",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0, TOGGLE_WIDTH, 1, -6),
		Parent = frame,
	}, function()
		set(key, not (current :: any)[key])
	end)
	table.insert(refreshers, function()
		local on = (current :: any)[key] == true
		button.Text = if on then "ON" else "OFF"
		button.BackgroundColor3 = if on then Theme.accent else Theme.button
		button.TextColor3 = if on then Theme.accentText else Theme.text
	end)
end

local function volumeRow(order: number, text: string, key: string)
	local frame = row(order, text)
	local step = Config.Settings.volumeStep
	local function change(delta: number)
		local value = math.clamp(math.round(((current :: any)[key] + delta) / step) * step, 0, 1)
		set(key, value)
	end
	Widgets.button({
		Name = "Less",
		Text = "-",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(STEP_WIDTH + 70), 0.5, 0),
		Size = UDim2.new(0, STEP_WIDTH, 1, -6),
		Parent = frame,
	}, function()
		change(-step)
	end)
	local value = Widgets.label({
		Name = "Value",
		Font = Theme.fontBold,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -STEP_WIDTH, 0.5, 0),
		Size = UDim2.new(0, 70, 1, 0),
		Parent = frame,
	})
	Widgets.button({
		Name = "More",
		Text = "+",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0, STEP_WIDTH, 1, -6),
		Parent = frame,
	}, function()
		change(step)
	end)
	table.insert(refreshers, function()
		value.Text = percent((current :: any)[key])
	end)
end

-- A button that steps through `choices` (e.g. Config.Graphics.choices) and shows the current one in capitals.
local function choiceRow(order: number, text: string, key: string, choices: { string })
	local frame = row(order, text)
	local button = Widgets.button({
		Name = "Choice",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0, TOGGLE_WIDTH, 1, -6),
		Parent = frame,
	}, function()
		local index = table.find(choices, (current :: any)[key]) or 0
		set(key, choices[index % #choices + 1])
	end)
	table.insert(refreshers, function()
		button.Text = string.upper(tostring((current :: any)[key] or choices[1]))
	end)
end

local function build()
	screen = Widgets.screen("Settings", 6)
	screen.Enabled = true
	local holder = Widgets.create("Frame", {
		Name = "GearHolder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, 8),
		Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
		Parent = screen,
	})
	Widgets.scaled(holder)
	Widgets.button({
		Name = "Gear",
		Text = "⚙",
		TextSize = 26,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	}, function()
		SettingsController.setOpen(not menu.Visible)
	end)

	menu = Widgets.panel({
		Name = "Menu",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		Visible = false,
		Parent = screen,
	})
	Widgets.list(6).Parent = menu
	Widgets.label({
		Text = "SETTINGS",
		Font = Theme.fontBold,
		TextSize = Theme.titleSize,
		Size = UDim2.new(1, 0, 0, Theme.titleSize + 6),
		LayoutOrder = 0,
		Parent = menu,
	})
	toggleRow(1, "Screen shake", "shake")
	toggleRow(2, "Damage numbers", "damageNumbers")
	volumeRow(3, "Music", "music")
	volumeRow(4, "Effects", "effects")
	choiceRow(5, "Graphics", "graphics", Config.Graphics.choices)
	Widgets.label({
		Text = "Saved with your progress",
		TextSize = 14,
		TextColor3 = Theme.textDim,
		LayoutOrder = 6,
		Parent = menu,
	})
	Widgets.button({
		Name = "Close",
		Text = "CLOSE",
		LayoutOrder = 7,
		Parent = menu,
	}, function()
		SettingsController.setOpen(false)
	end)
end

-- Lifecycle -------------------------------------------------------------------------

function SettingsController.init()
	Net.onClient("ProfileInfo", function(info: Types.ProfileInfo)
		if info.settings and changedAt == 0 then -- a change not sent yet wins over the saved values
			current = table.clone(info.settings)
			if current.graphics == nil then -- a server from before Paket 22
				current.graphics = Config.Settings.defaults.graphics
			end
			apply()
		end
	end)
end

function SettingsController.start()
	build()
	apply()
end

-- Commands --------------------------------------------------------------------------

function SettingsController.setOpen(open: boolean)
	menu.Visible = open
end

-- Changes one setting as the menu would (tests).
function SettingsController.set(key: string, value: any)
	set(key, value)
end

-- Queries ---------------------------------------------------------------------------

function SettingsController.get(): Types.Settings
	return current
end

function SettingsController.isOpen(): boolean
	return menu ~= nil and menu.Visible
end

return SettingsController
