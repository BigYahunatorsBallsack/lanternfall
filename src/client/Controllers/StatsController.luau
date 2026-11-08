--!strict
-- The local player's stats (DESIGN.md section 13, Brotato direction since B2): keeps the Stats remote from
-- StatService and shows them as a panel at the right edge between waves (shop phase, next to the level-up cards and
-- the shop): every stat with its value, green above its start value, red below (the other way round for stats where
-- less is better), Dodge with its cap; since B4 the secondary stats of the shop and the enemies only while they are not
-- 0. On small screens the shop hides it behind a STATS button (setSuppressed, since B3). Since B5 a WEAPON CLASSES part
-- below lists the classes of the weapons carried with their count and current bonus (Util/WeaponClasses; the bonus is
-- already in the stats above). Since Paket 14 a PRIMARY / SECONDARY switch in the title row (Brotato's two stat pages;
-- the secondary page lists the secondary stats that are not 0), tooltips that say what a stat does with its value
-- (Util/TooltipText) and class lines with their progress ("Edge 2/6", the bonus of every count in the tooltip).
-- Read by the smoke test (get).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local StatMath = require(Shared:WaitForChild("Util"):WaitForChild("StatMath"))
local UpgradeText = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeText"))
local WeaponClasses = require(Shared:WaitForChild("Util"):WaitForChild("WeaponClasses"))

local LoadoutController = require(script.Parent.LoadoutController)
local RunStateController = require(script.Parent.RunStateController)
local Icons = require(script.Parent.Parent.UI.Icons)
local Theme = require(script.Parent.Parent.UI.Theme)
local Tooltip = require(script.Parent.Parent.UI.Tooltip)
local TooltipText = require(Shared:WaitForChild("Util"):WaitForChild("TooltipText"))
local Widgets = require(script.Parent.Parent.UI.Widgets)

local PANEL_WIDTH = 274
local ROW_HEIGHT = 22
local CLASS_TEXT_SIZE = 13
local PRIMARY_ORDER = {
	"maxHp",
	"hpRegen",
	"lifeSteal",
	"damage",
	"meleeDamage",
	"rangedDamage",
	"elementalDamage",
	"attackSpeed",
	"critChance",
	"engineering",
	"range",
	"armor",
	"dodge",
	"speed",
	"luck",
	"harvesting",
}

local ProgressController = require(script.Parent.ProgressController)
local ShopLayout = require(script.Parent.Parent.UI.ShopLayout)
local Signal = require(Shared.Util.Signal)
local StatsController = {}
StatsController.Changed = Signal.new()

local MARGIN = 12

local screen: ScreenGui
local panel: Frame
local suppressed = false
local values: { [string]: TextLabel } = {}
local rows: { [string]: Frame } = {}
local sheet: Types.StatSheet = StatMath.baseSheet()
local baseSheet = StatMath.baseSheet()
local classTitle: TextLabel
local classList: Frame
local page: "Primary" | "Secondary" = "Primary" -- Paket 14
local pageButton: TextButton
local secondaryButton: TextButton
local levelValue: TextLabel
local emptyLabel: TextLabel
local resizePanel: (() -> ())? = nil

local function valueText(statId: string, value: number): string
	local rounded = math.round(value * 100) / 100
	local text = if rounded == math.floor(rounded)
		then tostring(rounded)
		else (string.format("%.2f", rounded):gsub("0+$", ""))
	local cap = if (sheet.dodgeCap or 0) > 0 then sheet.dodgeCap else Config.Stats.dodge.max
	if statId == "dodge" and value > cap then
		text ..= ` (max {cap}%)`
	end
	return text
end

-- "Edge 2/6: +1 Melee Damage, +1% Life Steal" or "Keen 1/6 (2 for a bonus)".
local function classLine(classId: string, count: number): string
	local class = Config.WeaponClasses.byId[classId]
	local name = if class then class.displayName else classId
	local progress = `{count}/{Config.WeaponClasses.maxCount}`
	local bonus = WeaponClasses.bonus(classId, count)
	if not bonus then
		return `<font color="#CCCAB9">{name} {progress} ({Config.WeaponClasses.minCount} for a bonus)</font>`
	end
	return `<b>{name} {progress}</b>: {(string.gsub(UpgradeText.statLines(bonus), "\n", ", "))}`
end

local function renderClasses()
	Widgets.clearRows(classList)
	local loadout = LoadoutController.getLocal()
	local ids = {}
	for _, weapon in if loadout then loadout.weapons else {} do
		table.insert(ids, weapon.id)
	end
	local me = RunStateController.getLocalPlayer()
	local carried = WeaponClasses.carried(ids, if me then me.classId else nil)
	classTitle.Visible = #carried > 0 and page == "Secondary"
	classList.Visible = page == "Secondary"
	for index, entry in carried do
		local classId, count = entry.id, entry.count
		local row = Widgets.label({
			Name = entry.id,
			Text = classLine(entry.id, entry.count),
			RichText = true,
			TextSize = CLASS_TEXT_SIZE,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			LayoutOrder = index,
			Parent = classList,
		})
		Tooltip.attach(row, function()
			return TooltipText.weaponClass(classId, count)
		end)
	end
end

local function render()
	if not screen then
		return
	end
	local state = RunStateController.get()
	screen.Enabled = not suppressed and RunStateController.getView() == "Run" and state ~= nil and state.phase == "Shop"
	if screen.Enabled then
		renderClasses()
	end
	local progress = ProgressController.getTeam()
	levelValue.Text = tostring(if progress then progress.level else 0)
	local anySecondary = false
	for statId, label in values do
		local value = sheet[statId] or 0
		local base = baseSheet[statId] or 0
		local stat = Config.Stats.byId[statId]
		local better = if stat and stat.inverted then value < base else value > base
		local worse = if stat and stat.inverted then value > base else value < base
		label.Text = valueText(statId, value)
		label.TextColor3 = if better then Theme.success elseif worse then Theme.danger else Theme.text
		local caption = rows[statId]:FindFirstChild("Label") :: TextLabel
		caption.TextColor3 = label.TextColor3
		local primary = stat == nil or stat.primary
		local hidden = stat ~= nil and stat.hideWhenZero and math.abs(value) < 1e-9
		rows[statId].Visible = if page == "Primary" then primary else not primary and not hidden
		if rows[statId].Visible and not primary then
			anySecondary = true
		end
	end
	emptyLabel.Visible = page == "Secondary" and not anySecondary
	pageButton.BackgroundTransparency = if page == "Primary" then 1 else 0
	secondaryButton.BackgroundTransparency = if page == "Secondary" then 1 else 0
	if resizePanel then
		resizePanel()
	end
end

local function build()
	screen = Widgets.screen("Stats", 1)
	panel = Widgets.panel({
		Name = "Stats",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -MARGIN, 0.56, 0),
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		Parent = screen,
	})
	Widgets.list(2).Parent = panel
	local titleRow = Widgets.create("Frame", {
		Name = "TitleRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 84),
		LayoutOrder = 0,
		Parent = panel,
	})
	Widgets.label({
		Name = "Title",
		Text = "Stats",
		TextSize = 28,
		Font = Theme.fontBold,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 38),
		Parent = titleRow,
	})
	-- Paket 14: Brotato's primary and secondary stat pages
	pageButton = Widgets.button({
		Name = "Page",
		Text = "Primary",
		TextSize = 18,
		Font = Theme.font,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(0.5, -2, 0, 34),
		Parent = titleRow,
	}, function()
		StatsController.setPage("Primary")
	end)
	pageButton.Outline.Thickness = 0
	secondaryButton = Widgets.button({
		Name = "SecondaryPage",
		Text = "Secondary",
		Font = Theme.font,
		TextSize = 18,
		Position = UDim2.new(0.5, 2, 0, 48),
		Size = UDim2.new(0.5, -2, 0, 34),
		Parent = titleRow,
	}, function()
		StatsController.setPage("Secondary")
	end)
	secondaryButton.Outline.Thickness = 0
	local levelRow = Widgets.create("Frame", {
		Name = "CurrentLevel",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = 1,
		Parent = panel,
	})
	local levelIcon = Icons.holder(levelRow, 20)
	Icons.draw(levelIcon, "stat", "xpGain")
	Widgets.label({
		Name = "Label",
		Text = "Current Level",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -65, 1, 0),
		Parent = levelRow,
	})
	levelValue = Widgets.label({
		Name = "Value",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -38, 0, 0),
		Size = UDim2.new(0, 38, 1, 0),
		Parent = levelRow,
	})
	for index, stat in Config.Stats.order do
		local row = Widgets.create("Frame", {
			Name = stat.id,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			LayoutOrder = (table.find(PRIMARY_ORDER, stat.id) or (100 + index)) + 1,
			Visible = stat.primary,
			Parent = panel,
		})
		rows[stat.id] = row
		local icon = Icons.holder(row, 20)
		icon.Position = UDim2.fromOffset(0, 1)
		Icons.draw(icon, "stat", stat.id)
		local statId = stat.id
		Tooltip.attach(row, function()
			return TooltipText.stat(statId, sheet[statId] or 0, sheet)
		end)
		Widgets.label({
			Name = "Label",
			Text = (if stat.percent then "% " else "") .. stat.displayName,
			TextSize = 16,
			TextColor3 = Theme.textDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(28, 0),
			Size = UDim2.new(1, -66, 1, 0),
			Parent = row,
		})
		values[stat.id] = Widgets.label({
			Name = "Value",
			TextSize = 16,
			Font = Theme.font,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(38, ROW_HEIGHT),
			Parent = row,
		})
	end
	local after = #Config.Stats.order + 2
	emptyLabel = Widgets.label({
		Name = "NoSecondary",
		Text = "None yet: secondary stats come from items.",
		TextSize = 14,
		TextColor3 = Theme.textDim,
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = after,
		Parent = panel,
	})
	classTitle = Widgets.label({
		Name = "ClassesTitle",
		Text = "WEAPON CLASSES",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = after + 1,
		Visible = false,
		Parent = panel,
	})
	classList = Widgets.create("Frame", {
		Name = "Classes",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		LayoutOrder = after + 2,
		Parent = panel,
	})
	Widgets.list(1).Parent = classList
	Widgets.unscaled(panel)
	panel:FindFirstChildOfClass("UIStroke").Thickness = 0
	panel:FindFirstChildOfClass("UIPadding"):Destroy()
	local scale = Widgets.create("UIScale", { Parent = panel })
	local contents = Widgets.create("ScrollingFrame", {
		Name = "StatsContent",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 1, -28),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		Parent = panel,
	})
	for _, child in panel:GetChildren() do
		if child ~= contents and (child:IsA("GuiObject") or child:IsA("UIListLayout")) then
			child.Parent = contents
			if child:IsA("UIListLayout") then
				child.VerticalAlignment = Enum.VerticalAlignment.Top
			end
		end
	end
	local function resize()
		local area = screen.AbsoluteSize
		if typeof(area) ~= "Vector2" or area.X <= 0 then
			area = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
		end
		local layout = ShopLayout.measure(area)
		local compact = layout.compact
		local choosing = require(script.Parent.LevelUpController).isOpen()
		scale.Scale = layout.scale
		panel.AutomaticSize = Enum.AutomaticSize.None
		panel.AnchorPoint = Vector2.new(if compact then 0.5 else 0, 0)
		panel.Position = if compact
			then UDim2.new(0.5, 0, 0, 76)
			else UDim2.fromOffset(layout.statsX * layout.scale, (if choosing then 126 else 16) * layout.scale)
		panel.Size = UDim2.fromOffset(
			if compact then math.min(520, area.X - 24) else layout.statsWidth,
			if compact then math.max(120, area.Y - 158) else layout.statsHeight
		)
	end
	resizePanel = resize
	resize()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	end
end

-- Lifecycle -------------------------------------------------------------------------

function StatsController.init()
	Net.onClient("Stats", function(newSheet: Types.StatSheet)
		sheet = newSheet
		render()
		StatsController.Changed:Fire(newSheet)
	end)
end

function StatsController.start()
	build()
	RunStateController.Changed:Connect(render)
	require(script.Parent.LevelUpController).Changed:Connect(render)
	ProgressController.TeamChanged:Connect(render)
	LoadoutController.Changed:Connect(function(userId: number)
		if userId == Players.LocalPlayer.UserId then
			render()
		end
	end)
	render()
end

-- Commands --------------------------------------------------------------------------

-- Hides the panel even between waves (the shop on a small screen) or lets it show again.
function StatsController.setSuppressed(value: boolean)
	if suppressed ~= value then
		suppressed = value
		render()
	end
end

-- Shows the primary or the secondary stats (Paket 14).
function StatsController.setPage(value: "Primary" | "Secondary")
	page = value
	render()
end

-- Queries ---------------------------------------------------------------------------

-- Screen pixels the panel takes at the right edge, margins included (the shop keeps clear of them).
function StatsController.reservedWidth(): number
	local uiScale = panel and panel:FindFirstChildOfClass("UIScale")
	local scale = if uiScale then uiScale.Scale else 1
	return PANEL_WIDTH * scale + 2 * MARGIN
end

-- The local player's stats as the server sent them last (smoke test).
function StatsController.get(): Types.StatSheet
	return sheet
end

return StatsController
