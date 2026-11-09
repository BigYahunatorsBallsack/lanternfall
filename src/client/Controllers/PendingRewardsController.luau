--!strict
-- Top-right HUD indicator for what waits for the end of the wave (Brotato layout): one icon per pending level-up
-- (the local character's head with a green arrow) in the top row and one icon per collected crate below it, legendary
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
local Icons = require(script.Parent.Parent.UI.Icons)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local RIGHT = 64 -- pixels from the right edge: left of the settings button (SettingsController, 44 + 12 margin + 8)
local TOP = 12
-- Pixels at 720 pixels screen height, scaled with the height. Brotato's icons are about 6.5 % of the screen height
-- (owner's screenshot, 08.11.2026); 38 and 30 before.
local ICON_SIZE = 48
local ICON_SIZE_PHONE = 38
local CRATE_SCALE = 1.35 -- crate icons are this much larger than the level-up heads (owner, 09.11.2026)
local ROW_GAP = 4
local ICON_GAP = 2
local MAX_ICONS = 6 -- per row; more are counted in a "+N" label left of the icons
local ARROW_GREEN = Color3.fromRGB(122, 222, 84)

local PendingRewardsController = {}

-- Fires when the indicator's size or visibility changes (HUDController re-places its team panel).
PendingRewardsController.Changed = Signal.new()

local screen: ScreenGui? = nil
local levelRow: Frame? = nil
local crateRow: Frame? = nil
local levels = 0
local crates = 0
local legendaryCrates = 0
local iconSize = ICON_SIZE
local shownKey = ""

local function visibleNow(): boolean
	local state = RunStateController.get()
	return RunStateController.getView() == "Run"
		and state ~= nil
		and (state.phase == "Running" or state.phase == "Boss")
end

local function localClassId(): string
	local info = RunStateController.getLocalPlayer()
	return if info then info.classId else ""
end

-- A green up arrow drawn from frames (shaft and two head strokes) in the icon's top-right corner.
local function drawArrow(parent: Frame)
	local holder = Widgets.create("Frame", {
		Name = "Arrow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1.08, -0.06),
		Size = UDim2.fromScale(0.5, 0.62),
		ZIndex = 3,
		Parent = parent,
	})
	local function stroke(name: string, x: number, y: number, w: number, h: number, turn: number)
		local part = Widgets.create("Frame", {
			Name = name,
			BackgroundColor3 = ARROW_GREEN,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			Rotation = turn,
			ZIndex = 3,
			Parent = holder,
		})
		Widgets.corner(UDim.new(0.5, 0)).Parent = part
		Widgets.create("UIStroke", { Color = Theme.stroke, Thickness = 2, Parent = part })
	end
	stroke("Shaft", 0.5, 0.6, 0.26, 0.74, 0)
	stroke("HeadLeft", 0.33, 0.3, 0.26, 0.56, -42)
	stroke("HeadRight", 0.67, 0.3, 0.26, 0.56, 42)
end

local function levelIcon(order: number, classId: string): Frame
	local frame = Widgets.create("Frame", {
		Name = `Level{order}`,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(iconSize, iconSize),
		LayoutOrder = order,
	})
	if classId ~= "" then
		-- the whole figure, like Brotato's icon; the head crop cut the body off at the bottom (owner, 09.11.2026)
		Icons.draw(frame, "characterBadge", classId)
	end
	drawArrow(frame)
	return frame
end

local function crateSize(): number
	return math.floor(iconSize * CRATE_SCALE)
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
	local classId = localClassId()
	local shown = math.min(levels, MAX_ICONS)
	if levels > shown then
		moreLabel(levels - shown, iconSize).Parent = row
	end
	for i = 1, shown do
		levelIcon(i, classId).Parent = row
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
	else
		iconSize = math.floor(ICON_SIZE * math.clamp(area.Y / 720, 0.8, 1.6))
	end
end

local function refresh()
	local gui, top, bottom = screen, levelRow, crateRow
	if not (gui and top and bottom) then
		return
	end
	measure()
	local visible = visibleNow()
	local key = `{visible}:{levels}:{crates}:{legendaryCrates}:{iconSize}:{localClassId()}`
	if key == shownKey then
		return
	end
	shownKey = key
	gui.Enabled = visible and levels + crates + legendaryCrates > 0
	top.Visible = levels > 0
	bottom.Visible = crates + legendaryCrates > 0
	top.Size = UDim2.fromOffset(0, iconSize)
	bottom.Size = UDim2.fromOffset(0, crateSize())
	-- the crate row moves up when no level-up waits
	bottom.Position = UDim2.fromOffset(0, if levels > 0 then iconSize + ROW_GAP else 0)
	fillLevels(top)
	fillCrates(bottom)
	PendingRewardsController.Changed:Fire()
end

local function newRow(name: string, parent: Instance): Frame
	local row = Widgets.create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		Parent = parent,
	})
	local layout = Widgets.list(ICON_GAP, Enum.FillDirection.Horizontal)
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
		Position = UDim2.new(1, -RIGHT, 0, TOP),
		Size = UDim2.fromOffset(0, 0),
		Parent = gui,
	})
	levelRow = newRow("PendingLevels", holder)
	crateRow = newRow("PendingCrates", holder)
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
	return TOP + height + (rows - 1) * ROW_GAP
end

-- Level-ups, crates and legendary crates shown right now (tests).
function PendingRewardsController.getShown(): (number, number, number)
	if rowCount() == 0 then
		return 0, 0, 0
	end
	return levels, crates, legendaryCrates
end

return PendingRewardsController
