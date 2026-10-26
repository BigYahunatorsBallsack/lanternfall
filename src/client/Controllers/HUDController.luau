--!strict
-- In-run HUD for the prototype: run timer, phase hint and the team with Alive/Down states.
-- Shown while the local player is in a running run; reads RunStateController. WP14 builds the full HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local STATE_TEXT: { [string]: string } = { Alive = "alive", Down = "DOWN", Out = "out" }

local HUDController = {}

local screen: ScreenGui
local timerLabel: TextLabel
local hintLabel: TextLabel
local teamRows: Frame

local function hintText(state: Types.RunState): (string, Color3)
	if state.phase == "Boss" then
		return string.upper(Config.Enemies.boss.displayName), Theme.danger
	end
	return `Survive until {Format.time(Config.Run.durationSeconds)}`, Theme.textDim
end

local function renderTeam(state: Types.RunState)
	Widgets.clearRows(teamRows)
	local order = 0
	for _, info in state.players do
		if info.participant then
			order += 1
			local stateName = info.state or "Alive"
			Widgets.label({
				Text = `{info.name} · {STATE_TEXT[stateName] or stateName}`,
				TextColor3 = if stateName == "Alive" then Theme.text else Theme.danger,
				TextXAlignment = Enum.TextXAlignment.Right,
				LayoutOrder = order,
				Parent = teamRows,
			})
		end
	end
end

local function render()
	local state = RunStateController.get()
	screen.Enabled = state ~= nil and RunStateController.getView() == "Run"
	if not (state and screen.Enabled) then
		return
	end
	local hint, color = hintText(state)
	hintLabel.Text = hint
	hintLabel.TextColor3 = color
	renderTeam(state)
end

local function build()
	screen = Widgets.screen("HUD", 0)

	local top = Widgets.panel({
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(260, 0),
		Parent = screen,
	})
	Widgets.list(2).Parent = top
	timerLabel = Widgets.label({
		Text = "00:00",
		Font = Theme.fontBold,
		TextSize = 44,
		Size = UDim2.new(1, 0, 0, 48),
		TextColor3 = Theme.accent,
		LayoutOrder = 1,
		Parent = top,
	})
	hintLabel = Widgets.label({ TextSize = 18, LayoutOrder = 2, Parent = top })

	local team = Widgets.panel({
		Name = "Team",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(260, 0),
		Parent = screen,
	})
	Widgets.list(4).Parent = team
	Widgets.label({
		Text = "TEAM",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 0,
		Parent = team,
	})
	teamRows = Widgets.create("Frame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		Parent = team,
	})
	Widgets.list(4).Parent = teamRows
end

function HUDController.start()
	build()
	RunStateController.Changed:Connect(render)
	render()

	RunService.Heartbeat:Connect(function()
		if screen.Enabled then
			local text = Format.time(RunStateController.getElapsed())
			if timerLabel.Text ~= text then
				timerLabel.Text = text
			end
		end
	end)
end

return HUDController
