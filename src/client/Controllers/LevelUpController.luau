--!strict
-- Level-up choice (DESIGN.md sections 8 and 13), opened in the shop phase after a wave: four stat cards (icon, stat,
-- "+8% Damage", rarity in its color; Brotato direction since B2) from the server's LevelUpOffer (UpgradeService), a
-- bar running down to the automatic pick and a reroll for Shards. Tap or click a card, or press 1-4. Cards ignore
-- input for a moment after they appear, so a thumb on the move stick does not pick one by accident. Sends
-- ChooseUpgrade and RequestReroll; texts from Util/UpgradeText, Shards from the ShopState remote (ShopService).
-- Since B6 crates open here first, one by one (CrateOffer from UpgradeService): the item's card with "Take" and
-- "Sell (+N Shards)" (keys 1 and 2) and the same bar to the automatic take; sends ChooseCrate.

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
local Dialog = require(script.Parent.Parent.UI.Dialog)

local LevelUp = Config.Run.levelUp
local CARD_SIZE = Vector2.new(210, 268)
local CARD_GAP = 12
local ICON_SIZE = 44
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

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

-- the crate panel (B6)
local levelPanel: Frame
local cratePanel: Frame
local crateSubtitle: TextLabel
local crateCard: CardView
local crateTimerFill: Frame
local sellButton: TextButton
local STAT_COLORS = { plus = Theme.success, minus = Theme.danger }

local offer: Types.LevelUpOffer? = nil
local crate: Types.CrateOffer? = nil
local crateShownAt = 0
local shownAt = 0 -- os.clock() when the current cards appeared
local waiting = false -- a pick or reroll was sent, the server has not answered yet
local shardCount = 0 -- from ShopState, for the reroll button

local function isCrateOpen(): boolean
	return crate ~= nil and crate.open and RunStateController.getView() == "Run"
end

local function isOpen(): boolean
	return (offer ~= nil and offer.open or isCrateOpen()) and RunStateController.getView() == "Run"
end

local function accepting(): boolean
	local since = if isCrateOpen() then crateShownAt else shownAt
	return isOpen() and not waiting and os.clock() - since >= LevelUp.inputDelaySeconds
end

-- Takes (or sells) the open crate's item.
local function chooseCrate(take: boolean)
	if not (isCrateOpen() and accepting()) then
		return
	end
	waiting = true
	Net.fireServer("ChooseCrate", take)
end

local function pick(index: number)
	if isCrateOpen() then
		if index <= 2 then
			chooseCrate(index == 1)
		end
		return
	end
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
	if not (current and accepting() and shardCount >= current.rerollPrice) then
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

local function buildCard(index: number, parent: Instance?, name: string?): CardView
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local button = Widgets.button({
		Name = name or `Card{index}`,
		Text = "",
		Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
		LayoutOrder = index,
		Parent = parent or cardRow,
	}, function()
		if not parent then
			pick(index)
		end
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
		TextSize = 20,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 3,
		Parent = button,
	})
	local detail = Widgets.label({
		Name = "Detail",
		TextSize = 17,
		TextColor3 = Theme.textDim,
		Size = UDim2.new(1, 0, 0, 62),
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
			local title, detail, badge = UpgradeText.card(card)
			local color = Theme.tiers[card.tier] or Theme.accent
			view.badge.Text = string.upper(badge)
			view.badge.TextColor3 = color
			view.name.Text = title
			view.detail.Text = detail
			view.icon.BackgroundColor3 = color
			view.letters.Text = initials(title)
			view.edge.Color = color
		end
	end
end

local function renderCrate(current: Types.CrateOffer)
	local item = Config.Items.byId[current.itemId]
	local title = if item then item.displayName else current.itemId
	local color = Theme.tiers[current.tier] or Theme.accent
	crateSubtitle.Text = if current.pending > 0
		then `Take it or sell it · {current.pending} more waiting`
		else "Take it or sell it"
	crateCard.badge.Text = string.upper(`{UpgradeText.tierName(current.tier)} · x{current.count}`)
	crateCard.badge.TextColor3 = color
	crateCard.name.Text = title
	crateCard.detail.Text = UpgradeText.itemLines(current.itemId, STAT_COLORS)
	crateCard.icon.BackgroundColor3 = color
	crateCard.letters.Text = initials(title)
	crateCard.edge.Color = color
	sellButton.Text = `Sell (+{current.sellPrice} Shards)`
end

local function render()
	if not screen then
		return -- an offer arrived before start() built the UI; start() renders it
	end
	screen.Enabled = isOpen()
	local crateOpen = isCrateOpen()
	cratePanel.Visible = crateOpen
	levelPanel.Visible = not crateOpen
	local currentCrate = crate
	if crateOpen and currentCrate then
		renderCrate(currentCrate)
		return
	end
	local current = offer
	if not (current and screen.Enabled) then
		return
	end
	titleLabel.Text = `LEVEL {current.level}`
	subtitleLabel.Text = if current.pending > 0 then `Pick one · {current.pending} more waiting` else "Pick one"
	renderCards(current)
	local canReroll = shardCount >= current.rerollPrice
	rerollButton.Text = `Reroll ({current.rerollPrice} Shards)`
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
		or previous.rerollPrice ~= newOffer.rerollPrice
	if newOffer.open and changed then
		shownAt = os.clock()
	end
	render()
end

local function onCrate(newCrate: Types.CrateOffer)
	local previous = crate
	crate = newCrate
	waiting = false
	if newCrate.open and not (previous and previous.open and previous.expiresAt == newCrate.expiresAt) then
		crateShownAt = os.clock()
	end
	render()
end

local function updateTimer()
	local current = if isCrateOpen() then crate else offer
	if not (current and screen.Enabled) then
		return
	end
	local fill = if isCrateOpen() then crateTimerFill else timerFill
	local remaining = math.max(0, current.expiresAt - workspace:GetServerTimeNow())
	local target = UDim2.fromScale(math.clamp(remaining / LevelUp.autoPickSeconds, 0, 1), 1)
	if fill.Size ~= target then
		fill.Size = target
	end
end

local function timerBar(parent: Instance, order: number, name: string): Frame
	local track = Widgets.create("Frame", {
		Name = name,
		BackgroundColor3 = Theme.button,
		Size = UDim2.new(1, 0, 0, 8),
		LayoutOrder = order,
		Parent = parent,
	}, { Widgets.corner(UDim.new(0, 4)) })
	return Widgets.create("Frame", {
		Name = `{name}Fill`,
		BackgroundColor3 = Theme.accent,
		Size = UDim2.fromScale(1, 1),
		Parent = track,
	}, { Widgets.corner(UDim.new(0, 4)) })
end

-- The crate panel (B6): title, the item's card, the timer and Take / Sell.
local function buildCrate()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	cratePanel = Widgets.panel({
		Name = "Crate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(2 * CARD_SIZE.X + CARD_GAP + 28, 0),
		Visible = false,
		Parent = screen,
	})
	Widgets.list(8).Parent = cratePanel
	Widgets.label({
		Name = "CrateTitle",
		Text = "CRATE",
		Font = Theme.fontBold,
		TextSize = Theme.titleSize,
		TextColor3 = Theme.accent,
		Size = UDim2.new(1, 0, 0, Theme.titleSize + 6),
		LayoutOrder = 1,
		Parent = cratePanel,
	})
	crateSubtitle = Widgets.label({ Name = "CrateSubtitle", LayoutOrder = 2, Parent = cratePanel })
	crateCard = buildCard(3, cratePanel, "CrateCard")
	crateCard.button.Size = UDim2.fromScale(1, 0)
	crateCard.button.AutomaticSize = Enum.AutomaticSize.Y
	crateCard.button.AutoButtonColor = false
	crateCard.detail.RichText = true
	crateCard.detail.Size = UDim2.new(1, 0, 0, 24)
	crateCard.detail.AutomaticSize = Enum.AutomaticSize.Y
	local key = crateCard.button:FindFirstChild("Key")
	if key and key:IsA("TextLabel") then
		key.Visible = false -- the buttons below carry the keys
	end
	crateTimerFill = timerBar(cratePanel, 4, "CrateTimer")
	local buttons = Widgets.create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 5,
		Parent = cratePanel,
	})
	Widgets.list(CARD_GAP, Enum.FillDirection.Horizontal).Parent = buttons
	Widgets.button({
		Name = "Take",
		Text = if touch then "Take" else "Take [1]",
		Size = UDim2.new(0.5, -CARD_GAP / 2, 0, 48),
		BackgroundColor3 = Theme.accent,
		TextColor3 = Theme.accentText,
		LayoutOrder = 1,
		Parent = buttons,
	}, function()
		chooseCrate(true)
	end)
	sellButton = Widgets.button({
		Name = "Sell",
		Size = UDim2.new(0.5, -CARD_GAP / 2, 0, 48),
		LayoutOrder = 2,
		Parent = buttons,
	}, function()
		chooseCrate(false)
	end)
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
	levelPanel = panel
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
	local grid = Widgets.create("UIGridLayout", {
		CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = cardRow,
	})
	for index = 1, LevelUp.cardCount do
		cards[index] = buildCard(index)
	end
	timerFill = timerBar(panel, 4, "Timer")
	rerollButton = Widgets.button({
		Name = "Reroll",
		Size = UDim2.fromOffset(240, 44),
		LayoutOrder = 5,
		Parent = panel,
	}, reroll)
	buildCrate()
	Dialog.wrap(panel, nil, width + 28)
	Dialog.wrap(cratePanel, nil, 480)
	local function resize()
		local available = panel.Size.X.Offset - 28
		local columns = if available >= 760 then LevelUp.cardCount elseif available >= 300 then 2 else 1
		local rows = math.ceil(LevelUp.cardCount / columns)
		grid.CellSize = UDim2.new(1 / columns, -CARD_GAP * (columns - 1) / columns, 0, CARD_SIZE.Y)
		grid.FillDirectionMaxCells = columns
		cardRow.Size = UDim2.new(1, 0, 0, rows * CARD_SIZE.Y + (rows - 1) * CARD_GAP)
		rerollButton.Size = UDim2.new(1, 0, 0, 48)
	end
	panel:GetPropertyChangedSignal("Size"):Connect(resize)
	resize()
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
	Net.onClient("CrateOffer", onCrate)
	Net.onClient("ShopState", function(shop: Types.ShopState)
		shardCount = shop.shards
		render()
	end)
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
	return if isOpen() and not isCrateOpen() then offer else nil
end

-- The open crate, or nil (B6, tests).
function LevelUpController.getCrate(): Types.CrateOffer?
	return if isCrateOpen() then crate else nil
end

return LevelUpController
