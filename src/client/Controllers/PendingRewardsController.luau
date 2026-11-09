--!strict
-- Top-right HUD indicator for what waits for the end of the wave (Brotato layout): one half transparent icon per
-- pending level-up (a head with a big green arrow; from 5 on one icon with the count) in the top row and one icon per collected crate below it, legendary
-- crates (open first) in their own crimson and gold box. Reads LevelUpOffer and CrateOffer (UpgradeService) and shows
-- only while a wave or the boss fight runs; the choices themselves open in LevelUpController. HUDController moves its
-- team panel and the phone timer below the indicator (getBottom). The server decides everything; this only shows it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local RIGHT = 64 -- pixels from the right edge: left of the settings button (SettingsController, 44 + 12 margin + 8)
-- Brotato 1.2.0.1 (main.tscn, ui_upgrade_to_process_element.tscn, UIUpgradeToProcessList): 80 pixel icons 24 pixels
-- from the top at 1080 pixels screen height, the level-up row drawn at half opacity, up to 4 equal icons and from the
-- 5th on a single icon with the count in its lower right corner (font 40).
local REFERENCE_HEIGHT = 1080
local TOP_PIXELS = 24
local LEVEL_ICON_PIXELS = 80
local LEVEL_OPACITY = 0.5
local MAX_LEVEL_ICONS = 4
local COUNT_TEXT_SHARE = 40 / 80 -- count text size as a share of the icon
local ICON_SIZE_PHONE = 38
local CRATE_BASE = 48 -- pixels at 720 pixels screen height, scaled with it (between 0.8 and 1.6 times)
local CRATE_SCALE = 1.35 -- crate icons are this much larger than that base (owner, 09.11.2026: crates look right)
local ROW_GAP = 4
local LEVEL_GAP = 4 -- Brotato's HBoxContainer default separation
local CRATE_GAP = 2
local MAX_ICONS = 6 -- crates per row; more are counted in a "+N" label left of the icons
local ARROW_GREEN = Color3.fromRGB(36, 230, 51)
local OUTLINE = Color3.new(0, 0, 0)
local FACE = Color3.new(1, 1, 1)

local PendingRewardsController = {}

-- Fires when the indicator's size or visibility changes (HUDController re-places its team panel).
PendingRewardsController.Changed = Signal.new()

local screen: ScreenGui? = nil
local holderFrame: Frame? = nil
local levelRow: Frame? = nil
local crateRow: Frame? = nil
local levels = 0
local crates = 0
local legendaryCrates = 0
local iconSize = LEVEL_ICON_PIXELS
local crateBase = CRATE_BASE
local top = TOP_PIXELS
local shownKey = ""

local function visibleNow(): boolean
	local state = RunStateController.get()
	return RunStateController.getView() == "Run"
		and state ~= nil
		and (state.phase == "Running" or state.phase == "Boss")
end

-- One plain frame of the level-up icon, in pixels of the icon.
local function piece(parent: Instance, name: string, props: { [string]: any }): Frame
	local frame = Widgets.create("Frame", {
		Name = name,
		BorderSizePixel = 0,
		Parent = parent,
	})
	for key, value in props do
		(frame :: any)[key] = value
	end
	return frame
end

-- A big up arrow behind the head (Brotato's upgrade icon layout): a square turned 45 degrees and cut at its middle
-- by a clipping frame makes the tip, a bar the shaft. `grow` pixels larger all round for the black outline.
local function drawArrow(parent: Instance, size: number, color: Color3, grow: number, layer: number)
	local center = 0.68 * size
	local half = 0.29 * size + grow * math.sqrt(2)
	local tipY = 0.04 * size - grow * math.sqrt(2)
	local baseY = 0.33 * size + grow
	local clip = piece(parent, "ArrowTip", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(center - half, tipY),
		Size = UDim2.fromOffset(half * 2, baseY - tipY),
		ZIndex = layer,
	})
	local side = half * math.sqrt(2)
	piece(clip, "Tip", {
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(half, half),
		Size = UDim2.fromOffset(side, side),
		Rotation = 45,
		ZIndex = layer,
	})
	local width = 0.12 * size + grow
	piece(parent, "ArrowShaft", {
		BackgroundColor3 = color,
		Position = UDim2.fromOffset(center - width, baseY - grow - 1),
		Size = UDim2.fromOffset(width * 2, 0.9 * size - baseY + grow * 2 + 1),
		ZIndex = layer,
	})
end

-- A round white head with two eyes in front of the arrow.
local function drawHead(parent: Instance, size: number, outline: number)
	local head = piece(parent, "Head", {
		BackgroundColor3 = FACE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0.38 * size, 0.6 * size),
		Size = UDim2.fromOffset(0.6 * size, 0.7 * size),
		Rotation = -18,
		ZIndex = 3,
	})
	Widgets.corner(UDim.new(0.5, 0)).Parent = head
	Widgets.create("UIStroke", { Color = OUTLINE, Thickness = outline, Parent = head })
	for index, x in { 0.3, 0.72 } do
		local eye = piece(head, `Eye{index}`, {
			BackgroundColor3 = OUTLINE,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromOffset(0.09 * size, 0.09 * size),
			ZIndex = 4,
		})
		Widgets.corner(UDim.new(0.5, 0)).Parent = eye
	end
	piece(head, "Mouth", {
		BackgroundColor3 = OUTLINE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.52, 0.64),
		Size = UDim2.fromOffset(0.14 * size, math.max(2, 0.035 * size)),
		Rotation = -8,
		ZIndex = 4,
	})
end

-- One pending level-up: head and green arrow, half transparent as a whole (CanvasGroup), with the count when more
-- than MAX_LEVEL_ICONS wait (Brotato).
local function levelIcon(order: number, count: number?): CanvasGroup
	local group = Widgets.create("CanvasGroup", {
		Name = `Level{order}`,
		BackgroundTransparency = 1,
		GroupTransparency = 1 - LEVEL_OPACITY,
		Size = UDim2.fromOffset(iconSize, iconSize),
		LayoutOrder = order,
	})
	local outline = math.max(2, math.floor(0.055 * iconSize + 0.5))
	drawArrow(group, iconSize, OUTLINE, outline, 1)
	drawArrow(group, iconSize, ARROW_GREEN, 0, 2)
	drawHead(group, iconSize, outline)
	if count then
		Widgets.label({
			Name = "Count",
			Text = tostring(count),
			Font = Theme.fontBold,
			TextSize = math.floor(iconSize * COUNT_TEXT_SHARE),
			TextColor3 = FACE,
			TextStrokeTransparency = 0,
			TextStrokeColor3 = OUTLINE,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.new(1, 0, COUNT_TEXT_SHARE, 0),
			ZIndex = 5,
			Parent = group,
		})
	end
	return group
end

local function crateSize(): number
	return math.floor(crateBase * CRATE_SCALE)
end

local function crateIcon(order: number, legendary: boolean): ImageLabel
	local art = Config.Sprites.pickups[if legendary then "LegendaryCrate" else "Crate"]
	return Widgets.create("ImageLabel", {
		Name = if legendary then `LegendaryCrate{order}` else `Crate{order}`,
		BackgroundTransparency = 1,
		Image = if art then art.image else "",
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(crateSize(), crateSize()),
		LayoutOrder = order,
	})
end

local function moreLabel(extra: number, height: number): TextLabel
	return Widgets.label({
		Name = "More",
		Text = `+{extra}`,
		Font = Theme.fontBold,
		TextSize = math.floor(iconSize * 0.55),
		TextColor3 = Theme.text,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Theme.stroke,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		LayoutOrder = 0,
	})
end

local function clear(row: Frame)
	for _, child in row:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function fillLevels(row: Frame)
	clear(row)
	if levels > MAX_LEVEL_ICONS then
		levelIcon(1, levels).Parent = row
		return
	end
	for i = 1, levels do
		levelIcon(i).Parent = row
	end
end

local function fillCrates(row: Frame)
	clear(row)
	local total = crates + legendaryCrates
	local shown = math.min(total, MAX_ICONS)
	if total > shown then
		moreLabel(total - shown, crateSize()).Parent = row
	end
	for i = 1, shown do
		crateIcon(i, i <= legendaryCrates).Parent = row -- legendary crates open first, so they come first
	end
end

local function rowCount(): number
	if not visibleNow() then
		return 0
	end
	return (if levels > 0 then 1 else 0) + (if crates + legendaryCrates > 0 then 1 else 0)
end

local function measure()
	local camera = workspace.CurrentCamera
	local area = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	if area.X < 700 then
		iconSize = ICON_SIZE_PHONE
		crateBase = ICON_SIZE_PHONE
	else
		iconSize = math.floor(LEVEL_ICON_PIXELS * area.Y / REFERENCE_HEIGHT)
		crateBase = math.floor(CRATE_BASE * math.clamp(area.Y / 720, 0.8, 1.6))
	end
	top = math.floor(TOP_PIXELS * area.Y / REFERENCE_HEIGHT)
end

local function refresh()
	local gui, holder, upper, bottom = screen, holderFrame, levelRow, crateRow
	if not (gui and holder and upper and bottom) then
		return
	end
	measure()
	local visible = visibleNow()
	local key = `{visible}:{levels}:{crates}:{legendaryCrates}:{iconSize}`
	if key == shownKey then
		return
	end
	shownKey = key
	gui.Enabled = visible and levels + crates + legendaryCrates > 0
	upper.Visible = levels > 0
	bottom.Visible = crates + legendaryCrates > 0
	upper.Size = UDim2.fromOffset(0, iconSize)
	bottom.Size = UDim2.fromOffset(0, crateSize())
	-- the crate row moves up when no level-up waits
	bottom.Position = UDim2.fromOffset(0, if levels > 0 then iconSize + ROW_GAP else 0)
	holder.Position = UDim2.new(1, -RIGHT, 0, top)
	fillLevels(upper)
	fillCrates(bottom)
	PendingRewardsController.Changed:Fire()
end

local function newRow(name: string, parent: Instance, gap: number): Frame
	local row = Widgets.create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		Parent = parent,
	})
	local layout = Widgets.list(gap, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Parent = row
	return row
end

local function build()
	local gui = Widgets.screen("PendingRewards", 0)
	local holder = Widgets.create("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -RIGHT, 0, top),
		Size = UDim2.fromOffset(0, 0),
		Parent = gui,
	})
	holderFrame = holder
	levelRow = newRow("PendingLevels", holder, LEVEL_GAP)
	crateRow = newRow("PendingCrates", holder, CRATE_GAP)
	screen = gui
end

-- Lifecycle -------------------------------------------------------------------------

function PendingRewardsController.init()
	Net.onClient("LevelUpOffer", function(offer: Types.LevelUpOffer)
		-- closed offers carry the choices waiting for the end of the wave
		levels = if typeof(offer) == "table" and not offer.open then math.max(0, offer.pending) else 0
		refresh()
	end)
	Net.onClient("CrateOffer", function(offer: Types.CrateOffer)
		local waiting = if typeof(offer) == "table" and not offer.open then math.max(0, offer.pending) else 0
		local legendary = if typeof(offer) == "table" then offer.legendaryPending else nil
		legendaryCrates = math.clamp(if typeof(legendary) == "number" then legendary else 0, 0, waiting)
		crates = waiting - legendaryCrates
		refresh()
	end)
end

function PendingRewardsController.start()
	build()
	RunStateController.Changed:Connect(function()
		if RunStateController.getView() ~= "Run" then
			levels, crates, legendaryCrates = 0, 0, 0 -- belongs to the run that ended
		end
		refresh()
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	refresh()
end

-- Queries ---------------------------------------------------------------------------

-- Pixels from the top of the screen to the indicator's lower edge, 0 while it is hidden (HUDController layout).
function PendingRewardsController.getBottom(): number
	local rows = rowCount()
	if rows == 0 then
		return 0
	end
	local height = (if levels > 0 then iconSize else 0) + (if crates + legendaryCrates > 0 then crateSize() else 0)
	return top + height + (rows - 1) * ROW_GAP
end

-- Level-ups, crates and legendary crates shown right now (tests).
function PendingRewardsController.getShown(): (number, number, number)
	if rowCount() == 0 then
		return 0, 0, 0
	end
	return levels, crates, legendaryCrates
end

return PendingRewardsController
