--!strict
-- Shards and the shop between waves (DESIGN.md sections 3 and 13, Brotato direction since B1). A small Shards counter
-- next to the timer during the whole run. Between waves an opaque backdrop hides the arena (below the HUD, so the
-- timer, build and team stay visible) with "WAVE n CLEARED"; once the level-up cards are done (LevelUpController), the
-- shop panel: up to four offers (weapons: name, effect, "NEW"/"LV 3"; items: name, stat lines in green and red,
-- rarity in its color; price), a reroll with its price and READY. Everything comes from the server's ShopState
-- (ShopService); sends BuyShopOffer, RerollShop and SetShopReady. The stats sit next to it (StatsController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local UpgradeText = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeText"))

local LevelUpController = require(script.Parent.LevelUpController)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local CARD_SIZE = Vector2.new(180, 236)
local CARD_GAP = 12
local SHARDS_COLOR = Color3.fromRGB(120, 230, 210) -- teal: Shards, not XP and not Embers
local BACKDROP_COLOR = Color3.fromRGB(12, 9, 20) -- the screen between waves, darker than the panels
local STAT_COLORS = { plus = Theme.success, minus = Theme.danger }

local ShopController = {}

local screen: ScreenGui
local backdrop: ScreenGui
local backdropTitle: TextLabel
local backdropHint: TextLabel
local shardsLabel: TextLabel
local panel: Frame
local subtitleLabel: TextLabel
local cardRow: Frame
local rerollButton: TextButton
local readyButton: TextButton

type CardView = {
	button: TextButton,
	badge: TextLabel,
	name: TextLabel,
	detail: TextLabel,
	price: TextLabel,
	edge: UIStroke,
}

local cards: { CardView } = {}
local shop: Types.ShopState? = nil

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

local function buy(index: number)
	local current = shop
	local offer = current and current.offers[index]
	if not (current and offer and isShopping()) or offer.sold then
		return
	end
	Net.fireServer("BuyShopOffer", offer.id)
end

local function reroll()
	if isShopping() then
		Net.fireServer("RerollShop")
	end
end

local function toggleReady()
	local info = localInfo()
	if isShopping() and info then
		Net.fireServer("SetShopReady", not info.shopReady)
	end
end

local function buildCard(index: number): CardView
	local button = Widgets.button({
		Name = `Offer{index}`,
		Text = "",
		Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
		LayoutOrder = index,
		Parent = cardRow,
	}, function()
		buy(index)
	end)
	Widgets.padding(10).Parent = button
	Widgets.list(6).Parent = button
	local edge = Widgets.create("UIStroke", { Name = "Edge", Color = Theme.stroke, Thickness = 2, Parent = button })
	local badge = Widgets.label({
		Name = "Badge",
		Font = Theme.fontBold,
		TextSize = 15,
		TextColor3 = Theme.accent,
		LayoutOrder = 1,
		Parent = button,
	})
	local name = Widgets.label({
		Name = "OfferName",
		Font = Theme.fontBold,
		TextSize = 20,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 2,
		Parent = button,
	})
	local detail = Widgets.label({
		Name = "Detail",
		TextSize = 15,
		TextColor3 = Theme.textDim,
		RichText = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 92),
		LayoutOrder = 3,
		Parent = button,
	})
	local price = Widgets.label({
		Name = "Price",
		Font = Theme.fontBold,
		TextSize = 20,
		TextColor3 = SHARDS_COLOR,
		LayoutOrder = 4,
		Parent = button,
	})
	return { button = button, badge = badge, name = name, detail = detail, price = price, edge = edge }
end

local function renderCards(current: Types.ShopState)
	for index, view in cards do
		local offer = current.offers[index]
		view.button.Visible = offer ~= nil
		if offer then
			local title, detail, badge = UpgradeText.offer(offer, STAT_COLORS)
			local color = if offer.kind == "Weapon" then Theme.accent else Theme.tiers[offer.tier] or Theme.accent
			local affordable = current.shards >= offer.price
			view.badge.Text = if offer.sold then "SOLD" else string.upper(badge)
			view.badge.TextColor3 = color
			view.name.Text = title
			view.detail.Text = detail
			view.price.Text = if offer.sold then "" else `{offer.price} Shards`
			view.price.TextColor3 = if affordable then SHARDS_COLOR else Theme.danger
			view.edge.Color = if offer.sold then Theme.stroke else color
			view.button.AutoButtonColor = not offer.sold and affordable
			view.button.BackgroundTransparency = if offer.sold then 0.6 else 0
		end
	end
end

local function render()
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
	panel.Visible = shopping
	if not (current and shopping) then
		return
	end
	renderCards(current)
	local canReroll = current.shards >= current.rerollPrice
	rerollButton.Text = `Reroll ({current.rerollPrice} Shards)`
	rerollButton.TextColor3 = if canReroll then Theme.text else Theme.textDim
	rerollButton.AutoButtonColor = canReroll
	local info = localInfo()
	local ready = info ~= nil and info.shopReady == true
	readyButton.Text = if ready then "WAITING… (tap to keep shopping)" else "READY"
	readyButton.BackgroundColor3 = if ready then Theme.button else Theme.accent
	readyButton.TextColor3 = if ready then Theme.text else Theme.accentText
end

local function updateSubtitle()
	if not (panel and panel.Visible) then
		return
	end
	local state = RunStateController.get()
	local left = math.ceil(RunStateController.getPhaseRemaining())
	local text = `Wave {if state then state.wave else 0} cleared · next wave in {left}`
	if subtitleLabel.Text ~= text then
		subtitleLabel.Text = text
	end
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
	local header = Widgets.panel({
		Name = "Header",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.17),
		Size = UDim2.fromOffset(600, 0),
		Parent = cover,
	})
	Widgets.list(2).Parent = header
	backdropTitle = Widgets.label({
		Name = "Title",
		Font = Theme.fontBold,
		TextSize = 40,
		TextColor3 = Theme.accent,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 1,
		Parent = header,
	})
	backdropHint = Widgets.label({ Name = "Hint", TextColor3 = Theme.textDim, LayoutOrder = 2, Parent = header })

	screen = Widgets.screen("Shop", 4)
	local shards = Widgets.panel({
		Name = "Shards",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -222, 0, 8),
		Size = UDim2.fromOffset(150, 0),
		Parent = screen,
	})
	shardsLabel = Widgets.label({
		Name = "ShardsText",
		Font = Theme.fontBold,
		TextColor3 = SHARDS_COLOR,
		Text = "0 Shards",
		Parent = shards,
	})

	local width = Config.Shop.slots * CARD_SIZE.X + (Config.Shop.slots - 1) * CARD_GAP
	panel = Widgets.panel({
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(width + 28, 0),
		Visible = false,
		Parent = screen,
	})
	Widgets.list(8).Parent = panel
	Widgets.label({
		Name = "Title",
		Text = "SHOP",
		Font = Theme.fontBold,
		TextSize = Theme.titleSize,
		TextColor3 = Theme.accent,
		Size = UDim2.new(1, 0, 0, Theme.titleSize + 6),
		LayoutOrder = 1,
		Parent = panel,
	})
	subtitleLabel = Widgets.label({ Name = "Subtitle", LayoutOrder = 2, Parent = panel })
	cardRow = Widgets.create("Frame", {
		Name = "Offers",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, CARD_SIZE.Y),
		LayoutOrder = 3,
		Parent = panel,
	})
	Widgets.list(CARD_GAP, Enum.FillDirection.Horizontal).Parent = cardRow
	for index = 1, Config.Shop.slots do
		cards[index] = buildCard(index)
	end
	local buttons = Widgets.create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = 4,
		Parent = panel,
	})
	Widgets.list(CARD_GAP, Enum.FillDirection.Horizontal).Parent = buttons
	rerollButton = Widgets.button({
		Name = "Reroll",
		Size = UDim2.fromOffset(240, 52),
		LayoutOrder = 1,
		Parent = buttons,
	}, reroll)
	readyButton = Widgets.button({
		Name = "Ready",
		Size = UDim2.fromOffset(320, 52),
		LayoutOrder = 2,
		Parent = buttons,
	}, toggleReady)
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

return ShopController
