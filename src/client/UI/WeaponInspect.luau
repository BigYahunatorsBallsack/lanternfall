--!strict
-- Inspect popup for an owned weapon in the shop (reference game layout): icon, name in tier color, classes, the
-- same stat lines as the offer cards, Recycle / Combine / Cancel, and one box per weapon class with its set bonus.
-- Built and positioned by ShopController (desktop layout); actions stay in ShopController.
local Widgets = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Currency = require(script.Parent.Currency)
local OfferText = require(script.Parent.OfferText)
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local UpgradeText = require(Shared.Util.UpgradeText)
local WeaponClasses = require(Shared.Util.WeaponClasses)

local WeaponInspect = {}

local WIDTH = 340
local CLASS_WIDTH = 330
local GAP = 8
local Z = 30
-- Set bonus lines that are not reached yet.
local INACTIVE = Color3.fromRGB(140, 140, 140)

export type Actions = { recycle: () -> (), combine: () -> (), cancel: () -> () }
export type Shown = {
	anchor: GuiObject,
	id: string,
	tier: number,
	evolution: string?,
	sellPrice: number,
	canMerge: boolean,
	sheet: { [string]: number },
	weaponIds: { string },
	characterId: string?,
}

local root: Frame
local panel: Frame
local icon: Frame
local nameLabel: TextLabel
local classLabel: TextLabel
local body: TextLabel
local recycle: TextButton
local recycleAmount: TextLabel
local combine: TextButton
local classColumn: Frame

local function hex(value: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.round(value.R * 255),
		math.round(value.G * 255),
		math.round(value.B * 255)
	)
end

local function box(name: string, parent: Instance): Frame
	return Widgets.create("Frame", {
		Name = name,
		BackgroundColor3 = Theme.button,
		BorderSizePixel = 0,
		ZIndex = Z,
		Parent = parent,
	}, { Widgets.corner(), Widgets.create("UIStroke", { Color = Theme.stroke, Thickness = 2 }) })
end

local function actionButton(name: string, order: number, onClick: () -> ()): TextButton
	local button = Widgets.button({
		Name = name,
		TextSize = 22,
		Font = Theme.fontBold,
		BackgroundColor3 = Theme.price,
		Size = UDim2.new(1, -20, 0, 36),
		LayoutOrder = order,
		ZIndex = Z + 1,
		Parent = panel,
	}, onClick)
	return button
end

-- Builds the hidden popup under `screen`.
function WeaponInspect.mount(screen: Instance, actions: Actions)
	root = Widgets.create("Frame", {
		Name = "WeaponInspect",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = Z,
		Parent = screen,
	})
	panel = box("Panel", root)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Size = UDim2.fromOffset(WIDTH, 0)
	panel.Active = true
	Widgets.padding(10).Parent = panel
	local list = Widgets.list(GAP)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = panel
	local head = Widgets.create("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 72),
		LayoutOrder = 1,
		ZIndex = Z,
		Parent = panel,
	})
	local iconBox = box("IconBox", head)
	iconBox.BackgroundColor3 = Theme.price
	iconBox.Size = UDim2.fromOffset(72, 72)
	icon = Icons.holder(iconBox, 64)
	icon.Position = UDim2.fromOffset(4, 4)
	nameLabel = Widgets.label({
		Name = "WeaponName",
		Font = Theme.fontBold,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(84, 4),
		Size = UDim2.new(1, -84, 0, 30),
		ZIndex = Z,
		Parent = head,
	})
	classLabel = Widgets.label({
		Name = "Classes",
		TextSize = 20,
		TextColor3 = Theme.statLabel,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Position = UDim2.fromOffset(84, 36),
		Size = UDim2.new(1, -84, 0, 30),
		ZIndex = Z,
		Parent = head,
	})
	body = Widgets.label({
		Name = "Stats",
		RichText = true,
		TextSize = 19,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		ZIndex = Z,
		Parent = panel,
	})
	recycle = actionButton("Recycle", 3, actions.recycle)
	recycle.Text = ""
	recycleAmount = Widgets.label({
		Name = "Amount",
		Font = Theme.fontBold,
		TextSize = 22,
		Size = UDim2.new(1, -40, 1, 0),
		ZIndex = Z + 2,
		Parent = recycle,
	})
	local shard = Currency.mount(recycle, 22)
	shard.AnchorPoint = Vector2.new(1, 0.5)
	shard.Position = UDim2.new(1, -12, 0.5, 0)
	combine = actionButton("Combine", 4, actions.combine)
	combine.Text = "Combine"
	local cancel = actionButton("Cancel", 5, actions.cancel)
	cancel.Text = "Cancel"
	classColumn = Widgets.create("Frame", {
		Name = "ClassBonuses",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(CLASS_WIDTH, 0),
		ZIndex = Z,
		Parent = root,
	})
	Widgets.list(GAP).Parent = classColumn
end

local function classBox(classId: string, count: number, order: number)
	local class = Config.WeaponClasses.byId[classId]
	local frame = box(classId, classColumn)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.LayoutOrder = order
	Widgets.padding(10).Parent = frame
	local lines = { `<font color="{hex(Theme.text)}">{if class then class.displayName else classId}</font>` }
	if class then
		for n = Config.WeaponClasses.minCount, Config.WeaponClasses.maxCount do
			local bonus = class.bonuses[n]
			if bonus then
				local text = `({n}) {(string.gsub(UpgradeText.statLines(bonus), "\n", ", "))}`
				local active = n == math.min(count, Config.WeaponClasses.maxCount)
				table.insert(lines, `<font color="{hex(if active then Theme.text else INACTIVE)}">{text}</font>`)
			end
		end
	end
	Widgets.label({
		Name = "Bonus",
		RichText = true,
		TextSize = 19,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Text = table.concat(lines, "\n"),
		ZIndex = Z,
		Parent = frame,
	})
end

-- Shows the popup next to the weapon tile `shown.anchor`.
function WeaponInspect.show(shown: Shown)
	root.Visible = true
	Icons.draw(icon, "weapon", shown.id)
	nameLabel.Text = UpgradeText.weaponName(shown.id, shown.tier, shown.evolution)
	nameLabel.TextColor3 = if shown.tier > 1 then Theme.tiers[shown.tier] or Theme.text else Theme.text
	local classes, text = OfferText.weapon(shown.id, shown.tier, shown.sheet)
	classLabel.Text = string.gsub(classes, " · ", ", ")
	body.Text = text
	recycleAmount.Text = `Recycle   +{shown.sellPrice}`
	combine.Visible = shown.canMerge
	for _, child in classColumn:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local weapon = Config.Weapons[shown.id]
	local counts = WeaponClasses.counts(shown.weaponIds, shown.characterId)
	for order, classId in if weapon then weapon.classes else {} do
		classBox(classId, counts[classId] or 0, order)
	end
	-- Bottom right corner of the panel sits above the weapon tile, kept inside the screen.
	local origin, size = root.AbsolutePosition, root.AbsoluteSize
	local at, tile = shown.anchor.AbsolutePosition, shown.anchor.AbsoluteSize
	if not (origin and size and at and tile) then
		return -- not laid out yet (test mocks)
	end
	local x = math.clamp(at.X - origin.X + tile.X - WIDTH, 8, math.max(8, size.X - WIDTH - CLASS_WIDTH - 16))
	local height = math.max(panel.AbsoluteSize.Y, 360)
	local y = math.clamp(at.Y - origin.Y - height - 8, 8, math.max(8, size.Y - height - 8))
	panel.Position = UDim2.fromOffset(x, y)
	classColumn.Position = UDim2.fromOffset(x + WIDTH + GAP, y)
end

function WeaponInspect.hide()
	if root then
		root.Visible = false
	end
end

function WeaponInspect.isOpen(): boolean
	return root ~= nil and root.Visible
end

return table.freeze(WeaponInspect)
