--!strict
-- Paket 18 lobby window "QUESTS" (DESIGN.md section 11): the three daily quests with progress and Embers, a SWAP button
-- per quest while a swap is left, when new quests come, and the 7 days of the login streak (paid days, the next one,
-- the day-7 cosmetic). Only sends intents (SwapQuest); the server answers with QuestState. Mounted by ProfileCard in
-- the row under STORE / EMBER SHOP; one lobby window at a time (closes the others when it opens).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EmberShopRules = require(Shared:WaitForChild("Util"):WaitForChild("EmberShopRules"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local ROW_HEIGHT = 58
local DAY_SIZE = 64

local QuestController = {}

local state: Types.QuestState? = nil
local window: Frame? = nil
local openButton: TextButton? = nil
local questRows: Frame? = nil
local resetLabel: TextLabel? = nil
local dayLabels: { TextLabel } = {}

function QuestController.get(): Types.QuestState?
	return state
end

function QuestController.isOpen(): boolean
	return window ~= nil and window.Visible
end

local function rewardText(dayNumber: number): string
	local day = Config.Quests.streak.days[dayNumber]
	if day.cosmetic then
		local entry = EmberShopRules.cosmetic(day.cosmetic)
		return if entry then entry.name else day.cosmetic
	end
	return `{day.embers}`
end

local function renderStreak()
	local current = if state then state.streakDay else 0
	for dayNumber, label in dayLabels do
		local paid = dayNumber <= current
		label.Text = `DAY {dayNumber}\n{rewardText(dayNumber)}`
		label.BackgroundColor3 = if paid then Theme.accent else Theme.button
		label.TextColor3 = if paid then Theme.accentText else Theme.text
	end
end

local function renderReset()
	local label = resetLabel
	if not (label and state) then
		return
	end
	local left = state.resetsIn - (workspace:GetServerTimeNow() - state.sentAt)
	label.Text = `New quests in {Format.duration(left)}`
	if left <= 0 then
		label.Text = "New quests are coming"
	end
end

-- Lobby button text, e.g. "QUESTS 1/3".
local function buttonText(): string
	if not state then
		return "QUESTS"
	end
	local done = 0
	for _, quest in state.quests do
		if quest.done then
			done += 1
		end
	end
	return `QUESTS {done}/{#state.quests}`
end

function QuestController.render()
	if openButton then
		openButton.Text = buttonText()
	end
	local container = questRows
	if not container then
		return
	end
	Widgets.clearRows(container)
	if not state then
		Widgets.label({ Text = "Loading your quests...", TextSize = 15, LayoutOrder = 1, Parent = container })
		return
	end
	local current = state
	for index, quest in current.quests do
		local row = Widgets.create("Frame", {
			Name = `Quest_{index}`,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = container,
		})
		local canSwap = not quest.done and current.swapsLeft > 0
		Widgets.label({
			Name = "Text",
			Text = `{quest.text}\n{if quest.done then "DONE" else `{quest.progress}/{quest.goal}`} · +{quest.embers} Embers`,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if quest.done then Theme.success else Theme.text,
			Size = UDim2.new(1, if canSwap then -96 else 0, 0, ROW_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = row,
		})
		if canSwap then
			Widgets.button({
				Name = "Swap",
				Text = "SWAP",
				TextSize = 14,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(88, 44),
				Parent = row,
			}, function()
				Net.fireServer("SwapQuest", index)
			end)
		end
	end
	Widgets.label({
		Name = "Swaps",
		Text = if current.swapsLeft > 0
			then `{current.swapsLeft} swap left today (only quests that are not done)`
			else "No swaps left today",
		TextSize = 13,
		TextColor3 = Theme.textDim,
		LayoutOrder = #current.quests + 1,
		Parent = container,
	})
	renderReset()
	renderStreak()
end

-- One lobby window at a time: opening this closes the others.
function QuestController.setOpen(open: boolean)
	if not window then
		return
	end
	if open then
		require(script.Parent.ProfileCard).closeWindows()
	end
	window.Visible = open
	if open then
		QuestController.render()
	end
end

-- Adds the QUESTS button to `row` (ProfileCard's second button row) and builds the hidden window on `screen`.
function QuestController.mount(row: Frame, screen: Instance)
	openButton = Widgets.button({
		Name = "OpenQuests",
		Text = "QUESTS",
		TextSize = 16,
		Size = UDim2.new(0.5, -3, 1, 0),
		LayoutOrder = 1,
		Parent = row,
	}, function()
		QuestController.setOpen(not QuestController.isOpen())
	end)

	local panel = Widgets.panel({
		Name = "Quests",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 0),
		Visible = false,
		ZIndex = 5,
		Parent = screen,
	})
	window = panel
	Widgets.list(8).Parent = panel
	Widgets.label({
		Text = "DAILY QUESTS",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		LayoutOrder = 1,
		Parent = panel,
	})
	resetLabel = Widgets.label({
		Name = "QuestReset",
		TextSize = 14,
		TextColor3 = Theme.accent,
		LayoutOrder = 2,
		Parent = panel,
	})
	local list = Widgets.create("Frame", {
		Name = "QuestRows",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 3,
		Parent = panel,
	})
	questRows = list
	Widgets.list(6).Parent = list
	Widgets.label({
		Text = "LOGIN STREAK",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		LayoutOrder = 4,
		Parent = panel,
	})
	local days = Widgets.create("Frame", {
		Name = "StreakDays",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, DAY_SIZE),
		LayoutOrder = 5,
		Parent = panel,
	})
	Widgets.list(4, Enum.FillDirection.Horizontal).Parent = days
	local count = #Config.Quests.streak.days
	for dayNumber = 1, count do
		local label = Widgets.label({
			Name = `Day_{dayNumber}`,
			TextSize = 11,
			TextWrapped = true,
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.button,
			Size = UDim2.new(1 / count, -4, 1, 0),
			LayoutOrder = dayNumber,
			Parent = days,
		})
		Widgets.corner().Parent = label
		dayLabels[dayNumber] = label
	end
	Widgets.label({
		Text = `Embers on the first visit of each day, day {count}: a lantern. A missed day only goes back `
			.. `{Config.Quests.streak.missedPenalty} days.`,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = Theme.textDim,
		Size = UDim2.new(1, 0, 0, 34),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 6,
		Parent = panel,
	})
	Widgets.button({
		Name = "CloseQuests",
		Text = "CLOSE",
		TextSize = 18,
		Size = UDim2.fromOffset(200, 44),
		LayoutOrder = 7,
		Parent = panel,
	}, function()
		QuestController.setOpen(false)
	end)
	QuestController.render()
end

function QuestController.init()
	Net.onClient("QuestState", function(payload: Types.QuestState)
		state = payload
		QuestController.render()
	end)
end

function QuestController.start()
	while true do
		task.wait(1)
		if QuestController.isOpen() then
			renderReset()
		end
	end
end

return QuestController
