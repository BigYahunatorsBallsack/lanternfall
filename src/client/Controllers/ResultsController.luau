--!strict
-- Results screen after a run: outcome, survived time, team, "Play again" (= SetReady) and the countdown
-- back to the lobby. Shown to the participants in the Ended phase. WP14 adds kills, damage and embers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local BUTTON_COOLDOWN = 0.3 -- seconds; keeps taps below the server rate limit

local OUTCOME_TEXT: { [string]: { title: string, subtitle: string } } = {
	Victory = { title = "VICTORY", subtitle = "The lanterns held until dawn" },
	Defeat = { title = "DEFEAT", subtitle = "The gloom took everyone" },
	Abandoned = { title = "RUN ENDED", subtitle = "Everyone left the run" },
}

local ResultsController = {}

local screen: ScreenGui
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local timeLabel: TextLabel
local teamRows: Frame
local againButton: TextButton
local footerLabel: TextLabel
local lastPress = 0

local function className(classId: string): string
	local class = Config.Classes[classId]
	return if class then class.displayName else classId
end

local function footerText(): string
	return `Back to the lobby in {math.ceil(RunStateController.getPhaseRemaining())}`
end

local function render()
	local state = RunStateController.get()
	screen.Enabled = state ~= nil and RunStateController.getView() == "Results"
	if not (state and screen.Enabled) then
		return
	end
	local results: Types.Results? = state.results
	if not results then
		return
	end

	local text = OUTCOME_TEXT[results.outcome] or OUTCOME_TEXT.Defeat
	titleLabel.Text = text.title
	titleLabel.TextColor3 = if results.outcome == "Victory" then Theme.accent else Theme.gloom
	subtitleLabel.Text = text.subtitle
	timeLabel.Text = `Time {Format.time(results.survivedSeconds)} · {results.difficulty}`

	Widgets.clearRows(teamRows)
	for index, entry in results.players do
		Widgets.label({
			Text = `{entry.name} · {className(entry.classId)}`,
			TextColor3 = Theme.textDim,
			LayoutOrder = index,
			Parent = teamRows,
		})
	end

	local me = RunStateController.getLocalPlayer()
	local ready = me ~= nil and me.ready
	againButton.Text = if ready then "WAITING FOR TEAM - CANCEL" else "PLAY AGAIN"
	againButton.BackgroundColor3 = if ready then Theme.button else Theme.accent
	againButton.TextColor3 = if ready then Theme.text else Theme.accentText
	footerLabel.Text = footerText()
end

local function build()
	screen = Widgets.screen("Results", 2)

	local card = Widgets.panel({
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 0),
		Parent = screen,
	})
	Widgets.list(10).Parent = card

	titleLabel = Widgets.label({
		Font = Theme.fontBold,
		TextSize = 48,
		Size = UDim2.new(1, 0, 0, 54),
		LayoutOrder = 1,
		Parent = card,
	})
	subtitleLabel = Widgets.label({ TextColor3 = Theme.textDim, LayoutOrder = 2, Parent = card })
	timeLabel = Widgets.label({ Font = Theme.fontBold, TextSize = 26, LayoutOrder = 3, Parent = card })

	teamRows = Widgets.create("Frame", {
		Name = "Team",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 4,
		Parent = card,
	})
	Widgets.list(4).Parent = teamRows

	againButton = Widgets.button({
		Name = "PlayAgain",
		Text = "PLAY AGAIN",
		TextSize = 26,
		Size = UDim2.fromOffset(360, 64),
		LayoutOrder = 5,
		Parent = card,
	}, function()
		local me = RunStateController.getLocalPlayer()
		local now = os.clock()
		if me and now - lastPress >= BUTTON_COOLDOWN then
			lastPress = now
			Net.fireServer("SetReady", not me.ready)
		end
	end)

	footerLabel = Widgets.label({ TextSize = 16, TextColor3 = Theme.textDim, LayoutOrder = 6, Parent = card })
end

function ResultsController.start()
	build()
	RunStateController.Changed:Connect(render)
	render()

	RunService.Heartbeat:Connect(function()
		if screen.Enabled then
			local text = footerText()
			if footerLabel.Text ~= text then
				footerLabel.Text = text
			end
		end
	end)
end

return ResultsController
