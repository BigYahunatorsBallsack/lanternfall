--!strict
-- Debug panel for admins (player attribute "LanternfallAdmin", set by AdminService): one button per
-- debug command. The server checks admin rights again, so this panel is only a convenience.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local DebugCommands = require(Shared:WaitForChild("Net"):WaitForChild("DebugCommands"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local ADMIN_ATTRIBUTE = "LanternfallAdmin"

local BUTTON_TEXT: { [string]: string } = {
	SkipMinute = "+1 minute",
	SkipToBoss = `Skip to {Format.time(Config.Run.durationSeconds - Config.Admin.skipToBossLeadSeconds)}`,
	DownSelf = "Knock me down",
	ReviveSelf = "Stand up again",
	WinRun = "Win the run",
}

local DebugController = {}

local function build(): ScreenGui
	local screen = Widgets.screen("Debug", 10)
	local panel = Widgets.panel({
		Name = "Debug",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(200, 0),
		Parent = screen,
	})
	Widgets.list(6).Parent = panel

	local buttons: { TextButton } = {}
	local open = true
	local header: TextButton
	header = Widgets.button({
		Name = "Header",
		Text = "DEBUG (hide)",
		TextSize = 16,
		TextColor3 = Theme.accent,
		Size = UDim2.fromOffset(172, 32),
		LayoutOrder = 0,
		Parent = panel,
	}, function()
		open = not open
		header.Text = if open then "DEBUG (hide)" else "DEBUG"
		for _, button in buttons do
			button.Visible = open
		end
	end)

	for index, command in DebugCommands do
		local button = Widgets.button({
			Name = command,
			Text = BUTTON_TEXT[command] or command,
			TextSize = 16,
			Size = UDim2.fromOffset(172, 38),
			LayoutOrder = index,
			Parent = panel,
		}, function()
			Net.fireServer("DebugCommand", command)
		end)
		table.insert(buttons, button)
	end
	return screen
end

function DebugController.start()
	local player = Players.LocalPlayer
	local screen: ScreenGui? = nil
	local function update()
		local isAdmin = player:GetAttribute(ADMIN_ATTRIBUTE) == true
		if isAdmin and not screen then
			screen = build()
		end
		if screen then
			screen.Enabled = isAdmin
		end
	end
	player:GetAttributeChangedSignal(ADMIN_ATTRIBUTE):Connect(update)
	update()
end

return DebugController
