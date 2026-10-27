--!strict
-- Elite chests on the client (DESIGN.md section 8): draws every chest from the Chests remote as a glowing box with a
-- light beam, points at chests off screen with arrows at the screen edge and shows the local player's reward when a
-- chest opens (ChestOpened). Active only while the local player is in a running run (RunStateController). The server
-- (LootService) decides who opens a chest and what is inside.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local UpgradeText = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeText"))

local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local VisualKit = require(script.Parent.WeaponRenderer.VisualKit)

local FOLDER_NAME = "LanternfallChests"
local BOX_COLOR = Color3.fromRGB(120, 72, 30)
local GOLD_COLOR = Color3.fromRGB(255, 196, 87)
local BOX_SIZE = Vector3.new(2.6, 1.8, 1.8)
local BAND_SIZE = Vector3.new(2.7, 0.35, 1.9)
local BEAM_WIDTH = 0.6
local BEAM_HEIGHT = 26 -- studs, visible from far away with the top-down camera
local BEAM_TRANSPARENCY = 0.55
local LIGHT_RANGE = 16
local LIGHT_BRIGHTNESS = 3
local SPIN_PER_SECOND = 1.2 -- radians
local BOB_HEIGHT = 0.3
local BOB_SPEED = 3
local ARROW_MARGIN = 40 -- pixels from the screen edge
local ARROW_SIZE = 44
local BANNER_SECONDS = 3
local BANNER_FADE_SECONDS = 0.4

type Drawn = { model: Model, box: BasePart, band: BasePart, beam: BasePart, arrow: TextLabel }

local ChestController = {}

local chests: { [number]: Types.ChestInfo } = {}
local drawn: { [number]: Drawn } = {}
local enabled = false
local folder: Folder? = nil
local screen: ScreenGui? = nil
local floorY = Config.Map.arena.center.Y

local function getFolder(): Folder
	local current = folder
	if current then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = workspace
	folder = created
	return created
end

local function build(): Drawn
	local model = Instance.new("Model")
	model.Name = "Chest"
	local box = VisualKit.part("Box", Enum.PartType.Block, BOX_SIZE, BOX_COLOR)
	box.Material = Enum.Material.SmoothPlastic
	box.Parent = model
	local band = VisualKit.part("Band", Enum.PartType.Block, BAND_SIZE, GOLD_COLOR)
	band.Parent = model
	local beam =
		VisualKit.part("Beam", Enum.PartType.Block, Vector3.new(BEAM_WIDTH, BEAM_HEIGHT, BEAM_WIDTH), GOLD_COLOR)
	beam.Transparency = BEAM_TRANSPARENCY
	beam.Parent = model
	local light = Instance.new("PointLight")
	light.Color = GOLD_COLOR
	light.Range = LIGHT_RANGE
	light.Brightness = LIGHT_BRIGHTNESS
	light.Parent = box
	local arrow = Widgets.label({
		Name = "ChestArrow",
		Text = ">", -- plain ASCII, every font has it
		Font = Theme.fontBold,
		TextColor3 = Theme.accent,
		TextSize = ARROW_SIZE,
		Size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		Parent = screen,
	})
	model.Parent = getFolder()
	return { model = model, box = box, band = band, beam = beam, arrow = arrow }
end

local function destroy(id: number)
	local entry = drawn[id]
	if entry then
		entry.model:Destroy()
		entry.arrow:Destroy()
		drawn[id] = nil
	end
end

local function sync()
	for id in drawn do
		if not (enabled and chests[id]) then
			destroy(id)
		end
	end
	if not enabled then
		return
	end
	for id in chests do
		if not drawn[id] then
			drawn[id] = build()
		end
	end
end

-- Puts the arrow of a chest off screen on the screen edge, pointing at it.
local function placeArrow(arrow: TextLabel, position: Vector3)
	local camera = workspace.CurrentCamera
	if not camera then
		arrow.Visible = false
		return
	end
	local point, onScreen = camera:WorldToViewportPoint(position)
	local viewport = camera.ViewportSize
	if onScreen and point.X >= 0 and point.X <= viewport.X and point.Y >= 0 and point.Y <= viewport.Y then
		arrow.Visible = false
		return
	end
	local cx, cy = viewport.X / 2, viewport.Y / 2
	local dx, dy = point.X - cx, point.Y - cy
	if point.Z < 0 then -- behind the camera: the projection is mirrored
		dx, dy = -dx, -dy
	end
	local halfW, halfH = cx - ARROW_MARGIN, cy - ARROW_MARGIN
	local scale = math.min(halfW / math.max(math.abs(dx), 1e-3), halfH / math.max(math.abs(dy), 1e-3))
	arrow.Position = UDim2.fromOffset(cx + dx * scale, cy + dy * scale)
	arrow.Rotation = math.deg(math.atan2(dy, dx)) -- ">" points right at rotation 0
	arrow.Visible = true
end

local function render()
	if not enabled then
		return
	end
	local now = os.clock()
	for id, entry in drawn do
		local chest = chests[id]
		if not chest then
			continue
		end
		local y = floorY + BOX_SIZE.Y / 2 + BOB_HEIGHT * (1 + math.sin(now * BOB_SPEED + id))
		local base = CFrame.new(chest.x, y, chest.z) * CFrame.Angles(0, now * SPIN_PER_SECOND, 0)
		entry.box.CFrame = base
		entry.band.CFrame = base * CFrame.new(0, BOX_SIZE.Y * 0.2, 0)
		entry.beam.CFrame = CFrame.new(chest.x, floorY + BEAM_HEIGHT / 2, chest.z)
		placeArrow(entry.arrow, Vector3.new(chest.x, floorY, chest.z))
	end
end

local function showBanner(title: string, detail: string)
	local parent = screen
	if not parent then
		return
	end
	local old = parent:FindFirstChild("ChestBanner")
	if old then
		old:Destroy()
	end
	local banner = Widgets.panel({
		Name = "ChestBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(420, 0),
		Parent = parent,
	})
	Widgets.list(4).Parent = banner
	local labels = {
		Widgets.label({ Text = "CHEST", Font = Theme.fontBold, TextColor3 = Theme.textDim, LayoutOrder = 1 }),
		Widgets.label({
			Text = title,
			Font = Theme.fontBold,
			TextSize = Theme.titleSize,
			Size = UDim2.new(1, 0, 0, Theme.titleSize + 6),
			TextColor3 = Theme.accent,
			LayoutOrder = 2,
		}),
		Widgets.label({ Text = detail, TextColor3 = Theme.text, LayoutOrder = 3 }),
	}
	for _, label in labels do
		label.Parent = banner
	end
	task.delay(BANNER_SECONDS, function()
		if not banner.Parent then
			return
		end
		local info = TweenInfo.new(BANNER_FADE_SECONDS)
		TweenService:Create(banner, info, { BackgroundTransparency = 1 }):Play()
		for _, label in labels do
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		end
		task.wait(BANNER_FADE_SECONDS)
		banner:Destroy()
	end)
end

local function onOpened(opened: Types.ChestOpened)
	if not enabled then
		return
	end
	for _, entry in opened.rewards do
		if entry.userId == Players.LocalPlayer.UserId then
			showBanner(UpgradeText.chestReward(entry.reward))
			return
		end
	end
end

local function setEnabled(value: boolean)
	if value == enabled then
		return
	end
	enabled = value
	if screen then
		screen.Enabled = value
	end
	if not value then
		table.clear(chests)
	end
	sync()
end

-- Lifecycle -------------------------------------------------------------------------

function ChestController.init()
	Net.onClient("Chests", function(list: { Types.ChestInfo })
		table.clear(chests)
		for _, chest in list do
			chests[chest.id] = chest
		end
		sync()
	end)
	Net.onClient("ChestOpened", onOpened)
	RunStateController.Changed:Connect(function()
		setEnabled(RunStateController.getView() == "Run")
	end)
end

function ChestController.start()
	screen = Widgets.screen("Chests", 4)
	setEnabled(RunStateController.getView() == "Run")
	RunService.RenderStepped:Connect(render)
end

-- Queries ---------------------------------------------------------------------------

-- Chests this client knows about.
function ChestController.getCount(): number
	local count = 0
	for _ in chests do
		count += 1
	end
	return count
end

return ChestController
