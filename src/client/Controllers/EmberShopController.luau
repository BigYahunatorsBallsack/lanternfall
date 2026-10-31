--!strict
-- Paket 17 lobby window "EMBER SHOP" (DESIGN.md section 10): spend saved Embers on locked characters and cosmetics
-- (lanterns, trails) and see every unlock. Tabs CHARACTERS (price, what unlocks it for free), LANTERNS and TRAILS (buy,
-- wear, VIP-only entries lead to the VIP pass) and UNLOCKS (locked weapons and items with their achievement). A buy
-- needs a second press within CONFIRM_SECONDS. Only sends intents (BuyWithEmbers, EquipCosmetic, RequestPurchase); the
-- server checks and answers with ProfileInfo. Mounted by ProfileCard next to the STORE button; reads ProfileCard
-- (Embers, unlocks, cosmetics) and StoreController (VIP).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EmberShopRules = require(Shared:WaitForChild("Util"):WaitForChild("EmberShopRules"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressRules = require(Shared:WaitForChild("Util"):WaitForChild("ProgressRules"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local ROW_HEIGHT = 56
local CONFIRM_SECONDS = 3
local TABS = { "CHARACTERS", "LANTERNS", "TRAILS", "UNLOCKS" }
local SLOT_OF_TAB: { [string]: string } = { LANTERNS = "Lantern", TRAILS = "Trail" }
local NONE_TEXT: { [string]: string } = { Lantern = "No lantern", Trail = "No trail" }

local Cosmetics = Config.Cosmetics

local EmberShopController = {}

local window: Frame? = nil
local rows: ScrollingFrame? = nil
local embersLabel: TextLabel? = nil
local tabButtons: { [string]: TextButton } = {}
local tab = TABS[1]
local confirming: { id: string, untilTime: number }? = nil

local function info(): Types.ProfileInfo?
	return require(script.Parent.ProfileCard).get()
end

local function isVip(): boolean
	local state = require(script.Parent.StoreController).get()
	return state ~= nil and state.passes.VIP == true
end

-- The saved data as the rules read it (empty until the record arrived).
local function wallet(): EmberShopRules.Wallet
	local record = info()
	return {
		embers = if record then record.embers or 0 else 0,
		achievements = if record then record.achievements or {} else {},
		classes = if record then record.ownedClasses or {} else {},
		cosmetics = if record and record.cosmetics then record.cosmetics else { owned = {}, equipped = {} },
	}
end

local function isConfirming(id: string): boolean
	return confirming ~= nil and confirming.id == id and os.clock() < confirming.untilTime
end

-- First press asks, the second one (within CONFIRM_SECONDS) buys.
local function pressBuy(kind: string, id: string)
	if isConfirming(id) then
		confirming = nil
		Net.fireServer("BuyWithEmbers", kind, id)
	else
		confirming = { id = id, untilTime = os.clock() + CONFIRM_SECONDS }
		task.delay(CONFIRM_SECONDS, EmberShopController.render)
	end
	EmberShopController.render()
end

-- A row: its text, color and what pressing it does (nil = nothing).
type Row = { id: string, text: string, color: Color3, press: (() -> ())? }

local function buyLine(kind: string, id: string, price: number, embers: number): (string, Color3, (() -> ())?)
	if isConfirming(id) then
		return `Press again to buy for {price} Embers`, Theme.accent, function()
			pressBuy(kind, id)
		end
	elseif embers < price then
		return `{price} Embers · you need {price - embers} more`, Theme.textDim, nil
	end
	return `{price} Embers · press to buy`, Theme.text, function()
		pressBuy(kind, id)
	end
end

local function characterRows(): { Row }
	local purse = wallet()
	local classes = {}
	for classId, class in Config.Classes do
		if class.available and ProgressRules.isLockable("characters", classId) then
			table.insert(classes, class)
		end
	end
	table.sort(classes, function(a, b)
		local pa = EmberShopRules.characterPrice(a.id) or math.huge
		local pb = EmberShopRules.characterPrice(b.id) or math.huge
		return if pa == pb then a.displayName < b.displayName else pa < pb
	end)
	local list = {}
	for _, class in classes do
		local requirement = ProgressRules.requirement("characters", class.id) or ""
		if EmberShopRules.ownsCharacter(class.id, purse) then
			table.insert(list, {
				id = class.id,
				text = `{class.displayName} · UNLOCKED\n{class.description}`,
				color = Theme.success,
			})
		else
			local price = EmberShopRules.characterPrice(class.id)
			if price then
				local line, color, press = buyLine("Character", class.id, price, purse.embers)
				table.insert(list, {
					id = class.id,
					text = `{class.displayName} · {line}\nor free: {requirement}`,
					color = color,
					press = press,
				})
			else
				table.insert(list, {
					id = class.id,
					text = `{class.displayName} · LOCKED\n{requirement}`,
					color = Theme.textDim,
				})
			end
		end
	end
	return list
end

local function cosmeticRows(slot: string): { Row }
	local purse = wallet()
	local vip = isVip()
	local owned, equipped = purse.cosmetics.owned, purse.cosmetics.equipped
	local shown = EmberShopRules.shown(slot, equipped, owned, vip)
	local list: { Row } = {
		{
			id = Cosmetics.none,
			text = if shown == nil then `{NONE_TEXT[slot]} · WEARING` else `{NONE_TEXT[slot]} · press to wear`,
			color = if shown == nil then Theme.success else Theme.text,
			press = if shown == nil
				then nil
				else function()
					Net.fireServer("EquipCosmetic", slot, Cosmetics.none)
				end,
		},
	}
	for _, entry in EmberShopRules.list(slot) do
		local id = entry.id
		local row: Row
		if shown == id then
			row = { id = id, text = `{entry.name} · WEARING`, color = Theme.success }
		elseif EmberShopRules.ownsCosmetic(id, owned, vip) then
			row = {
				id = id,
				text = `{entry.name} · {if entry.vip then "VIP" else "OWNED"} · press to wear`,
				color = Theme.text,
				press = function()
					Net.fireServer("EquipCosmetic", slot, id)
				end,
			}
		elseif entry.reward then -- Paket 18: login streak reward
			row = { id = id, text = `{entry.name} · {Config.Progress.shopTexts.rewardOnly}`, color = Theme.textDim }
		elseif entry.vip then
			row = {
				id = id,
				text = `{entry.name} · comes with the VIP pass\nPress to see the VIP pass`,
				color = Theme.accent,
				press = function()
					Net.fireServer("RequestPurchase", "VIP")
				end,
			}
		else
			local line, color, press = buyLine("Cosmetic", id, entry.price, purse.embers)
			row = { id = id, text = `{entry.name} · {line}`, color = color, press = press }
		end
		table.insert(list, row)
	end
	return list
end

local function unlockRows(): { Row }
	local purse = wallet()
	local list = {}
	local function add(kind: ProgressRules.Kind, label: string, ids: { string }, nameOf: (string) -> string)
		table.sort(ids, function(a, b)
			return nameOf(a) < nameOf(b)
		end)
		for _, id in ids do
			local open = ProgressRules.isUnlocked(kind, id, purse.achievements, purse.classes)
			table.insert(list, {
				id = id,
				text = `{nameOf(id)} ({label}) · {if open then "UNLOCKED" else "LOCKED"}\n`
					.. `{ProgressRules.requirement(kind, id) or ""}`,
				color = if open then Theme.success else Theme.textDim,
			})
		end
	end
	local weapons, items = {}, {}
	for id in Config.Weapons do
		if ProgressRules.isLockable("weapons", id) then
			table.insert(weapons, id)
		end
	end
	for _, item in Config.Items.list do
		if ProgressRules.isLockable("items", item.id) then
			table.insert(items, item.id)
		end
	end
	add("weapons", "weapon", weapons, function(id)
		return Config.Weapons[id].displayName
	end)
	add("items", "item", items, function(id)
		return Config.Items.byId[id].displayName
	end)
	return list
end

local function rowsOf(name: string): { Row }
	if name == "CHARACTERS" then
		return characterRows()
	elseif SLOT_OF_TAB[name] then
		return cosmeticRows(SLOT_OF_TAB[name])
	end
	return unlockRows()
end

function EmberShopController.render()
	local container = rows
	if not container then
		return
	end
	local purse = wallet()
	if embersLabel then
		embersLabel.Text = `You have {purse.embers} Embers`
	end
	for name, button in tabButtons do
		local active = name == tab
		button.BackgroundColor3 = if active then Theme.accent else Theme.button
		button.TextColor3 = if active then Theme.accentText else Theme.text
	end
	Widgets.clearRows(container)
	local list = rowsOf(tab)
	for index, row in list do
		local press = row.press
		local button = Widgets.button({
			Name = `Ember_{row.id}`,
			Text = row.text,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = row.color,
			AutoButtonColor = press ~= nil,
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
			LayoutOrder = index,
			Parent = container,
		}, function()
			if press then
				press()
			end
		end)
		Widgets.padding(8).Parent = button
	end
	container.CanvasSize = UDim2.fromOffset(0, #list * (ROW_HEIGHT + 6))
end

function EmberShopController.isOpen(): boolean
	return window ~= nil and window.Visible
end

-- One lobby window at a time: opening this closes the others (ProfileCard.closeWindows).
function EmberShopController.setOpen(open: boolean)
	if not window then
		return
	end
	if open then
		require(script.Parent.ProfileCard).closeWindows() -- one lobby window at a time (Paket 18)
	end
	window.Visible = open
	if open then
		EmberShopController.render()
	end
end

-- Shows a tab (tests and the tab buttons).
function EmberShopController.showTab(name: string)
	if table.find(TABS, name) then
		tab = name
		confirming = nil
		EmberShopController.render()
	end
end

-- Adds the EMBER SHOP button to `row` (the STORE row of the lobby's player list) and builds the hidden window on
-- `screen`.
function EmberShopController.mount(row: Frame, screen: Instance)
	Widgets.button({
		Name = "OpenEmberShop",
		Text = "EMBER SHOP",
		TextSize = 16,
		Size = UDim2.new(0.5, -3, 1, 0),
		LayoutOrder = 2,
		Parent = row,
	}, function()
		EmberShopController.setOpen(not EmberShopController.isOpen())
	end)

	local panel = Widgets.panel({
		Name = "EmberShop",
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
		Text = "EMBER SHOP",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		LayoutOrder = 1,
		Parent = panel,
	})
	embersLabel = Widgets.label({
		Name = "EmberShopEmbers",
		TextSize = 16,
		TextColor3 = Theme.accent,
		LayoutOrder = 2,
		Parent = panel,
	})
	local tabRow = Widgets.create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 3,
		Parent = panel,
	})
	Widgets.list(6, Enum.FillDirection.Horizontal).Parent = tabRow
	for index, name in TABS do
		tabButtons[name] = Widgets.button({
			Name = `Tab_{name}`,
			Text = name,
			TextSize = 13,
			Size = UDim2.new(1 / #TABS, -5, 1, 0),
			LayoutOrder = index,
			Parent = tabRow,
		}, function()
			EmberShopController.showTab(name)
		end)
	end
	local scroll = Widgets.create("ScrollingFrame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Size = UDim2.new(1, 0, 0, 330),
		LayoutOrder = 4,
		Parent = panel,
	})
	rows = scroll
	Widgets.list(6).Parent = scroll
	Widgets.button({
		Name = "CloseEmberShop",
		Text = "CLOSE",
		TextSize = 18,
		Size = UDim2.fromOffset(200, 44),
		LayoutOrder = 5,
		Parent = panel,
	}, function()
		EmberShopController.setOpen(false)
	end)
	EmberShopController.render()
end

function EmberShopController.init()
	-- VIP can change while the window is open (pass bought, debug button)
	Net.onClient("StoreState", function()
		task.defer(EmberShopController.render) -- after StoreController kept the new state
	end)
end

-- The row button of an id in the current tab (tests).
function EmberShopController.getRow(id: string): TextButton?
	local container = rows
	local found = container and container:FindFirstChild(`Ember_{id}`)
	return if found and found:IsA("TextButton") then found else nil
end

return EmberShopController
