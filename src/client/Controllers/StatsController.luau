--!strict
-- The local player's stats (DESIGN.md section 13, Brotato direction since B2): keeps the Stats remote from
-- StatService and shows them as a panel at the right edge between waves (shop phase, next to the level-up cards and
-- the shop): every stat with its value, green above its start value, red below (the other way round for stats where
-- less is better), Dodge with its cap; since B4 the secondary stats of the shop and the enemies only while they are not
-- 0. On small screens the shop hides it behind a STATS button (setSuppressed, since B3). Since B5 a WEAPON CLASSES part
-- below lists the classes of the weapons carried with their count and current bonus (Util/WeaponClasses; the bonus is
-- already in the stats above). Read by the smoke test (get).

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
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local PANEL_WIDTH = 230
local ROW_HEIGHT = 18
local CLASS_TEXT_SIZE = 13

local StatsController = {}

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

local function valueText(statId: string, value: number): string
	local stat = Config.Stats.byId[statId]
	local rounded = math.round(value * 10) / 10
	local text = if rounded == math.floor(rounded) then tostring(rounded) else string.format("%.1f", rounded)
	if stat and stat.percent then
		text ..= "%"
	end
	if statId == "dodge" and value > Config.Stats.dodge.max then
		text ..= ` (max {Config.Stats.dodge.max}%)`
	end
	return text
end

-- "Edge 2: +1 Melee Damage, +1% Life Steal" or "Keen 1 (2 for a bonus)".
local function classLine(classId: string, count: number): string
	local class = Config.WeaponClasses.byId[classId]
	local name = if class then class.displayName else classId
	local bonus = WeaponClasses.bonus(classId, count)
	if not bonus then
		return `<font color="#9A93A8">{name} {count} ({Config.WeaponClasses.minCount} for a bonus)</font>`
	end
	return `<b>{name} {count}</b>: {(string.gsub(UpgradeText.statLines(bonus), "\n", ", "))}`
end

local function renderClasses()
	Widgets.clearRows(classList)
	local loadout = LoadoutController.getLocal()
	local ids = {}
	for _, weapon in if loadout then loadout.weapons else {} do
		table.insert(ids, weapon.id)
	end
	local carried = WeaponClasses.carried(ids)
	classTitle.Visible = #carried > 0
	for index, entry in carried do
		Widgets.label({
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
	for statId, label in values do
		local value = sheet[statId] or 0
		local base = baseSheet[statId] or 0
		local stat = Config.Stats.byId[statId]
		local better = if stat and stat.inverted then value < base else value > base
		local worse = if stat and stat.inverted then value > base else value < base
		label.Text = valueText(statId, value)
		label.TextColor3 = if better then Theme.success elseif worse then Theme.danger else Theme.text
		rows[statId].Visible = not (stat and stat.hideWhenZero and math.abs(value) < 1e-9)
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
	Widgets.label({
		Name = "Title",
		Text = "STATS",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = panel,
	})
	for index, stat in Config.Stats.order do
		local row = Widgets.create("Frame", {
			Name = stat.id,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			LayoutOrder = index,
			Visible = not stat.hideWhenZero,
			Parent = panel,
		})
		rows[stat.id] = row
		Widgets.label({
			Name = "Label",
			Text = stat.displayName,
			TextSize = 15,
			TextColor3 = Theme.textDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.62, 1),
			Parent = row,
		})
		values[stat.id] = Widgets.label({
			Name = "Value",
			TextSize = 15,
			Font = Theme.fontBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.38, 1),
			Parent = row,
		})
	end
	local after = #Config.Stats.order
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
end

-- Lifecycle -------------------------------------------------------------------------

function StatsController.init()
	Net.onClient("Stats", function(newSheet: Types.StatSheet)
		sheet = newSheet
		render()
	end)
end

function StatsController.start()
	build()
	RunStateController.Changed:Connect(render)
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
