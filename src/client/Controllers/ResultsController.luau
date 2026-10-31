--!strict
-- Results screen after a run: outcome, survived time, team, "Play again" (= SetReady) and the countdown
-- back to the lobby, plus team level, kills and damage per player from RunSummary (RunStatsService). Shown to the
-- participants in the Ended phase. WP14 adds embers and the final layout.

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
local statsLabel: TextLabel
local teamRows: Frame
local againButton: TextButton
local footerLabel: TextLabel
local lastPress = 0
local summary: Types.RunSummary? = nil

local function className(classId: string): string
	local class = Config.Classes[classId]
	return if class then class.displayName else classId
end

local function compact(value: number): string
	if value >= 10000 then
		return `{math.round(value / 1000)}k`
	elseif value >= 1000 then
		return string.format("%.1fk", value / 1000)
	end
	return tostring(value)
end

local function summaryOf(userId: number): Types.RunSummaryPlayer?
	for _, entry in if summary then summary.players else {} do
		if entry.userId == userId then
			return entry
		end
	end
	return nil
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
	local reached = if results.wave then ` · wave {results.wave}` else "" -- B11
	timeLabel.Text = `Time {Format.time(results.survivedSeconds)}{reached} · {results.difficulty}`
	statsLabel.Text = if summary then `Team level {summary.teamLevel} · {summary.kills} kills` else ""
	statsLabel.Visible = summary ~= nil

	Widgets.clearRows(teamRows)
	for index, entry in results.players do
		local stats = summaryOf(entry.userId)
		local statsText = if stats
			then ` · {stats.kills} kills · {compact(stats.damageDealt)} damage · took {compact(stats.damageTaken)}`
			else ""
		Widgets.label({
			Text = `{entry.name} · {className(entry.classId)}{statsText}`,
			TextColor3 = Theme.textDim,
			AutomaticSize = Enum.AutomaticSize.Y, -- long stat lines wrap on narrow screens
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
	statsLabel = Widgets.label({ Name = "Stats", TextColor3 = Theme.text, LayoutOrder = 4, Parent = card })

	teamRows = Widgets.create("Frame", {
		Name = "Team",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 5,
		Parent = card,
	})
	Widgets.list(4).Parent = teamRows

	againButton = Widgets.button({
		Name = "PlayAgain",
		Text = "PLAY AGAIN",
		TextSize = 26,
		Size = UDim2.fromOffset(360, 64),
		LayoutOrder = 6,
		Parent = card,
	}, function()
		local me = RunStateController.getLocalPlayer()
		local now = os.clock()
		if me and now - lastPress >= BUTTON_COOLDOWN then
			lastPress = now
			Net.fireServer("SetReady", not me.ready)
		end
	end)

	footerLabel = Widgets.label({ TextSize = 16, TextColor3 = Theme.textDim, LayoutOrder = 7, Parent = card })
end

function ResultsController.start()
	build()
	RunStateController.Changed:Connect(render)
	Net.onClient("RunSummary", function(received: Types.RunSummary)
		summary = received
		render()
	end)
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
