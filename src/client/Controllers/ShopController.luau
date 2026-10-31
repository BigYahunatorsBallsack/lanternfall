--!strict
-- Shards and the shop between waves (DESIGN.md sections 3 and 13, Brotato direction since B1, complete since B3). A
-- small Shards counter next to the timer during the whole run. Between waves an opaque backdrop hides the arena (below
-- the HUD; combat panels hide between waves) with "WAVE n CLEARED"; once the level-up cards are done
-- (LevelUpController), the shop panel: up to four offers (weapons: name with tier, effect, merge hint; items: name,
-- stat lines in green and red; rarity in its color; price) each with a Lock button, the player's weapons (tap one to
-- sell or merge it), a reroll with its price (or free) and READY. The unscaled panel scrolls with fixed footer actions; on small screens
-- (phones) it gets a compact layout and the stat panel moves behind a STATS button. Everything comes from the
-- server's ShopState (ShopService); sends BuyShopOffer, LockShopOffer, RerollShop, SellWeapon, MergeWeapons and
-- SetShopReady. The stats sit next to it (StatsController). Since Paket 14 each weapon field has a tooltip with the
-- weapon's real damage, scaling and stats (UI/Tooltip; LoadoutController has the effective stats). Paket 16: next to
-- the reroll a bonus reroll button (StoreController: VIP reroll, reroll tokens or the reroll pack).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local RunSchedule = require(Shared:WaitForChild("Util"):WaitForChild("RunSchedule"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local UpgradeText = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeText"))

local LevelUpController = require(script.Parent.LevelUpController)
local LoadoutController = require(script.Parent.LoadoutController)
local RunStateController = require(script.Parent.RunStateController)
local StatsController = require(script.Parent.StatsController)
local StoreController = require(script.Parent.StoreController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Tooltip = require(script.Parent.Parent.UI.Tooltip)
local TooltipText = require(Shared:WaitForChild("Util"):WaitForChild("TooltipText"))
local Widgets = require(script.Parent.Parent.UI.Widgets)

local CARD_WIDTH = 200
local CARD_HEIGHT = { normal = 254, compact = 210 } -- the buy button; the lock button sits below it
local DETAIL_HEIGHT = { normal = 116, compact = 76 }
local LOCK_HEIGHT = 44
local CHIP_SIZE = Vector2.new(126, 52)
local GAP = 10
local HEADER_HEIGHT = 34
local WEAPONS_TITLE_HEIGHT = 20
local ACTION_HEIGHT = 44
local BUTTON_HEIGHT = 46
local PADDING = 14
-- Screen space the shop leaves free: the HUD's top bar (timer, XP, Shards) and a margin at the bottom and sides.
local TOP_RESERVE = 76 -- pixels for the wave and currency header
local MARGIN = 8

local SHARDS_COLOR = Theme.shards -- teal: Shards, not XP and not Embers
local BACKDROP_COLOR = Theme.canvas -- the screen between waves, darker than the panels
local LOCKED_COLOR = Color3.fromRGB(110, 170, 255)
local STAT_COLORS = { plus = Theme.success, minus = Theme.danger }

local MAX_WEAPON_SLOTS = Config.Player.maxWeapons
for _, class in Config.Classes do
	MAX_WEAPON_SLOTS = math.max(MAX_WEAPON_SLOTS, class.maxWeapons or 0)
end
local ShopController = {}

local screen: ScreenGui
local backdrop: ScreenGui
local backdropTitle: TextLabel
local backdropHint: TextLabel
local shardsLabel: TextLabel
local panel: Frame
local panelScale: UIScale
local shopScroll: ScrollingFrame
local footer: Frame
local footerButtons: Frame
local actionsRow: Frame
local shardsPanel: Frame
local header: Frame
local subtitleLabel: TextLabel
local cardRow: Frame
local weaponsTitle: TextLabel
local chipRow: Frame
local actionHint: TextLabel
local sellButton: TextButton
local mergeButton: TextButton
local rerollButton: TextButton
local statsButton: TextButton
local readyButton: TextButton
local backButton: TextButton

type CardView = {
	frame: Frame,
	button: TextButton,
	badge: TextLabel,
	name: TextLabel,
	detail: TextLabel,
	detailArea: ScrollingFrame,
	price: TextLabel,
	edge: UIStroke,
	lock: TextButton,
}

type ChipView = {
	button: TextButton,
	name: TextLabel,
	info: TextLabel,
	edge: UIStroke,
}

local cards: { CardView } = {}
local chips: { ChipView } = {}
local shop: Types.ShopState? = nil
local selectedUid: number? = nil
local compact = false
local showingStats = false -- compact layout: the stat panel is shown instead of the shop

local function localInfo(): Types.PlayerInfo?
	return RunStateController.getLocalPlayer()
end

local function isShopping(): boolean
	local state = RunStateController.get()
	return shop ~= nil
		and shop.open
		and state ~= nil
		and state.phase == "Shop"
		and RunStateController.getView() == "Run"
		and not LevelUpController.isOpen()
end

local function selectedWeapon(current: Types.ShopState): Types.ShopWeapon?
	for _, weapon in current.weapons do
		if weapon.uid == selectedUid then
			return weapon
		end
	end
	return nil
end

-- Commands sent to the server ----------------------------------------------------------

local function buy(index: number)
	local current = shop
	local offer = current and current.offers[index]
	if not (current and offer and isShopping()) or offer.sold then
		return
	end
	Net.fireServer("BuyShopOffer", offer.id)
end

local function toggleLock(index: number)
	local current = shop
	local offer = current and current.offers[index]
	if not (current and offer and isShopping()) or offer.sold then
		return
	end
	Net.fireServer("LockShopOffer", offer.id, not offer.locked)
end

local function reroll()
	if isShopping() then
		Net.fireServer("RerollShop")
	end
end

local function sell()
	local current = shop
	local weapon = current and selectedWeapon(current)
	if weapon and isShopping() then
		Net.fireServer("SellWeapon", weapon.uid)
		selectedUid = nil
	end
end

local function merge()
	local current = shop
	local weapon = current and selectedWeapon(current)
	if weapon and weapon.canMerge and isShopping() then
		Net.fireServer("MergeWeapons", weapon.uid)
	end
end

local function toggleReady()
	local info = localInfo()
	if isShopping() and info then
		Net.fireServer("SetShopReady", not info.shopReady)
	end
end

local render: () -> ()

local function selectChip(index: number)
	local current = shop
	local weapon = current and current.weapons[index]
	if not weapon then
		return
	end
	selectedUid = if selectedUid == weapon.uid then nil else weapon.uid
	render()
end

local function setShowingStats(value: boolean)
	showingStats = value
	render()
end

-- Layout --------------------------------------------------------------------------------

local function cardHeight(): number
	return (if compact then CARD_HEIGHT.compact else CARD_HEIGHT.normal) + GAP / 2 + LOCK_HEIGHT
end

-- The shop uses real pixels and scrolling, never a tiny scaled four-card strip.
local function screenArea(): Vector2
	local size = screen and screen.AbsoluteSize
	if typeof(size) == "Vector2" and size.X > 0 and size.Y > 0 then
		return size
	end
	return if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
end
local function applyLayout()
	local area = screenArea()
	compact = area.X < 1000 or area.Y < 600
	local reserved = if compact then 0 else StatsController.reservedWidth()
	local width = math.min(1120, area.X - reserved - 2 * MARGIN)
	local columns = if compact then (if width < 340 then 1 else 2) else Config.Shop.slots
	local cardWidth = (width - 2 * PADDING - (columns - 1) * GAP) / columns
	local cardRows = math.ceil(Config.Shop.slots / columns)
	local perRow = math.max(1, math.floor((width - 2 * PADDING + GAP) / (CHIP_SIZE.X + GAP)))
	local chipRows = math.max(1, math.ceil((if shop then #shop.weapons else 0) / perRow))
	local footerHeight = if compact then 2 * BUTTON_HEIGHT + GAP else BUTTON_HEIGHT
	local actionsHeight = if compact then 3 * ACTION_HEIGHT + 2 * GAP else ACTION_HEIGHT
	local contentHeight = HEADER_HEIGHT
		+ cardRows * cardHeight()
		+ (cardRows - 1) * GAP
		+ WEAPONS_TITLE_HEIGHT
		+ chipRows * (CHIP_SIZE.Y + GAP)
		+ actionsHeight
		+ 5 * GAP
		+ 2 * PADDING
	panelScale.Scale = 1
	panel.Size = UDim2.fromOffset(width, contentHeight)
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.new()
	shopScroll.Position = UDim2.fromOffset(MARGIN, TOP_RESERVE)
	shopScroll.Size = UDim2.new(0, width + 6, 1, -TOP_RESERVE - footerHeight - 24)
	shopScroll.CanvasSize = UDim2.fromOffset(0, contentHeight)
	footer.Position = UDim2.new(0, MARGIN, 1, -footerHeight - 12)
	footer.Size = UDim2.fromOffset(width, footerHeight)
	local footerGrid = footerButtons:FindFirstChildOfClass("UIGridLayout")
	footerGrid.CellSize = UDim2.new(if compact then 0.5 else 1 / 3, -GAP, 0, BUTTON_HEIGHT)
	local cardGrid = cardRow:FindFirstChildOfClass("UIGridLayout")
	cardGrid.CellSize = UDim2.fromOffset(cardWidth, cardHeight())
	cardRow.Size = UDim2.new(1, 0, 0, cardRows * cardHeight() + (cardRows - 1) * GAP)
	for _, view in cards do
		view.button.Size = UDim2.fromOffset(cardWidth, if compact then CARD_HEIGHT.compact else CARD_HEIGHT.normal)
		view.lock.Size = UDim2.fromOffset(cardWidth, LOCK_HEIGHT)
		view.detailArea.Size = UDim2.new(1, 0, 0, if compact then DETAIL_HEIGHT.compact else DETAIL_HEIGHT.normal)
		view.detail.TextSize = if compact then 15 else 17
	end
	local actionsGrid = actionsRow:FindFirstChildOfClass("UIGridLayout")
	actionsGrid.CellSize = UDim2.new(if compact then 1 else 1 / 3, -GAP, 0, ACTION_HEIGHT)
	actionsRow.Size = UDim2.new(1, 0, 0, actionsHeight)
	statsButton.Visible = compact
	header.Visible = true
	weaponsTitle.Visible = true
	footer.Visible = panel.Visible
	shardsPanel.AnchorPoint = Vector2.new(0, 0)
	local state = RunStateController.get()
	local betweenWaves = state and state.phase == "Shop"
	shardsPanel.Position = UDim2.fromOffset(12, if betweenWaves then 12 elseif area.X < 700 then 176 else 68)
end

-- Rendering -----------------------------------------------------------------------------

local function renderCards(current: Types.ShopState)
	for index, view in cards do
		local offer = current.offers[index]
		view.frame.Visible = offer ~= nil
		if offer then
			local title, detail, badge = UpgradeText.offer(offer, STAT_COLORS)
			local color = Theme.tiers[offer.tier] or Theme.accent
			local affordable = current.shards >= offer.price and not offer.blocked
			view.badge.Text = if offer.sold then "SOLD" else string.upper(badge)
			view.badge.TextColor3 = color
			view.name.Text = title
			view.detail.Text = detail
			view.price.Text = if offer.sold then "" else `BUY · {offer.price} Shards`
			view.price.TextColor3 = if affordable then SHARDS_COLOR else Theme.danger
			view.edge.Color = if offer.sold then Theme.stroke elseif offer.locked then LOCKED_COLOR else color
			view.edge.Thickness = if offer.locked then 3 else 2
			view.button.AutoButtonColor = not offer.sold and affordable
			view.button.BackgroundTransparency = if offer.sold then 0.6 else 0
			view.lock.Visible = not offer.sold
			view.lock.Text = if offer.locked then "LOCKED" else "Lock"
			view.lock.BackgroundColor3 = if offer.locked then LOCKED_COLOR else Theme.button
			view.lock.TextColor3 = if offer.locked then Theme.accentText else Theme.textDim
		end
	end
end

local function renderWeapons(current: Types.ShopState)
	weaponsTitle.Text = `WEAPONS {#current.weapons}/{current.maxWeapons}`
	if not selectedWeapon(current) then
		selectedUid = nil
	end
	for index, view in chips do
		local weapon = current.weapons[index]
		view.button.Visible = weapon ~= nil
		if weapon then
			local selected = weapon.uid == selectedUid
			local color = Theme.tiers[weapon.tier] or Theme.accent
			view.name.Text = UpgradeText.weaponName(weapon.id, weapon.tier, weapon.evolution)
			view.name.TextColor3 = color
			view.info.Text = if weapon.canMerge then "can merge" else ""
			view.edge.Color = if selected then Theme.accent else color
			view.edge.Thickness = if selected then 3 else 1.5
		end
	end
	local weapon = selectedWeapon(current)
	sellButton.Visible = weapon ~= nil
	mergeButton.Visible = weapon ~= nil and weapon.canMerge
	if weapon then
		actionHint.Text = UpgradeText.weaponName(weapon.id, weapon.tier, weapon.evolution)
		actionHint.TextColor3 = Theme.text
		sellButton.Text = `Sell (+{weapon.sellPrice})`
		mergeButton.Text = `Merge → {Format.tier(weapon.tier + 1)}`
	else
		actionHint.Text = if compact
			then `Weapons {#current.weapons}/{current.maxWeapons} · tap one to sell or merge`
			else "Tap a weapon to sell or merge it"
		actionHint.TextColor3 = Theme.textDim
	end
end

local function renderButtons(current: Types.ShopState)
	local free = current.freeRerolls > 0
	local canReroll = free or current.shards >= current.rerollPrice
	rerollButton.Text = if free
		then `Reroll (free{if current.freeRerolls > 1 then ` x{current.freeRerolls}` else ""})`
		else `Reroll ({current.rerollPrice} Shards)`
	rerollButton.TextColor3 = if free then SHARDS_COLOR elseif canReroll then Theme.text else Theme.textDim
	rerollButton.AutoButtonColor = canReroll
	local info = localInfo()
	local ready = info ~= nil and info.shopReady == true
	readyButton.Text = if ready then "WAITING… (tap to shop)" else "READY"
	readyButton.BackgroundColor3 = if ready then Theme.button else Theme.accent
	readyButton.TextColor3 = if ready then Theme.text else Theme.accentText
end

function render()
	if not screen then
		return
	end
	local current = shop
	local state = RunStateController.get()
	local inRun = RunStateController.getView() == "Run" and current ~= nil
	screen.Enabled = inRun
	backdrop.Enabled = RunStateController.getView() == "Run" and state ~= nil and state.phase == "Shop"
	if backdrop.Enabled and state then
		backdropTitle.Text = `WAVE {state.wave} CLEARED`
		backdropHint.Text = if LevelUpController.isOpen() then "Pick your level-ups" else "Spend your Shards"
	end
	shardsLabel.Text = `{if current then current.shards else 0} Shards`
	local shopping = isShopping()
	if not shopping then
		showingStats = false
	end
	applyLayout()
	local statsInstead = shopping and compact and showingStats
	panel.Visible = shopping and not statsInstead
	shopScroll.Visible = panel.Visible
	footer.Visible = panel.Visible
	backButton.Visible = statsInstead
	StatsController.setSuppressed(shopping and compact and not showingStats)
	if not (current and shopping) then
		return
	end
	renderCards(current)
	renderWeapons(current)
	renderButtons(current)
end

local function updateSubtitle()
	if not (panel and panel.Visible) then
		return
	end
	local state = RunStateController.get()
	local left = math.ceil(RunStateController.getPhaseRemaining())
	local text =
		`SHOP · Wave {if state then state.wave else 0}/{RunSchedule.waveCount()} cleared · next wave in {left}`
	if subtitleLabel.Text ~= text then
		subtitleLabel.Text = text
	end
end

-- Building --------------------------------------------------------------------------------

local function buildCard(index: number): CardView
	local frame = Widgets.create("Frame", {
		Name = `Card{index}`,
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Parent = cardRow,
	})
	Widgets.list(GAP / 2).Parent = frame
	local button = Widgets.button({
		Name = `Offer{index}`,
		Text = "",
		LayoutOrder = 1,
		Parent = frame,
	}, function()
		buy(index)
	end)
	Widgets.padding(10).Parent = button
	Widgets.list(4).Parent = button
	local edge = Widgets.create("UIStroke", { Name = "Edge", Color = Theme.stroke, Thickness = 2, Parent = button })
	local badge = Widgets.label({
		Name = "Badge",
		Font = Theme.fontBold,
		TextSize = 14,
		TextColor3 = Theme.accent,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = button,
	})
	local name = Widgets.label({
		Name = "OfferName",
		Font = Theme.fontBold,
		TextSize = 19,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = 2,
		Parent = button,
	})
	-- Long effects scroll inside the card while the price and lock action remain reachable.
	local detailArea = Widgets.create("ScrollingFrame", {
		Name = "EffectDetails",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		LayoutOrder = 3,
		Parent = button,
	})
	local detail = Widgets.label({
		Name = "Detail",
		TextSize = 15,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -6, 0, 0),
		TextColor3 = Theme.textDim,
		RichText = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 3,
		Parent = detailArea,
	})
	local price = Widgets.label({
		Name = "Price",
		Font = Theme.fontBold,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = SHARDS_COLOR,
		LayoutOrder = 4,
		Parent = button,
	})
	local lock = Widgets.button({
		Name = `Lock{index}`,
		Text = "Lock",
		TextSize = 15,
		Size = UDim2.fromOffset(CARD_WIDTH, LOCK_HEIGHT),
		LayoutOrder = 2,
		Parent = frame,
	}, function()
		toggleLock(index)
	end)
	return {
		frame = frame,
		button = button,
		badge = badge,
		name = name,
		detail = detail,
		detailArea = detailArea,
		price = price,
		edge = edge,
		lock = lock,
	}
end

local function buildChip(index: number): ChipView
	local button = Widgets.button({
		Name = `Weapon{index}`,
		Text = "",
		Size = UDim2.fromOffset(CHIP_SIZE.X, CHIP_SIZE.Y),
		LayoutOrder = index,
		Parent = chipRow,
	}, function()
		selectChip(index)
	end)
	local edge = Widgets.create("UIStroke", { Name = "Edge", Color = Theme.stroke, Thickness = 1.5, Parent = button })
	Widgets.padding(4).Parent = button
	Widgets.list(0).Parent = button
	local name = Widgets.label({
		Name = "WeaponName",
		Font = Theme.fontBold,
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
		Parent = button,
	})
	local info = Widgets.label({
		Name = "Info",
		TextSize = 13,
		TextColor3 = SHARDS_COLOR,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 2,
		Parent = button,
	})
	Tooltip.attach(button, function()
		local weapon = shop and shop.weapons[index]
		local loadout = LoadoutController.getLocal()
		for _, info in if weapon and loadout then loadout.weapons else {} do
			if weapon and info.uid == weapon.uid then
				return TooltipText.weapon(info)
			end
		end
		return nil, nil
	end)
	return { button = button, name = name, info = info, edge = edge }
end

local function row(name: string, height: number, order: number, parent: Instance): Frame
	local frame = Widgets.create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order,
		Parent = parent,
	})
	Widgets.list(GAP, Enum.FillDirection.Horizontal).Parent = frame
	return frame
end

local function build()
	-- Between the 3D arena and the HUD (DisplayOrder 0): the shop and the level-up cards are a screen of their own.
	backdrop = Widgets.screen("Backdrop", -1)
	backdrop.IgnoreGuiInset = true
	local cover = Widgets.create("Frame", {
		Name = "Cover",
		BackgroundColor3 = BACKDROP_COLOR,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = backdrop,
	})
	Widgets.create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(BACKDROP_COLOR, Theme.panel),
		Parent = cover,
	})
	local banner = Widgets.panel({
		Name = "Header",
		Visible = false, -- The shop owns its header; choices have their own modal title.
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.17),
		Size = UDim2.fromOffset(600, 0),
		Parent = cover,
	})
	Widgets.list(2).Parent = banner
	backdropTitle = Widgets.label({
		Name = "Title",
		Font = Theme.fontBold,
		TextSize = 40,
		TextColor3 = Theme.accent,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 1,
		Parent = banner,
	})
	backdropHint = Widgets.label({ Name = "Hint", TextColor3 = Theme.textDim, LayoutOrder = 2, Parent = banner })

	screen = Widgets.screen("Shop", 4)
	local shards = Widgets.panel({
		Name = "Shards",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -222, 0, 8),
		Size = UDim2.fromOffset(150, 0),
		Parent = screen,
	})
	shardsPanel = shards
	Widgets.unscaled(shards)
	shardsLabel = Widgets.label({
		Name = "ShardsText",
		Font = Theme.fontBold,
		TextColor3 = SHARDS_COLOR,
		Text = "0 Shards",
		Parent = shards,
	})

	shopScroll = Widgets.create("ScrollingFrame", {
		Name = "ShopContent",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.stroke,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = screen,
	})
	footer = Widgets.create(
		"Frame",
		{ Name = "ShopFooter", BackgroundColor3 = Theme.panel, BorderSizePixel = 0, Parent = screen }
	)
	-- Own scale instead of Widgets.panel's: the shop fits itself to the free screen space (applyLayout).
	panelScale = Widgets.create("UIScale", { Scale = 1 })
	panel = Widgets.create("Frame", {
		Name = "Shop",
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = Theme.panelTransparency,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		Parent = shopScroll,
	}, {
		panelScale,
		Widgets.corner(),
		Widgets.padding(PADDING),
		Widgets.create("UIStroke", { Color = Theme.stroke, Thickness = 1.5 }),
	})
	Widgets.list(GAP).Parent = panel

	header = row("HeaderRow", HEADER_HEIGHT, 1, panel)
	subtitleLabel = Widgets.label({
		Name = "Subtitle",
		Font = Theme.fontBold,
		TextColor3 = Theme.accent,
		Size = UDim2.fromScale(1, 1),
		Parent = header,
	})

	cardRow = row("Offers", 0, 2, panel)
	cardRow:FindFirstChildOfClass("UIListLayout"):Destroy()
	Widgets.create(
		"UIGridLayout",
		{ CellPadding = UDim2.fromOffset(GAP, GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = cardRow }
	)
	for index = 1, Config.Shop.slots do
		cards[index] = buildCard(index)
	end

	weaponsTitle = Widgets.label({
		Name = "WeaponsTitle",
		Font = Theme.fontBold,
		TextSize = 15,
		TextColor3 = Theme.textDim,
		Size = UDim2.new(1, 0, 0, WEAPONS_TITLE_HEIGHT),
		LayoutOrder = 3,
		Parent = panel,
	})
	chipRow = Widgets.create("Frame", {
		Name = "Weapons",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, CHIP_SIZE.Y),
		LayoutOrder = 4,
		Parent = panel,
	})
	Widgets.create("UIGridLayout", {
		CellSize = UDim2.fromOffset(CHIP_SIZE.X, CHIP_SIZE.Y),
		CellPadding = UDim2.fromOffset(GAP, GAP),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = chipRow,
	})
	for index = 1, MAX_WEAPON_SLOTS do
		chips[index] = buildChip(index)
	end

	local actions = row("Actions", ACTION_HEIGHT, 5, panel)
	actionsRow = actions
	actions:FindFirstChildOfClass("UIListLayout"):Destroy()
	Widgets.create(
		"UIGridLayout",
		{ CellPadding = UDim2.fromOffset(GAP, GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = actions }
	)
	actionHint = Widgets.label({
		Name = "ActionHint",
		TextSize = 16,
		Size = UDim2.fromOffset(280, ACTION_HEIGHT),
		LayoutOrder = 1,
		Parent = actions,
	})
	mergeButton = Widgets.button({
		Name = "Merge",
		TextSize = 17,
		Size = UDim2.fromOffset(170, ACTION_HEIGHT),
		BackgroundColor3 = Theme.accent,
		TextColor3 = Theme.accentText,
		LayoutOrder = 2,
		Visible = false,
		Parent = actions,
	}, merge)
	sellButton = Widgets.button({
		Name = "Sell",
		TextSize = 17,
		Size = UDim2.fromOffset(150, ACTION_HEIGHT),
		TextColor3 = SHARDS_COLOR,
		LayoutOrder = 3,
		Visible = false,
		Parent = actions,
	}, sell)

	local buttons = row("Buttons", BUTTON_HEIGHT, 6, footer)
	buttons.Size = UDim2.fromScale(1, 1)
	footerButtons = buttons
	buttons:FindFirstChildOfClass("UIListLayout"):Destroy()
	Widgets.create(
		"UIGridLayout",
		{ CellPadding = UDim2.fromOffset(GAP, GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = buttons }
	)
	-- widths fit the panel with every button shown (compact layout: reroll, bonus reroll, STATS, READY)
	rerollButton = Widgets.button({
		Name = "Reroll",
		Size = UDim2.fromOffset(210, BUTTON_HEIGHT),
		LayoutOrder = 1,
		Parent = buttons,
	}, reroll)
	StoreController.mountShop(buttons, 2, BUTTON_HEIGHT) -- Paket 16
	statsButton = Widgets.button({
		Name = "StatsToggle",
		Text = "STATS",
		Size = UDim2.fromOffset(110, BUTTON_HEIGHT),
		LayoutOrder = 3,
		Visible = false,
		Parent = buttons,
	}, function()
		setShowingStats(true)
	end)
	readyButton = Widgets.button({
		Name = "Ready",
		Size = UDim2.fromOffset(230, BUTTON_HEIGHT),
		LayoutOrder = 4,
		Parent = buttons,
	}, toggleReady)

	-- compact layout: back from the stat panel to the shop
	backButton = Widgets.button({
		Name = "BackToShop",
		Text = "← SHOP",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(160, 56),
		BackgroundColor3 = Theme.accent,
		TextColor3 = Theme.accentText,
		Visible = false,
		Parent = screen,
	}, function()
		setShowingStats(false)
	end)
end

-- Lifecycle -------------------------------------------------------------------------

function ShopController.init()
	Net.onClient("ShopState", function(state: Types.ShopState)
		shop = state
		render()
	end)
end

function ShopController.start()
	build()
	RunStateController.Changed:Connect(render)
	render()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(render)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(render)
	local levelUpWasOpen = false
	RunService.Heartbeat:Connect(function()
		local levelUpOpen = LevelUpController.isOpen()
		if levelUpOpen ~= levelUpWasOpen then
			levelUpWasOpen = levelUpOpen
			render() -- the shop appears once the level-up cards are done
		end
		updateSubtitle()
	end)
end

-- Queries ---------------------------------------------------------------------------

-- The local player's shop as the server sent it last, or nil (smoke test).
function ShopController.get(): Types.ShopState?
	return shop
end

-- True while the shop panel is on screen (smoke test).
function ShopController.isShopping(): boolean
	return isShopping()
end

-- True while the shop uses its compact layout for small screens (smoke test).
function ShopController.isCompact(): boolean
	return compact
end

return ShopController
