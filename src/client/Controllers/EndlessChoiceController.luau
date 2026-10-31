--!strict
-- "Continue in endless mode?" after the boss wave (playtest after Paket 24): while the run state carries an
-- endlessVote, every participant sees a panel above the shop with CONTINUE and END RUN (remote ChooseEndless), the
-- votes so far and the time left. More "continue" than "stop" goes on, otherwise the run is won (RunFlow).
-- Reads RunStateController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local EndlessChoiceController = {}

local screen: ScreenGui
local statusLabel: TextLabel
local continueButton: TextButton
local stopButton: TextButton
local lastSecond = -1

-- The open vote, if the local player takes part in the run.
local function openVote(): (Types.RunState?, { Types.EndlessVote }?)
	local state = RunStateController.get()
	if not (state and state.phase == "Shop" and state.endlessVote) then
		return nil, nil
	end
	local me = RunStateController.getLocalPlayer()
	if not (me and me.participant) then
		return nil, nil
	end
	return state, state.endlessVote
end

local function render()
	local state, votes = openVote()
	screen.Enabled = votes ~= nil
	if not (state and votes) then
		return
	end
	local me = RunStateController.getLocalPlayer()
	local mine: boolean? = nil
	local continue, stop = 0, 0
	for _, vote in votes do
		if vote.continue then
			continue += 1
		else
			stop += 1
		end
		if me and vote.userId == me.userId then
			mine = vote.continue
		end
	end
	local players = 0
	for _, info in state.players do
		if info.participant then
			players += 1
		end
	end
	local seconds = math.max(0, math.ceil(RunStateController.getPhaseRemaining()))
	lastSecond = seconds
	statusLabel.Text = if players > 1
		then `Continue {continue} · End {stop} · {players - continue - stop} still choosing · {seconds}s`
		else `{seconds}s`
	continueButton.BackgroundColor3 = if mine == true then Theme.accent else Theme.button
	continueButton.TextColor3 = if mine == true then Theme.accentText else Theme.text
	stopButton.BackgroundColor3 = if mine == false then Theme.accent else Theme.button
	stopButton.TextColor3 = if mine == false then Theme.accentText else Theme.text
end

local function build()
	screen = Widgets.screen("EndlessChoice", 6)
	local panel = Widgets.panel({
		Name = "Choice",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 0),
		Parent = screen,
	})
	Widgets.list(10).Parent = panel
	Widgets.label({
		Name = "Title",
		Text = "BOSS DEFEATED!",
		TextSize = 26,
		Font = Theme.fontBold,
		TextColor3 = Theme.accent,
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = 1,
		Parent = panel,
	})
	Widgets.label({
		Name = "Question",
		Text = "The run is won. Keep going in endless mode? Enemies grow stronger every wave and a boss comes every few waves.",
		TextSize = 16,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 2,
		Parent = panel,
	})
	continueButton = Widgets.button({
		Name = "Continue",
		Text = "CONTINUE (ENDLESS)",
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 3,
		Parent = panel,
	}, function()
		Net.fireServer("ChooseEndless", true)
	end)
	stopButton = Widgets.button({
		Name = "Stop",
		Text = "END RUN",
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 4,
		Parent = panel,
	}, function()
		Net.fireServer("ChooseEndless", false)
	end)
	statusLabel = Widgets.label({
		Name = "Status",
		TextSize = 15,
		TextColor3 = Theme.textDim,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 5,
		Parent = panel,
	})
end

function EndlessChoiceController.init()
	build()
end

function EndlessChoiceController.start()
	RunStateController.Changed:Connect(render)
	RunService.Heartbeat:Connect(function()
		if screen.Enabled and math.ceil(RunStateController.getPhaseRemaining()) ~= lastSecond then
			render() -- the seconds left
		end
	end)
	render()
end

-- Tests: whether the choice panel shows.
function EndlessChoiceController.isOpen(): boolean
	return screen.Enabled
end

return EndlessChoiceController
