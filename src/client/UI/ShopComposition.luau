--!strict
-- Applies the approved desktop composition to the existing shop controls; ShopController owns all actions.
local Widgets = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local Layout = require(script.Parent.ShopLayout)
local Currency = require(script.Parent.Currency)
local OfferText = require(script.Parent.OfferText)
local ChallengeIcon = require(script.Parent.ChallengeIcon)
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local WeaponClasses = require(Shared.Util.WeaponClasses)
local Composition = {}
-- Inventory tiles (items, weapons, character): grey tile, thin dark outline, tier color only above tier 1.
local TILE = Color3.fromRGB(42, 42, 42)
local function inventoryTile(tile: GuiObject, tier: number, selected: boolean?)
	tile.BackgroundColor3 = if tier > 1 then Theme.tiers[tier]:Lerp(Theme.panel, 0.6) else TILE
	local edge = tile:FindFirstChild("Outline") or tile:FindFirstChildOfClass("UIStroke")
	if edge and edge:IsA("UIStroke") then
		edge.Color = if selected then Theme.accent elseif tier > 1 then Theme.tiers[tier] else Theme.stroke
		edge.Thickness = 2
	end
end
local plan = {}
local saved: any = nil

function Composition.setPlan(value: any)
	plan = value
end

function Composition.setRemaining(seconds: number)
	if saved and saved.countdown then
		saved.countdown.Text = `Next wave in {math.max(0, seconds)}s`
	end
end

local function place(object: GuiObject, x: number, y: number, width: number, height: number)
	object.AnchorPoint = Vector2.new(0, 0)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(width, height)
end

function Composition.apply(ctx: any, area: Vector2)
	if not saved then
		saved = {
			list = ctx.panel:FindFirstChildOfClass("UIListLayout"),
			headerList = ctx.header:FindFirstChildOfClass("UIListLayout"),
			padding = ctx.panel:FindFirstChildOfClass("UIPadding"),
			outline = ctx.panel:FindFirstChildOfClass("UIStroke"),
			storage = Instance.new("Folder"),
			inventory = Widgets.create("ScrollingFrame", {
				Name = "ItemInventory",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 3,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Parent = ctx.panel,
			}),
			weapons = Widgets.create("ScrollingFrame", {
				Name = "WeaponInventory",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 3,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Parent = ctx.panel,
			}),
			chips = {},
		}
		for _, view in ctx.chips do
			saved.chips[view] = {
				list = view.button:FindFirstChildOfClass("UIListLayout"),
				padding = view.button:FindFirstChildOfClass("UIPadding"),
			}
		end
		saved.shard = Currency.mount(ctx.shardsPanel, 32)
		saved.countdown = Widgets.label({
			Name = "Countdown",
			TextSize = 13,
			TextColor3 = Theme.textDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.fromOffset(390, 22),
			Parent = ctx.header,
		})
		ctx.shardsPanel.BackgroundTransparency = 1
		local stroke = ctx.shardsPanel:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = 0
		end
		local padding = ctx.shardsPanel:FindFirstChildOfClass("UIPadding")
		if padding then
			padding:Destroy()
		end
		saved.schedule =
			Widgets.create("Frame", { Name = "WaveSchedule", BackgroundTransparency = 1, Parent = ctx.screen })
		saved.hint = Widgets.label({
			Name = "Hint",
			TextSize = 15,
			BackgroundColor3 = Theme.button,
			BackgroundTransparency = 0,
			Size = UDim2.new(1, 0, 0, 28),
			Parent = saved.schedule,
		})
		Widgets.corner().Parent = saved.hint
		saved.slots = {}
		for index = 1, 3 do
			local slot = Widgets.create("Frame", {
				Name = `Challenge{index}`,
				BackgroundColor3 = Theme.panel,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(70 + (index - 1) * 68, 36),
				Size = UDim2.fromOffset(60, 60),
				Parent = saved.schedule,
			}, { Widgets.corner(), Widgets.create("UIStroke", { Color = Theme.stroke, Thickness = 2 }) })
			Widgets.label({
				Name = "Symbol",
				Text = "☠",
				TextSize = 40,
				TextColor3 = Theme.gloom,
				Size = UDim2.fromScale(1, 1),
				Parent = slot,
			})
			Widgets.label({
				Name = "Number",
				Font = Theme.fontBold,
				TextSize = 24,
				TextStrokeTransparency = 0,
				Position = UDim2.fromOffset(0, 34),
				Size = UDim2.new(1, 0, 0, 26),
				ZIndex = 3,
				Parent = slot,
			})
			saved.slots[index] = slot
			ChallengeIcon.mount(slot)
		end
		saved.scheduleScale = Widgets.create("UIScale", { Parent = saved.schedule })
		saved.footerScale = Widgets.create("UIScale", { Parent = ctx.footer })
	end
	local layout = Layout.measure(area)
	local compact = layout.compact
	local shopping = ctx.panel.Visible
	local scale = layout.scale
	saved.list.Parent = if compact then ctx.panel else saved.storage
	saved.headerList.Parent = if compact then ctx.header else saved.storage
	saved.padding.Parent = if compact then ctx.panel else saved.storage
	saved.outline.Thickness = if compact then 1.5 else 0
	ctx.panel.BackgroundTransparency = 1
	ctx.footer.BackgroundTransparency = 1
	saved.inventory.Visible = not compact
	saved.weapons.Visible = not compact
	saved.schedule.Visible = not compact and shopping
	saved.countdown.Visible = not compact and shopping
	ctx.itemRow.Parent = if compact then ctx.panel else saved.inventory
	ctx.chipRow.Parent = if compact then ctx.panel else saved.weapons
	ctx.chipRow.AutomaticSize = if compact then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
	local bonus = ctx.footerButtons:FindFirstChild("BonusReroll") or ctx.screen:FindFirstChild("BonusReroll")
	ctx.rerollButton.Parent = if compact then ctx.footerButtons else ctx.screen
	if bonus then
		bonus.Parent = if compact then ctx.footerButtons else ctx.screen
	end
	ctx.rerollButton.Visible = shopping
	if bonus then
		-- StoreController retains availability; a hidden parent suppresses it outside the shop.
		bonus.Parent = if shopping and not compact then ctx.screen else ctx.footerButtons
	end
	saved.footerScale.Scale = if compact then 1 else scale
	saved.shard.Visible = true
	-- Icon and amount share one middle line.
	saved.shard.AnchorPoint = Vector2.new(0, 0.5)
	saved.shard.Position = UDim2.new(0, 2, 0.5, 0)
	ctx.shardsLabel.Text = tostring(if ctx.current then ctx.current.shards else 0)
	ctx.shardsLabel.TextColor3 = Theme.text
	ctx.shardsLabel.TextSize = (if compact then 24 else 29 * scale) * (if shopping then 1 else Theme.hudTextScale)
	ctx.shardsLabel.TextStrokeTransparency = 0
	ctx.shardsLabel.TextXAlignment = Enum.TextXAlignment.Left
	place(ctx.shardsLabel, 40, 0, 110, 44)
	ctx.shardsLabel.TextYAlignment = Enum.TextYAlignment.Center
	ctx.shardsPanel.AutomaticSize = Enum.AutomaticSize.None
	ctx.shardsPanel.Size = UDim2.fromOffset(150, 44)
	for _, view in ctx.chips do
		local original = saved.chips[view]
		original.list.Parent = if compact then view.button else saved.storage
		original.padding.Parent = if compact then view.button else saved.storage
		view.name.Visible = compact
		view.info.Visible = compact
		view.details.Text = if compact then "DETAILS" else "i"
		if compact then
			place(view.button, 0, 0, 136, 90)
			place(view.details, 0, 92, 136, 26)
			view.details.Visible = true
			view.icon.Size = UDim2.fromOffset(48, 48)
			view.icon.Position = UDim2.new()
		else
			place(view.button, 0, 0, 64, 64)
			place(view.details, 44, 1, 19, 19)
			-- The inspect popup (UI/WeaponInspect) shows the stats on desktop.
			view.details.Visible = false
			place(view.icon, 6, 6, 52, 52)
			local weapon = ctx.current and ctx.current.weapons[view.frame.LayoutOrder]
			inventoryTile(
				view.button,
				if weapon then weapon.tier else 1,
				weapon ~= nil and weapon.uid == ctx.selectedUid
			)
		end
	end
	for _, view in ctx.cards do
		view.badge.BackgroundTransparency = 1
		view.badge.TextColor3 = Theme.statLabel
		view.button.BackgroundColor3 = Theme.button
		view.price.TextColor3 = Theme.text
		view.price.BackgroundColor3 = Theme.price
		local priceIcon = view.price:FindFirstChild("ShardIcon")
		if not priceIcon then
			Widgets.corner().Parent = view.price
			priceIcon = Currency.mount(view.price, 28)
			priceIcon.AnchorPoint = Vector2.new(1, 0.5)
			priceIcon.Position = UDim2.new(1, -6, 0.5, 0)
		end
		local amount = view.price:FindFirstChild("Amount")
		if not amount then
			amount = Widgets.label({
				Name = "Amount",
				Font = Theme.fontBold,
				TextSize = 29,
				Position = UDim2.fromOffset(6, 0),
				Size = UDim2.new(1, -44, 1, 0),
				Parent = view.price,
			})
		end
		amount.Visible = not compact
		priceIcon.Visible = not compact
		if compact then
			local offer = ctx.current and ctx.current.offers[view.frame.LayoutOrder]
			if offer then
				view.name.TextColor3 = Theme.tiers[offer.tier]
				view.button.BackgroundColor3 = Theme.cardSurfaces[offer.tier]
				view.edge.Color = if offer.tier == 1 then Theme.stroke else Theme.tiers[offer.tier]
			end
			view.name.TextXAlignment = Enum.TextXAlignment.Center
			view.detail.TextXAlignment = Enum.TextXAlignment.Center
			view.badge.Size = UDim2.new(1, 0, 0, 20)
			view.details.Parent = view.frame
		else
			view.list.Parent = saved.storage
			local zero = UDim.new(0, 0)
			view.padding.PaddingTop, view.padding.PaddingBottom = zero, zero
			view.padding.PaddingLeft, view.padding.PaddingRight = zero, zero
			local cardWidth = (layout.leftWidth - 28 - 24) / 4
			local height = layout.cardHeight
			place(view.button, 0, 0, cardWidth, height)
			place(view.artStage, 10, 10, 64, 64)
			view.icon.Size = UDim2.fromScale(1, 1)
			place(view.name, 84, 8, cardWidth - 94, 44)
			view.name.TextSize = 18
			view.name.TextXAlignment = Enum.TextXAlignment.Left
			view.name.TextYAlignment = Enum.TextYAlignment.Top
			place(view.badge, 84, 54, cardWidth - 94, 26)
			view.badge.Position =
				UDim2.fromOffset(84, if #(view.name.Text or "") > (cardWidth - 94) / 9 then 54 else 32)
			view.badge.TextSize = 16
			view.badge.TextXAlignment = Enum.TextXAlignment.Left
			view.badge.TextYAlignment = Enum.TextYAlignment.Top
			place(view.detailArea, 10, 86, cardWidth - 20, height - 162)
			view.detail.TextXAlignment = Enum.TextXAlignment.Left
			view.detail.TextSize = 16
			place(view.price, (cardWidth - 104) / 2, height - 56, 104, 44)
			view.price.TextSize = 29
			view.details.Parent = view.button
			place(view.details, cardWidth - 70, height - 80, 62, 20)
			view.details.TextSize = 12
			view.details.BackgroundTransparency = 1
			place(view.lock, 15, height + 8, cardWidth - 30, 34)
			view.lock.TextSize = 18
			view.lock.BackgroundColor3 = Theme.button
			view.lock.Outline.Thickness = 0
			local offer = ctx.current and ctx.current.offers[view.frame.LayoutOrder]
			if offer then
				view.button.BackgroundColor3 = Theme.cardSurfaces[offer.tier]
				view.name.TextColor3 = Theme.tiers[offer.tier]
				view.edge.Color = if offer.tier == 1 then Theme.stroke else Theme.tiers[offer.tier]
				view.edge.Thickness = if offer.locked then 3 else 1.5
				view.lock.TextColor3 = if offer.locked then Theme.tiers[2] else Theme.text
				view.badge.Text = if offer.sold
					then "SOLD"
					elseif offer.kind == "Weapon" then WeaponClasses.names(offer.itemId)
					else "Item"
				if offer.kind == "Weapon" then
					local _, text = OfferText.weapon(offer.itemId, offer.tier, ctx.sheet)
					-- Full slots look like a normal offer (reference game); only the merge hint is added.
					view.detail.Text = text
						.. (if offer.merges then "\nMerges into " .. tostring(offer.tier + 1) else "")
					view.detailArea.Visible = not offer.sold
				end
				-- A bought offer leaves an empty slot (reference game).
				view.button.Visible = not offer.sold
				view.lock.Visible = not offer.sold
				view.price.Text = if offer.sold then "SOLD" else tostring(offer.price)
				priceIcon.Visible = not offer.sold
				view.price.TextColor3 = if ctx.current.shards >= offer.price then Theme.text else Theme.danger
				amount.Text = view.price.Text
				amount.TextColor3 = view.price.TextColor3
				view.price.Text = ""
			end
		end
	end
	for _, entry in ctx.items do
		local tile = ctx.itemRow:FindFirstChild(entry.id)
		if tile then
			local count = tile:FindFirstChild("Count")
			if count then
				count.Visible = entry.count > 1
				count.TextSize = if compact then 13 else 23
				count.TextXAlignment = Enum.TextXAlignment.Right
				count.TextStrokeTransparency = 0
			end
			local item = Config.Items.byId[entry.id]
			inventoryTile(tile, if item then item.tier else 1)
			local art = tile:FindFirstChildWhichIsA("Frame")
			if art and not compact then
				place(art, 6, 6, 52, 52)
			end
		end
	end
	local characterTile = ctx.itemRow:FindFirstChild("CharacterTile")
	if characterTile then
		inventoryTile(characterTile, 1)
		place(characterTile.Art, 6, 6, 52, 52)
	end
	if compact then
		ctx.rerollButton.TextSize = 17
		if bonus then
			bonus.TextSize = 16
		end
		local rerollIcon = ctx.rerollButton:FindFirstChild("ShardIcon")
		if rerollIcon then
			rerollIcon.Visible = false
		end
		ctx.shopScroll.ScrollingEnabled = true
		ctx.header.Size = UDim2.new(1, 0, 0, 34)
		ctx.subtitleLabel.TextSize = 18
		ctx.subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
		ctx.subtitleLabel.TextStrokeTransparency = 1
		ctx.chipRow.Size = UDim2.new(1, 0, 0, 118)
		local chipGrid = ctx.chipRow:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		chipGrid.CellSize = UDim2.fromOffset(136, 118)
		chipGrid.CellPadding = UDim2.fromOffset(10, 10)
		chipGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		return
	end
	if not shopping then
		ctx.shardsPanel.Position = UDim2.fromOffset(12, 78 * scale)
	end
	local width = layout.leftWidth
	ctx.panelScale.Scale = scale
	place(ctx.panel, 0, 0, width, layout.height)
	place(ctx.shopScroll, 0, 0, width * scale, area.Y)
	ctx.shopScroll.CanvasSize = UDim2.new()
	ctx.shopScroll.ScrollingEnabled = false
	place(ctx.header, 14, 18, 410, 52)
	ctx.subtitleLabel.Text = `Shop (Wave {if ctx.current then ctx.current.wave else 0})`
	ctx.subtitleLabel.TextSize = 28
	ctx.subtitleLabel.TextColor3 = Theme.text
	ctx.subtitleLabel.TextStrokeTransparency = 0
	ctx.subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	local grid = ctx.cardRow:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	grid.CellSize = UDim2.fromOffset((width - 52) / 4, layout.cardHeight + 42)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	place(ctx.cardRow, 14, layout.cardY, width - 28, layout.cardHeight + 42)
	place(ctx.itemTitle, 14, layout.inventoryY, width - 256, 34)
	ctx.itemTitle.Text, ctx.itemTitle.TextSize, ctx.itemTitle.TextColor3 = "Items", 28, Theme.text
	ctx.itemTitle.TextXAlignment = Enum.TextXAlignment.Left
	ctx.itemTitle.Visible, ctx.itemRow.Visible = true, true
	ctx.weaponsTitle.Text = `Weapons ({if ctx.current then #ctx.current.weapons else 0}/{if ctx.current
		then ctx.current.maxWeapons
		else 6})`
	ctx.weaponsTitle.TextSize, ctx.weaponsTitle.TextColor3 = 28, Theme.text
	ctx.weaponsTitle.TextXAlignment = Enum.TextXAlignment.Left
	place(ctx.weaponsTitle, width - 224, layout.inventoryY, 224, 34)
	local inventoryHeight = math.max(64, layout.height - layout.inventoryY - 58)
	place(saved.inventory, 14, layout.inventoryY + 44, width - 256, inventoryHeight)
	place(saved.weapons, width - 224, layout.inventoryY + 44, 224, inventoryHeight)
	local itemCount = #ctx.items + 1 -- the character tile comes first
	local itemColumns = math.max(1, math.floor((width - 248) / 72))
	place(ctx.itemRow, 0, 0, width - 262, math.max(64, math.ceil(itemCount / itemColumns) * 72 - 8))
	place(
		ctx.chipRow,
		0,
		0,
		224,
		math.max(64, math.ceil((if ctx.current then #ctx.current.weapons else 0) / 3) * 72 - 8)
	)
	for _, container in { ctx.itemRow, ctx.chipRow } do
		local inventoryGrid = container:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		inventoryGrid.CellSize = UDim2.fromOffset(64, 64)
		inventoryGrid.CellPadding = UDim2.fromOffset(8, 8)
		inventoryGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end
	ctx.actionsRow.Visible = false -- desktop: Recycle and Combine live in the inspect popup
	place(ctx.actionsRow, 14, layout.inventoryY - 52, width - 28, 44)
	place(ctx.footer, layout.statsX * scale, (layout.statsHeight + 28) * scale, layout.statsWidth, 44)
	ctx.footerButtons.Size = UDim2.fromScale(1, 1)
	ctx.footerButtons:FindFirstChildOfClass("UIGridLayout").CellSize = UDim2.fromScale(1, 1)
	ctx.readyButton.Text = if ctx.ready
		then "WAITING… (tap to shop)"
		else `GO (Wave {if ctx.current then ctx.current.wave + 1 else 1})`
	ctx.readyButton.TextSize = 26
	place(ctx.rerollButton, (width - 218) * scale, 16 * scale, 204 * scale, 56 * scale)
	ctx.rerollButton.TextSize = 24 * scale
	ctx.rerollButton.Text = `REROLL - {if ctx.current then ctx.current.rerollPrice else 0}   `
	local rerollIcon = ctx.rerollButton:FindFirstChild("ShardIcon")
	if not rerollIcon then
		rerollIcon = Currency.mount(ctx.rerollButton, 30)
	end
	rerollIcon.AnchorPoint = Vector2.new(1, 0.5)
	rerollIcon.Visible = true
	rerollIcon.Position = UDim2.new(1, -14, 0.5, 0)
	if bonus then
		place(bonus, (width - 218) * scale, 76 * scale, 204 * scale, 22 * scale)
		bonus.TextSize = 13 * scale
	end
	if shopping then
		place(ctx.shardsPanel, width * 0.46 * scale, 22 * scale, 150 * scale, 44 * scale)
	end
	place(saved.schedule, layout.statsX * scale, (layout.statsHeight + 84) * scale, layout.statsWidth, 98)
	saved.scheduleScale.Scale = scale
	local upcoming = {}
	for _, entry in plan do
		if entry.wave > (if ctx.current then ctx.current.wave else 0) then
			table.insert(upcoming, entry)
		end
	end
	table.sort(upcoming, function(a, b)
		return a.wave < b.wave
	end)
	local first = upcoming[1]
	saved.schedule.Visible = not compact and shopping and first ~= nil
	saved.hint.Text = if first
		then `{if first.kind == "Elite" then "An elite" else "A horde"} will appear on wave {first.wave}`
		else "No elite waves scheduled"
	for index, slot in saved.slots do
		local entry = upcoming[index]
		slot.Visible = entry ~= nil
		if entry then
			slot.Number.Text = tostring(entry.wave)
			slot.Symbol.Text = ""
			ChallengeIcon.setKind(slot, entry.kind)
		end
	end
end

return Composition
