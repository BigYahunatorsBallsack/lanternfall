--!strict
-- Lobby screen: status line with the countdown, class choice, Ready button and who is ready.
-- Shown while the local player is not in a run. Reads RunStateController; sends SelectClass and SetReady.
-- Paket 15: on the hub PartyController replaces READY and the player list (parties, Play solo, Quick join) and on the
-- run place adds "Back to hub"; it also gives the status line there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local StatMath = require(Shared:WaitForChild("Util"):WaitForChild("StatMath"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local PartyController = require(script.Parent.PartyController)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local BUTTON_COOLDOWN = 0.3 -- seconds; keeps taps below the server rate limit

-- Short names for class bonus stats, e.g. "+20% max HP".
local LobbyController = {}

local screen: ScreenGui
local statusLabel: TextLabel
local readyButton: TextButton
local playerRows: Frame
local classButtons: { [string]: TextButton } = {}
local lastPress = 0

local function canPress(): boolean
	local now = os.clock()
	if now - lastPress < BUTTON_COOLDOWN then
		return false
	end
	lastPress = now
	return true
end

local function className(classId: string): string
	local class = Config.Classes[classId]
	return if class then class.displayName else classId
end

local function bonusText(class: any): string
	local parts = {}
	for _, stat in Config.Stats.order do
		local value = class.stats[stat.id]
		if value and value ~= 0 then
			table.insert(parts, StatMath.format(stat.id, value))
		end
	end
	return table.concat(parts, ", ")
end

local function statusText(state: Types.RunState, me: Types.PlayerInfo?): string
	local placeText = PartyController.statusText() -- Paket 15: hub and run place
	if placeText then
		return placeText
	end
	local ready = me ~= nil and me.ready
	if state.phase == "Lobby" then
		return "Pick a class and press READY"
	elseif state.phase == "Countdown" then
		local seconds = math.ceil(RunStateController.getPhaseRemaining())
		return if ready then `Run starts in {seconds}` else `Run starts in {seconds} - press READY to join`
	elseif state.phase == "Ended" then
		return "Run finished - the next one starts soon"
	end
	local timer = Format.time(RunStateController.getElapsed())
	return if ready
		then `Run in progress ({timer}) - you join the next one`
		else `Run in progress ({timer}) - press READY to join the next one`
end

local function playerLine(info: Types.PlayerInfo): (string, Color3)
	local status, color = "not ready", Theme.textDim
	if info.participant then
		status, color = "in run", Theme.gloom
	elseif info.ready then
		status, color = "READY", Theme.success
	end
	return `{info.name} · {className(info.classId)} · {status}`, color
end

local function renderPlayers(state: Types.RunState)
	Widgets.clearRows(playerRows)
	for index, info in state.players do
		local text, color = playerLine(info)
		Widgets.label({
			Text = text,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = index,
			Parent = playerRows,
		})
	end
end

local function render()
	local state = RunStateController.get()
	screen.Enabled = state ~= nil and RunStateController.getView() == "Lobby"
	if not (state and screen.Enabled) then
		return
	end
	local me = RunStateController.getLocalPlayer()

	for classId, button in classButtons do
		local selected = me ~= nil and me.classId == classId
		button.BackgroundColor3 = if selected then Theme.accent else Theme.button
		button.TextColor3 = if selected then Theme.accentText else Theme.text
	end

	local ready = me ~= nil and me.ready
	readyButton.Visible = not PartyController.isHub() -- Paket 15: the hub starts runs with Play solo / party / quick join
	readyButton.Text = if ready then "CANCEL" else "READY"
	readyButton.BackgroundColor3 = if ready then Theme.button else Theme.success
	readyButton.TextColor3 = if ready then Theme.text else Theme.accentText

	statusLabel.Text = statusText(state, me)
	renderPlayers(state)
	require(script.Parent.CharacterChoice).render() -- B10 lobby extension
	require(script.Parent.DangerChoice).render() -- B11 lobby extension
	require(script.Parent.ProfileCard).render() -- Paket 12 lobby extension
	PartyController.render() -- Paket 15 lobby extension
	require(script.Parent.Parent.UI.LobbyLayout).refresh()
end

local function build()
	screen = Widgets.screen("Lobby", 1)

	-- Status line at the top
	local banner = Widgets.panel({
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(640, 0),
		Parent = screen,
	})
	statusLabel = Widgets.label({ Font = Theme.fontBold, TextSize = 24, Parent = banner })

	-- Class choice and Ready at the bottom
	local card = Widgets.panel({
		Name = "Choose",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(640, 0),
		Parent = screen,
	})
	Widgets.list(12).Parent = card
	Widgets.label({
		Text = "CHOOSE YOUR CLASS",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		LayoutOrder = 1,
		Parent = card,
	})

	local row = Widgets.create("Frame", {
		Name = "Classes",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 84),
		LayoutOrder = 2,
		Parent = card,
	})
	Widgets.list(12, Enum.FillDirection.Horizontal).Parent = row

	local classes = {}
	for _, class in Config.Classes do
		if class.available then
			table.insert(classes, class)
		end
	end
	table.sort(classes, function(a, b)
		return a.displayName < b.displayName
	end)
	for index, class in classes do
		local weapon = Config.Weapons[class.startWeapon]
		local weaponName = if weapon then weapon.displayName else class.startWeapon
		local button = Widgets.button({
			Name = class.id,
			Text = `{class.displayName}\n{weaponName} · {bonusText(class)}`,
			Size = UDim2.fromOffset(290, 84),
			LayoutOrder = index,
			Parent = row,
		}, function()
			local me = RunStateController.getLocalPlayer()
			if me and me.classId ~= class.id and canPress() then
				Net.fireServer("SelectClass", class.id)
			end
		end)
		classButtons[class.id] = button
	end

	readyButton = Widgets.button({
		Name = "Ready",
		Text = "READY",
		TextSize = 26,
		Size = UDim2.fromOffset(320, 60),
		LayoutOrder = 3,
		Parent = card,
	}, function()
		local me = RunStateController.getLocalPlayer()
		if me and canPress() then
			Net.fireServer("SetReady", not me.ready)
		end
	end)

	-- Who is in the server
	local list = Widgets.panel({
		Name = "Players",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(340, 0),
		Parent = screen,
	})
	Widgets.list(4).Parent = list
	local playersTitle = Widgets.label({
		Text = `PLAYERS (max {Config.Run.maxPlayers} per run)`,
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = list,
	})
	playerRows = Widgets.create("Frame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		Parent = list,
	})
	Widgets.list(4).Parent = playerRows
	require(script.Parent.CharacterChoice).mount(card, row, classButtons) -- B10
	list.AnchorPoint = Vector2.new(0, 0) -- keep the player list above the taller B10 choice panel
	list.Position = UDim2.fromOffset(12, 90)
	require(script.Parent.DangerChoice).mount(screen) -- B11
	local record = Widgets.panel({ Name = "Collection", Size = UDim2.fromOffset(640, 0), Parent = screen })
	Widgets.list(12).Parent = record
	require(script.Parent.ProfileCard).mount(record) -- Saved record and persistent progression get their own page.
	PartyController.mountRows(list, playerRows, playersTitle) -- Paket 15
	PartyController.mountActions(card)
	PartyController.mountInvite(screen)
	require(script.Parent.Parent.UI.LobbyLayout).mount(screen, card, list, record, banner)
end

function LobbyController.start()
	build()
	RunStateController.Changed:Connect(render)
	PartyController.Changed:Connect(render)
	render()

	-- Countdown and run timer tick every frame; only touch the label when the text changes.
	RunService.Heartbeat:Connect(function()
		local state = RunStateController.get()
		if state and screen.Enabled then
			local text = statusText(state, RunStateController.getLocalPlayer())
			if statusLabel.Text ~= text then
				statusLabel.Text = text
			end
			PartyController.tick()
		end
	end)
end

return LobbyController
