--!strict
-- Results screen after a run: outcome, survived time, team, "Play again" (= SetReady) and the countdown
-- back to the lobby, plus team level, kills and damage per player from RunSummary (RunStatsService). Shown to the
-- participants in the Ended phase. Since Paket 13 also the Embers, achievements and unlocks of the run (RunRewards).
-- Paket 14: the local player's weapons with their damage and kills (most damage first), and the team, weapons and
-- rewards in a part that scrolls when it does not fit (phones, Widgets.isCompact).
-- B11 part 2: after a defeat with retries left, "Retry wave" (remote RetryWave) starts the lost wave again from its
-- start; such a defeat is only saved (Embers) once the results are over, so the rewards line says so.
-- Paket 15: on the run place "Back to hub" (remote ReturnToHub) next to "Play again".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressRules = require(Shared:WaitForChild("Util"):WaitForChild("ProgressRules"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local UpgradeText = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeText"))

local PartyController = require(script.Parent.PartyController)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local BUTTON_COOLDOWN = 0.3 -- seconds; keeps taps below the server rate limit
local DETAILS_MAX_HEIGHT = 330 -- reference pixels of the team, weapons and rewards part before it scrolls
local DETAILS_MAX_HEIGHT_COMPACT = 150 -- on small screens
local MAX_WEAPON_ROWS = 6

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
local retryButton: TextButton
local hubButton: TextButton
local footerLabel: TextLabel
local lastPress = 0
local summary: Types.RunSummary? = nil
local rewards: Types.RunRewards? = nil -- Paket 13: Embers and achievements of the run that just ended
local rewardsLabel: TextLabel
local card: Frame
local details: ScrollingFrame
local detailsLayout: UIListLayout
local weaponsTitle: TextLabel
local weaponRows: Frame

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

local fitDetails: () -> ()

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

-- The local player's weapons: "Spark Bolt III · 12.3k damage · 140 kills".
local function renderWeapons()
	Widgets.clearRows(weaponRows)
	local mine = summaryOf(Players.LocalPlayer.UserId)
	local weapons = if mine and mine.weapons then mine.weapons else {}
	weaponsTitle.Visible = #weapons > 0
	for index, weapon in weapons do
		if index > MAX_WEAPON_ROWS then
			break
		end
		Widgets.label({
			Name = weapon.id,
			Text = `{UpgradeText.weaponName(weapon.id, weapon.tier, weapon.evolution)} · {compact(weapon.damage)} damage · {weapon.kills} kills`,
			TextSize = 17,
			TextColor3 = if index == 1 then Theme.text else Theme.textDim,
			LayoutOrder = index,
			Parent = weaponRows,
		})
	end
end

-- The details part is as tall as its content, up to a limit; beyond that it scrolls.
fitDetails = function()
	local content = detailsLayout.AbsoluteContentSize
	if not content then
		return
	end
	local uiScale = card:FindFirstChildOfClass("UIScale")
	local scale = if uiScale and uiScale.Scale > 0 then uiScale.Scale else 1
	local limit = if Widgets.isCompact() then DETAILS_MAX_HEIGHT_COMPACT else DETAILS_MAX_HEIGHT
	local height = math.min(content.Y / scale, limit)
	details.Size = UDim2.new(1, 0, 0, height)
	details.CanvasSize = UDim2.fromOffset(0, content.Y / scale)
end

local function canRetry(results: Types.Results): boolean
	if results.outcome ~= "Defeat" or (results.retriesLeft or 0) <= 0 then
		return false
	end
	for _, entry in results.players do
		if entry.userId == Players.LocalPlayer.UserId then
			return true
		end
	end
	return false
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
	local retry = canRetry(results)
	rewardsLabel.Visible = rewards ~= nil or retry
	if not rewards and retry then
		rewardsLabel.Text = "Embers are saved when the results end, unless the wave is retried"
	end
	if rewards then
		local parts = {}
		for _, line in rewards.lines do
			table.insert(parts, `{line.label} +{line.amount}`)
		end
		local text = `+{rewards.embers} EMBERS ({rewards.totalEmbers} total)`
		if #parts > 0 then
			text ..= `\n{table.concat(parts, " · ")}`
		end
		for _, id in rewards.achievements do
			local achievement = ProgressRules.get(id)
			if achievement then
				text ..= `\nAchievement: {achievement.name} (+{achievement.embers})`
			end
		end
		if #rewards.unlocked > 0 then
			text ..= `\nUnlocked: {table.concat(rewards.unlocked, ", ")}`
		end
		rewardsLabel.Text = text
	end

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

	renderWeapons()
	fitDetails()

	local me = RunStateController.getLocalPlayer()
	local ready = me ~= nil and me.ready
	againButton.Text = if ready then "WAITING FOR TEAM - CANCEL" else "PLAY AGAIN"
	againButton.BackgroundColor3 = if ready then Theme.button else Theme.accent
	againButton.TextColor3 = if ready then Theme.text else Theme.accentText
	footerLabel.Text = footerText()
	local party = PartyController.get()
	hubButton.Visible = PartyController.getRole() == "Run"
	hubButton.Text = if party and party.teleporting then "TELEPORTING..." else "BACK TO HUB"
	retryButton.Visible = retry
	if retry then
		local left = results.retriesLeft or 0
		retryButton.Text = `RETRY WAVE {results.wave or ""} ({left} left)`
	end
end

local function build()
	screen = Widgets.screen("Results", 2)

	card = Widgets.panel({
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

	details = Widgets.create("ScrollingFrame", {
		Name = "Details",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		Size = UDim2.new(1, 0, 0, DETAILS_MAX_HEIGHT_COMPACT),
		LayoutOrder = 5,
		Parent = card,
	})
	detailsLayout = Widgets.list(8)
	detailsLayout.Parent = details
	detailsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		fitDetails()
	end)

	teamRows = Widgets.create("Frame", {
		Name = "Team",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 0),
		LayoutOrder = 1,
		Parent = details,
	})
	Widgets.list(4).Parent = teamRows
	weaponsTitle = Widgets.label({
		Name = "WeaponsTitle",
		Text = "YOUR WEAPONS",
		Font = Theme.fontBold,
		TextSize = 16,
		TextColor3 = Theme.textDim,
		Visible = false,
		LayoutOrder = 2,
		Parent = details,
	})
	weaponRows = Widgets.create("Frame", {
		Name = "Weapons",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 0),
		LayoutOrder = 3,
		Parent = details,
	})
	Widgets.list(2).Parent = weaponRows

	againButton = Widgets.button({
		Name = "PlayAgain",
		Text = "PLAY AGAIN",
		TextSize = 26,
		Size = UDim2.fromOffset(360, 64),
		LayoutOrder = 7,
		Parent = card,
	}, function()
		local me = RunStateController.getLocalPlayer()
		local now = os.clock()
		if me and now - lastPress >= BUTTON_COOLDOWN then
			lastPress = now
			Net.fireServer("SetReady", not me.ready)
		end
	end)

	retryButton = Widgets.button({
		Name = "RetryWave",
		Text = "RETRY WAVE",
		TextSize = 22,
		Size = UDim2.fromOffset(360, 52),
		Visible = false,
		LayoutOrder = 6,
		Parent = card,
	}, function()
		local now = os.clock()
		if now - lastPress >= BUTTON_COOLDOWN then
			lastPress = now
			Net.fireServer("RetryWave")
		end
	end)

	hubButton = Widgets.button({
		Name = "BackToHub",
		Text = "BACK TO HUB",
		TextSize = 20,
		Size = UDim2.fromOffset(360, 44),
		Visible = false,
		LayoutOrder = 9,
		Parent = card,
	}, function()
		local now = os.clock()
		if now - lastPress >= BUTTON_COOLDOWN then
			lastPress = now
			Net.fireServer("ReturnToHub")
		end
	end)

	footerLabel = Widgets.label({ TextSize = 16, TextColor3 = Theme.textDim, LayoutOrder = 8, Parent = card })
	rewardsLabel = Widgets.label({
		Name = "Rewards",
		TextColor3 = Theme.accent,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 20),
		Visible = false,
		LayoutOrder = 0, -- the Embers first, so they show without scrolling
		Parent = details,
	})
end

function ResultsController.start()
	build()
	RunStateController.Changed:Connect(render)
	PartyController.Changed:Connect(render)
	Net.onClient("RunSummary", function(received: Types.RunSummary)
		summary = received
		render()
	end)
	Net.onClient("RunRewards", function(received: Types.RunRewards)
		rewards = received
		render()
	end)
	RunStateController.Changed:Connect(function()
		if RunStateController.getView() ~= "Results" then
			rewards = nil -- belongs to the run that just ended
		end
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
