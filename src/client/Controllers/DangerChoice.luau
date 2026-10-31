--!strict
-- B11 lobby extension: danger level 0-5 and the enemy sliders for the next run (Config.Difficulty),
-- shared by everyone in the server. Mounted and rendered by LobbyController; sends SetRunOptions.
-- Since the playtest after Paket 24 there is no endless switch any more: the run asks after the boss wave (ShopController).
-- Since Paket 13 levels above the one open for the local player's character are dimmed (the server allows them only
-- if someone in the lobby has them open).
-- Paket 15: on the hub the choice belongs to the party (PartyController's options); only its leader changes it.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local DangerRules = require(Shared:WaitForChild("Util"):WaitForChild("DangerRules"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local CharacterChoice = require(script.Parent.CharacterChoice)
local PartyController = require(script.Parent.PartyController)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local BUTTON_COOLDOWN = 0.2 -- seconds; keeps taps below the server rate limit

local Difficulty = Config.Difficulty

local DangerChoice = {}

local levelButtons: { [number]: TextButton } = {}
local description: TextLabel?
local sliderLabels: { [string]: TextLabel } = {}
local titleLabel: TextLabel? = nil
local lastPress = 0

local function current(): Types.RunOptions
	local party = PartyController.get()
	if party and party.role == "Hub" then
		return party.options
	end
	local state = RunStateController.get()
	return if state and state.options then state.options else DangerRules.defaultOptions()
end

local function send(change: (Types.RunOptions) -> ())
	local now = os.clock()
	if now - lastPress < BUTTON_COOLDOWN then
		return
	end
	lastPress = now
	local options = table.clone(current())
	change(options)
	local clean = DangerRules.clean(options)
	Net.fireServer(
		"SetRunOptions",
		clean.danger,
		false, -- endless: since the playtest after Paket 24 chosen after the boss wave (ChooseEndless)
		clean.enemyHp,
		clean.enemyDamage,
		clean.enemySpeed,
		clean.enemyCount
	)
end

function DangerChoice.render()
	if not description then
		return
	end
	local options = current()
	local me = RunStateController.getLocalPlayer()
	local open = if me then CharacterChoice.maxDanger(me.classId) else Config.Progress.startDanger
	for level, button in levelButtons do
		local chosen = level == options.danger
		button.BackgroundColor3 = if chosen then Theme.danger else Theme.button
		button.TextColor3 = if chosen then Theme.accentText elseif level > open then Theme.textDim else Theme.text
	end
	local note = if open < #Difficulty.levels - 1
		then `\nOpen for your character: 0-{open}. Win danger {open} with it to open {open + 1}.`
		else ""
	description.Text = DangerRules.level(options.danger).description .. note
	if titleLabel then
		titleLabel.Text = if not PartyController.isHub()
			then "DANGER (whole lobby)"
			elseif PartyController.isLeader() then "DANGER (your party)"
			else "DANGER (your leader picks)"
	end
	for id, label in sliderLabels do
		local slider = (Difficulty.sliders :: any)[id]
		label.Text = `{slider.label} {(options :: any)[id]}%`
	end
end

local function sliderRow(parent: Frame, id: string, order: number)
	local slider = (Difficulty.sliders :: any)[id]
	local row = Widgets.create("Frame", {
		Name = `Slider_{id}`,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = order,
		Parent = parent,
	})
	Widgets.list(6, Enum.FillDirection.Horizontal).Parent = row
	Widgets.button({
		Name = "Less",
		Text = "-",
		TextSize = 20,
		Size = UDim2.fromOffset(44, 44),
		LayoutOrder = 1,
		Parent = row,
	}, function()
		send(function(options)
			(options :: any)[id] -= slider.step
		end)
	end)
	sliderLabels[id] = Widgets.label({
		Name = "Value",
		TextSize = 16,
		Size = UDim2.new(1, -100, 1, 0),
		LayoutOrder = 2,
		Parent = row,
	})
	Widgets.button({
		Name = "More",
		Text = "+",
		TextSize = 20,
		Size = UDim2.fromOffset(44, 44),
		LayoutOrder = 3,
		Parent = row,
	}, function()
		send(function(options)
			(options :: any)[id] += slider.step
		end)
	end)
end

-- Builds the panel on the right side of the lobby screen.
function DangerChoice.mount(screen: ScreenGui)
	local panel = Widgets.panel({
		Name = "Danger",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 90),
		Size = UDim2.fromOffset(300, 0),
		Parent = screen,
	})
	Widgets.list(6).Parent = panel
	titleLabel = Widgets.label({
		Name = "Title",
		Text = "DANGER (whole lobby)",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		LayoutOrder = 1,
		Parent = panel,
	})
	local row = Widgets.create("Frame", {
		Name = "Levels",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 2,
		Parent = panel,
	})
	Widgets.list(4, Enum.FillDirection.Horizontal).Parent = row
	for index, level in Difficulty.levels do
		levelButtons[level.level] = Widgets.button({
			Name = `Danger{level.level}`,
			Text = tostring(level.level),
			TextSize = 20,
			Size = UDim2.new(1 / #Difficulty.levels, -4, 1, 0),
			LayoutOrder = index,
			Parent = row,
		}, function()
			send(function(options)
				options.danger = level.level
			end)
		end)
	end
	description = Widgets.label({
		Name = "Description",
		TextSize = 15,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 3,
		Parent = panel,
	})
	for index, id in Difficulty.sliderOrder do
		sliderRow(panel, id, 4 + index)
	end
	DangerChoice.render()
end

return DangerChoice
