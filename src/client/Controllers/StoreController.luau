--!strict
-- Robux purchases on screen (Paket 16, DESIGN.md section 12; StoreState from MonetizationService): a STORE button and
-- window in the lobby (game passes, reroll pack, Ember packs, Server Ember Boost; saved tokens) with the running Ember
-- Boost under the record, a bonus reroll button in the shop (VIP reroll or reroll token, else the reroll pack) and a
-- revive button while the local player is down in a co-op wave. Only sends intents (RequestPurchase, UseBonusReroll);
-- Roblox shows its own purchase prompt and the server grants. Also puts "[VIP]" before VIP players' chat messages.
-- Mounted by ProfileCard (lobby) and ShopController (shop button); purchase buttons never show during a fight.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local PurchaseRules = require(Shared:WaitForChild("Util"):WaitForChild("PurchaseRules"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local AchievementList = require(script.Parent.AchievementList)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local Store = Config.Store
local Economy = Config.Economy
local ROW_HEIGHT = 56
local REFRESH_SECONDS = 1 -- the boost countdown
local REVIVE_Y = 0.8 -- share of the screen height, below ReviveController's hint line
local OWNED_COLOR = Theme.success

local StoreController = {}

local state: Types.StoreState? = nil
local localDown = false -- down or out in the current wave (ReviveState)
local window: Frame? = nil
local tokensLabel: TextLabel? = nil
local boostLabel: TextLabel? = nil
local shopButton: TextButton? = nil
local reviveScreen: ScreenGui? = nil
local reviveButton: TextButton? = nil
local buttons: { [string]: TextButton } = {}
local sinceRefresh = 0

local function priceText(key: string): string
	local price = if state then state.prices[key] else nil
	local fallback = PurchaseRules.pass(key) or PurchaseRules.product(key)
	return `R$ {price or (fallback :: any).price}`
end

local function isSetUp(key: string): boolean
	return state ~= nil and state.setUp[key] == true
end

local function request(key: string)
	Net.fireServer("RequestPurchase", key)
end

-- Ember Boost ---------------------------------------------------------------------------------

local function boostSecondsLeft(): number
	local boost = state and state.boost
	if not boost then
		return 0
	end
	return math.max(0, boost.secondsLeft - (workspace:GetServerTimeNow() - boost.sentAt))
end

local function boostText(): string
	local left = boostSecondsLeft()
	local boost = state and state.boost
	if left <= 0 or not boost then
		return ""
	end
	local minutes = math.max(1, math.ceil(left / 60))
	return `EMBER BOOST +{math.round(Economy.serverBoost.bonus * 100)}% · {minutes} min left · by {boost.by}`
end

-- Lobby window --------------------------------------------------------------------------------

local function rowText(key: string, name: string, text: string): (string, Color3, boolean)
	local owned = state ~= nil and state.passes[key] == true
	if owned then
		return `{name} · OWNED\n{text}`, OWNED_COLOR, false
	elseif not isSetUp(key) then
		return `{name} · not set up yet\n{text}`, Theme.textDim, false
	end
	return `{name} · {priceText(key)}\n{text}`, Theme.text, true
end

local function renderWindow()
	for key, button in buttons do
		local entry: any = PurchaseRules.pass(key) or PurchaseRules.product(key)
		local text, color, active = rowText(key, entry.name, entry.text)
		button.Text = text
		button.TextColor3 = color
		button.AutoButtonColor = active
	end
	local label = tokensLabel
	if label then
		local tokens = if state then state.tokens else { revives = 0, rerolls = 0 }
		label.Text = `Saved: {tokens.revives} revives · {tokens.rerolls} shop rerolls`
	end
end

local function renderBoost()
	local label = boostLabel
	if label then
		local text = boostText()
		label.Text = text
		label.Visible = text ~= ""
	end
end

-- Shop button ---------------------------------------------------------------------------------

local function bonusRerolls(): number
	if not state then
		return 0
	end
	return PurchaseRules.bonusRerolls(state.vipRerolls, state.tokens)
end

local function renderShopButton()
	local button = shopButton
	if not button then
		return
	end
	local bonus = bonusRerolls()
	if bonus > 0 then
		button.Visible = true
		button.Text = `Bonus reroll ({bonus})`
		button.TextColor3 = Theme.accent
	elseif isSetUp("Rerolls") then
		button.Visible = true
		button.Text = `+{Economy.rerollPackAmount} rerolls · {priceText("Rerolls")}`
		button.TextColor3 = Theme.text
	else
		button.Visible = false
	end
end

local function pressShopButton()
	if bonusRerolls() > 0 then
		Net.fireServer("UseBonusReroll")
	else
		request("Rerolls")
	end
end

-- Revive button -------------------------------------------------------------------------------

local function teammateStands(): boolean
	local run = RunStateController.get()
	local me = Players.LocalPlayer
	if not run then
		return false
	end
	for _, info in run.players do
		if info.participant and info.userId ~= me.UserId and info.state == "Alive" then
			return true
		end
	end
	return false
end

local function reviveOffer(): string?
	local run = RunStateController.get()
	if not (state and run and localDown and run.phase == "Running") then
		return nil
	end
	if state.reviveUsed or not teammateStands() then
		return nil
	end
	if state.tokens.revives > 0 then
		return `USE REVIVE ({state.tokens.revives})`
	elseif isSetUp("Revive") then
		return `REVIVE NOW · {priceText("Revive")}`
	end
	return nil
end

local function renderRevive()
	local screen, button = reviveScreen, reviveButton
	if not (screen and button) then
		return
	end
	local offer = reviveOffer()
	screen.Enabled = offer ~= nil and RunStateController.getView() == "Run"
	button.Text = offer or ""
end

local function render()
	renderWindow()
	renderBoost()
	renderShopButton()
	renderRevive()
end

local function buildRevive()
	reviveScreen = Widgets.screen("StoreRevive", 6)
	reviveButton = Widgets.button({
		Name = "BuyRevive",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, REVIVE_Y),
		Size = UDim2.fromOffset(280, 52),
		BackgroundColor3 = Theme.accent,
		TextColor3 = Theme.accentText,
		Parent = reviveScreen,
	}, function()
		request("Revive")
	end)
	Widgets.scaled(reviveButton :: TextButton)
end

-- "[VIP]" in front of chat messages of VIP players (player attribute set by MonetizationService).
local function hookChat()
	local ok, chat = pcall(game.GetService, game, "TextChatService")
	if not ok or not chat then
		return
	end
	local hex = Store.vip.colorHex
	local textChat: any = chat
	textChat.OnIncomingMessage = function(message: any)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local player = source and Players:GetPlayerByUserId(source.UserId)
		if player and player:GetAttribute(Store.vip.attribute) == true then
			properties.PrefixText = `<font color="#{hex}">[{Store.vip.tag}]</font> {message.PrefixText}`
		end
		return properties
	end
end

-- Mounting --------------------------------------------------------------------------------------

function StoreController.isOpen(): boolean
	return window ~= nil and window.Visible
end

function StoreController.setOpen(open: boolean)
	if window then
		window.Visible = open
		if open then
			AchievementList.setOpen(false)
		end
	end
end

-- Adds the boost line and the STORE button to the lobby's player list panel (ProfileCard) and builds the window.
function StoreController.mount(list: Frame)
	boostLabel = Widgets.label({
		Name = "EmberBoost",
		TextSize = 14,
		TextColor3 = Theme.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		LayoutOrder = 14,
		Parent = list,
	})
	Widgets.button({
		Name = "OpenStore",
		Text = "STORE",
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Theme.accent,
		TextColor3 = Theme.accentText,
		LayoutOrder = 15,
		Parent = list,
	}, function()
		StoreController.setOpen(not StoreController.isOpen())
	end)

	local panel = Widgets.panel({
		Name = "Store",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 0),
		Visible = false,
		ZIndex = 5,
		Parent = list.Parent,
	})
	window = panel
	Widgets.list(8).Parent = panel
	Widgets.label({
		Text = "STORE",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		LayoutOrder = 1,
		Parent = panel,
	})
	local scroll = Widgets.create("ScrollingFrame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Size = UDim2.new(1, 0, 0, 360),
		LayoutOrder = 2,
		Parent = panel,
	})
	Widgets.list(6).Parent = scroll
	local count = 0
	local function addRow(key: string)
		count += 1
		buttons[key] = Widgets.button({
			Name = `Buy_{key}`,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
			LayoutOrder = count,
			Parent = scroll,
		}, function()
			if isSetUp(key) and not (state and state.passes[key]) then
				request(key)
			end
		end)
	end
	for _, pass in Store.passes do
		addRow(pass.key)
	end
	for _, product in Store.products do
		if product.inStore then
			addRow(product.key)
		end
	end
	scroll.CanvasSize = UDim2.fromOffset(0, count * (ROW_HEIGHT + 6))
	tokensLabel = Widgets.label({
		Name = "Tokens",
		TextSize = 15,
		TextColor3 = Theme.textDim,
		LayoutOrder = 3,
		Parent = panel,
	})
	Widgets.button({
		Name = "CloseStore",
		Text = "CLOSE",
		TextSize = 18,
		Size = UDim2.fromOffset(200, 44),
		LayoutOrder = 4,
		Parent = panel,
	}, function()
		StoreController.setOpen(false)
	end)
	render()
end

-- Adds the bonus reroll button to the shop's button row (ShopController).
function StoreController.mountShop(row: Frame, layoutOrder: number, height: number)
	shopButton = Widgets.button({
		Name = "BonusReroll",
		TextSize = 16,
		Size = UDim2.fromOffset(170, height),
		LayoutOrder = layoutOrder,
		Visible = false,
		Parent = row,
	}, pressShopButton)
	renderShopButton()
end

-- Lifecycle -----------------------------------------------------------------------------------

function StoreController.init()
	Net.onClient("StoreState", function(payload: Types.StoreState)
		state = payload
		render()
	end)
	Net.onClient("ReviveState", function(payload: Types.ReviveState)
		local me = Players.LocalPlayer.UserId
		localDown = false
		for _, info in payload.players do
			if info.userId == me then
				localDown = true
			end
		end
		renderRevive()
	end)
end

function StoreController.start()
	buildRevive()
	hookChat()
	RunStateController.Changed:Connect(renderRevive)
	RunService.Heartbeat:Connect(function(dt)
		sinceRefresh += dt
		if sinceRefresh >= REFRESH_SECONDS then
			sinceRefresh = 0
			renderBoost()
		end
	end)
	render()
end

-- Queries (tests) -----------------------------------------------------------------------------

-- The StoreState the server sent last, or nil.
function StoreController.get(): Types.StoreState?
	return state
end

-- The lobby window's row button of a key (tests).
function StoreController.getRow(key: string): TextButton?
	return buttons[key]
end

return StoreController
