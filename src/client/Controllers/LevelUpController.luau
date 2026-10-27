--!strict
-- Level-up choice (DESIGN.md sections 8 and 13), opened in the shop phase after a wave: three big cards (icon, name, one line of effect, "NEW"/"LV 3") from
-- the server's LevelUpOffer (UpgradeService), a bar running down to the automatic pick and the free reroll. Tap or
-- click a card, or press 1/2/3. Cards ignore input for a moment after they appear, so a thumb on the move stick
-- does not pick one by accident. Sends ChooseUpgrade and RequestReroll; texts from Util/UpgradeText.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local UpgradeText = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeText"))

local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local LevelUp = Config.Run.levelUp
local CARD_SIZE = Vector2.new(210, 220)
local CARD_GAP = 16
local ICON_SIZE = 56
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local KIND_COLOR: { [string]: Color3 } = {
	Weapon = Theme.accent,
	Passive = Theme.success,
	Reward = Theme.gloom,
}

local LevelUpController = {}

local screen: ScreenGui
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local cardRow: Frame
local timerFill: Frame
local rerollButton: TextButton
type CardView = {
	button: TextButton,
	badge: TextLabel,
	icon: Frame,
	letters: TextLabel,
	name: TextLabel,
	detail: TextLabel,
	edge: UIStroke,
}

local cards: { CardView } = {}

local offer: Types.LevelUpOffer? = nil
local shownAt = 0 -- os.clock() when the current cards appeared
local waiting = false -- a pick or reroll was sent, the server has not answered yet

local function isOpen(): boolean
	return offer ~= nil and offer.open and RunStateController.getView() == "Run"
end

local function accepting(): boolean
	return isOpen() and not waiting and os.clock() - shownAt >= LevelUp.inputDelaySeconds
end

local function pick(index: number)
	local current = offer
	local card = current and current.cards[index]
	if not (card and accepting()) then
		return
	end
	waiting = true
	Net.fireServer("ChooseUpgrade", card.id)
end

local function reroll()
	local current = offer
	if not (current and current.rerolls > 0 and accepting()) then
		return
	end
	waiting = true
	Net.fireServer("RequestReroll")
end

local function initials(title: string): string
	local letters = {}
	for word in string.gmatch(title, "%a+") do
		table.insert(letters, string.sub(word, 1, 1))
	end
	return string.upper(table.concat(letters, "", 1, math.min(#letters, 2)))
end

local function buildCard(index: number): CardView
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local button = Widgets.button({
		Name = `Card{index}`,
		Text = "",
		Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
		LayoutOrder = index,
		Parent = cardRow,
	}, function()
		pick(index)
	end)
	Widgets.padding(12).Parent = button
	Widgets.list(6).Parent = button
	local edge = Widgets.create("UIStroke", { Name = "Edge", Color = Theme.stroke, Thickness = 2, Parent = button })
	local badge = Widgets.label({
		Name = "Badge",
		Font = Theme.fontBold,
		TextSize = 16,
		TextColor3 = Theme.accent,
		LayoutOrder = 1,
		Parent = button,
	})
	local icon = Widgets.create("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
		LayoutOrder = 2,
		Parent = button,
	}, { Widgets.corner(UDim.new(0.5, 0)) })
	local letters = Widgets.label({
		Name = "Letters",
		Font = Theme.fontBold,
		TextSize = 24,
		TextColor3 = Theme.accentText,
		Size = UDim2.fromScale(1, 1),
		Parent = icon,
	})
	local name = Widgets.label({
		Name = "CardName",
		Font = Theme.fontBold,
		TextSize = 22,
		LayoutOrder = 3,
		Parent = button,
	})
	local detail = Widgets.label({
		Name = "Detail",
		TextSize = 17,
		TextColor3 = Theme.textDim,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 4,
		Parent = button,
	})
	Widgets.label({
		Name = "Key",
		Text = if touch then "" else `[{index}]`,
		TextSize = 14,
		TextColor3 = Theme.textDim,
		LayoutOrder = 5,
		Parent = button,
	})
	return {
		button = button,
		badge = badge,
		icon = icon,
		letters = letters,
		name = name,
		detail = detail,
		edge = edge,
	}
end

local function renderCards(current: Types.LevelUpOffer)
	for index, view in cards do
		local card = current.cards[index]
		view.button.Visible = card ~= nil
		if card then
			local title, detail, badge = UpgradeText.describe(card)
			local color = KIND_COLOR[card.kind] or Theme.accent
			view.badge.Text = badge
			view.name.Text = title
			view.detail.Text = detail
			view.icon.BackgroundColor3 = color
			view.letters.Text = initials(title)
			view.edge.Color = color
		end
	end
end

local function render()
	if not screen then
		return -- an offer arrived before start() built the UI; start() renders it
	end
	local current = offer
	screen.Enabled = isOpen()
	if not (current and screen.Enabled) then
		return
	end
	titleLabel.Text = `LEVEL {current.level}`
	subtitleLabel.Text = if current.pending > 0 then `Pick one · {current.pending} more waiting` else "Pick one"
	renderCards(current)
	local canReroll = current.rerolls > 0
	rerollButton.Text = if canReroll then `Reroll ({current.rerolls} left)` else "No rerolls left"
	rerollButton.TextColor3 = if canReroll then Theme.text else Theme.textDim
	rerollButton.AutoButtonColor = canReroll
end

local function onOffer(newOffer: Types.LevelUpOffer)
	local previous = offer
	offer = newOffer
	waiting = false
	local changed = previous == nil
		or not previous.open
		or previous.level ~= newOffer.level
		or previous.rerolls ~= newOffer.rerolls
	if newOffer.open and changed then
		shownAt = os.clock()
	end
	render()
end

local function updateTimer()
	local current = offer
	if not (current and screen.Enabled) then
		return
	end
	local remaining = math.max(0, current.expiresAt - workspace:GetServerTimeNow())
	local target = UDim2.fromScale(math.clamp(remaining / LevelUp.autoPickSeconds, 0, 1), 1)
	if timerFill.Size ~= target then
		timerFill.Size = target
	end
end

local function build()
	screen = Widgets.screen("LevelUp", 5)
	local width = LevelUp.cardCount * CARD_SIZE.X + (LevelUp.cardCount - 1) * CARD_GAP
	local panel = Widgets.panel({
		Name = "LevelUp",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width + 28, 0),
		Parent = screen,
	})
	Widgets.list(8).Parent = panel
	titleLabel = Widgets.label({
		Name = "Title",
		Font = Theme.fontBold,
		TextSize = Theme.titleSize,
		TextColor3 = Theme.accent,
		Size = UDim2.new(1, 0, 0, Theme.titleSize + 6),
		LayoutOrder = 1,
		Parent = panel,
	})
	subtitleLabel = Widgets.label({ Name = "Subtitle", LayoutOrder = 2, Parent = panel })
	cardRow = Widgets.create("Frame", {
		Name = "Cards",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, CARD_SIZE.Y),
		LayoutOrder = 3,
		Parent = panel,
	})
	Widgets.list(CARD_GAP, Enum.FillDirection.Horizontal).Parent = cardRow
	for index = 1, LevelUp.cardCount do
		cards[index] = buildCard(index)
	end
	local track = Widgets.create("Frame", {
		Name = "Timer",
		BackgroundColor3 = Theme.button,
		Size = UDim2.new(1, 0, 0, 8),
		LayoutOrder = 4,
		Parent = panel,
	}, { Widgets.corner(UDim.new(0, 4)) })
	timerFill = Widgets.create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.accent,
		Size = UDim2.fromScale(1, 1),
		Parent = track,
	}, { Widgets.corner(UDim.new(0, 4)) })
	rerollButton = Widgets.button({
		Name = "Reroll",
		Size = UDim2.fromOffset(240, 44),
		LayoutOrder = 5,
		Parent = panel,
	}, reroll)
end

local function bindKeys()
	for index, key in KEYS do
		if index > LevelUp.cardCount then
			break
		end
		ContextActionService:BindActionAtPriority(
			`LanternfallCard{index}`,
			function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
				if not isOpen() then
					return Enum.ContextActionResult.Pass
				end
				if state == Enum.UserInputState.Begin then
					pick(index)
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			key
		)
	end
end

-- Lifecycle -------------------------------------------------------------------------

function LevelUpController.init()
	Net.onClient("LevelUpOffer", onOffer)
end

function LevelUpController.start()
	build()
	bindKeys()
	RunStateController.Changed:Connect(render)
	render()
	RunService.Heartbeat:Connect(updateTimer)
end

-- Level-ups waiting for the end of the wave (choices open in the shop phase since B1), 0 while the cards are open.
function LevelUpController.getWaiting(): number
	return if offer and not offer.open then offer.pending else 0
end

-- True while the cards are on screen (the shop panel waits until the choice is done).
function LevelUpController.isOpen(): boolean
	return isOpen()
end

-- The open choice, or nil (smoke test and later tutorials, WP19).
function LevelUpController.getOffer(): Types.LevelUpOffer?
	return if isOpen() then offer else nil
end

return LevelUpController
