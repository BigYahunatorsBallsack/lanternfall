--!strict
-- The local player's stats (DESIGN.md section 13, Brotato direction since B2): keeps the Stats remote from
-- StatService and shows them as a panel at the right edge between waves (shop phase, next to the level-up cards and
-- the shop): every stat with its value, green above its start value, red below, Dodge with its cap. Read by the smoke
-- test (get).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local StatMath = require(Shared:WaitForChild("Util"):WaitForChild("StatMath"))

local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local PANEL_WIDTH = 230
local ROW_HEIGHT = 18

local StatsController = {}

local screen: ScreenGui
local values: { [string]: TextLabel } = {}
local sheet: Types.StatSheet = StatMath.baseSheet()
local baseSheet = StatMath.baseSheet()

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

local function render()
	if not screen then
		return
	end
	local state = RunStateController.get()
	screen.Enabled = RunStateController.getView() == "Run" and state ~= nil and state.phase == "Shop"
	for statId, label in values do
		local value = sheet[statId] or 0
		local base = baseSheet[statId] or 0
		label.Text = valueText(statId, value)
		label.TextColor3 = if value > base then Theme.success elseif value < base then Theme.danger else Theme.text
	end
end

local function build()
	screen = Widgets.screen("Stats", 1)
	local panel = Widgets.panel({
		Name = "Stats",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.56, 0),
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
			Parent = panel,
		})
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
	render()
end

-- Queries ---------------------------------------------------------------------------

-- The local player's stats as the server sent them last (smoke test).
function StatsController.get(): Types.StatSheet
	return sheet
end

return StatsController
