--!strict
-- Draws fruits and crates on the arena floor (DESIGN.md section 3, since B6) from the server's Pickups events
-- (LootService): a glowing lantern fruit with a leaf, a dark wooden crate with a glowing brass band. Picked up they fly
-- into the player like orbs; left at the wave end they simply vanish. Lying ones are placed once; only flying ones move
-- each frame, together in one workspace:BulkMoveTo. Also shows a small chip under the timer with the team's bag
-- (OrbBag, ExperienceService) and the crates waiting for the end of the wave (CrateOffer, UpgradeService) while a run
-- is on. Since WP10 legendary crates: a bigger crimson crate with a gold band and a glow. The server decides every
-- pickup; this only shows it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local VisualKit = require(script.Parent.WeaponRenderer.VisualKit)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local FOLDER_NAME = "LanternfallPickups"
local FLY_SECONDS = 0.3
local CRATE, LEGENDARY = 2, 3 -- kinds in Net/Types.PickupEvents (1 = fruit)
local FRUIT_COLOR = Color3.fromRGB(255, 112, 64)
local LEAF_COLOR = Color3.fromRGB(96, 168, 92)
local WOOD_COLOR = Color3.fromRGB(92, 60, 40)
local BAND_COLOR = Color3.fromRGB(255, 196, 87) -- Theme.accent, the lantern yellow
local LEGENDARY_WOOD = Color3.fromRGB(120, 28, 36) -- crimson lacquer, the Legendary tier's red
local LEGENDARY_BAND = Color3.fromRGB(236, 188, 88)
local LEGENDARY_GLOW = Color3.fromRGB(255, 80, 80)
local CHIP_Y = 126 -- pixels from the top, under the HUD's timer panel

-- One pickup's parts and where each sits relative to the pickup's floor point.
type Visual = { parts: { BasePart }, offsets: { CFrame } }
type Pickup = { visual: Visual, kind: number, position: Vector3, yaw: number }
type Flight = { visual: Visual, kind: number, from: Vector3, yaw: number, userId: number, startedAt: number }

local PickupRenderer = {}

local floorY = Config.Map.arena.center.Y
local folder: Folder? = nil

local function partsOf(visual: Visual): { BasePart }
	return visual.parts
end

local fruitPool = VisualKit.objectPool(function(): Visual
	local fruit = VisualKit.part("Fruit", Enum.PartType.Ball, Vector3.one * 1.3, FRUIT_COLOR)
	local leaf =
		VisualKit.solid("Leaf", Enum.PartType.Block, Vector3.new(0.5, 0.12, 0.8), LEAF_COLOR, Enum.Material.Grass)
	return {
		parts = { fruit, leaf },
		offsets = { CFrame.new(0, 1.05, 0), CFrame.new(0.2, 1.75, 0) * CFrame.Angles(0, 0.6, 0.4) },
	}
end, partsOf)

local cratePool = VisualKit.objectPool(function(): Visual
	local box = VisualKit.solid("Crate", Enum.PartType.Block, Vector3.new(2, 1.6, 2), WOOD_COLOR, Enum.Material.Wood)
	local band = VisualKit.part("CrateBand", Enum.PartType.Block, Vector3.new(2.1, 0.25, 2.1), BAND_COLOR)
	return { parts = { box, band }, offsets = { CFrame.new(0, 0.8, 0), CFrame.new(0, 1.1, 0) } }
end, partsOf)

local legendaryPool = VisualKit.objectPool(function(): Visual
	local box = VisualKit.solid(
		"LegendaryCrate",
		Enum.PartType.Block,
		Vector3.new(2.8, 2.2, 2.8),
		LEGENDARY_WOOD,
		Enum.Material.Wood
	)
	local band = VisualKit.part("LegendaryBand", Enum.PartType.Block, Vector3.new(2.95, 0.35, 2.95), LEGENDARY_BAND)
	local glow = VisualKit.halo("LegendaryGlow", Enum.PartType.Ball, Vector3.one * 4.5, LEGENDARY_GLOW, 0.8)
	return {
		parts = { box, band, glow },
		offsets = { CFrame.new(0, 1.1, 0), CFrame.new(0, 1.5, 0), CFrame.new(0, 1.2, 0) },
	}
end, partsOf)

local pickups: { [number]: Pickup } = {}
local flights: { Flight } = {}
local bag = 0
local cratesWaiting = 0

local chipScreen: ScreenGui? = nil
local chipLabel: TextLabel? = nil

-- Reused lists for workspace:BulkMoveTo.
local partList: { BasePart } = {}
local cframeList: { CFrame } = {}

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

local function poolOf(kind: number)
	return if kind == LEGENDARY then legendaryPool elseif kind == CRATE then cratePool else fruitPool
end

local function place(visual: Visual, position: Vector3, yaw: number)
	local at = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	for index, part in visual.parts do
		table.insert(partList, part)
		table.insert(cframeList, at * visual.offsets[index])
	end
end

local function flushMoves()
	if #partList > 0 then
		workspace:BulkMoveTo(partList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(partList)
		table.clear(cframeList)
	end
end

local function rootPosition(userId: number): Vector3?
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function clear()
	for _, pickup in pickups do
		poolOf(pickup.kind):release(pickup.visual)
	end
	for _, flight in flights do
		poolOf(flight.kind):release(flight.visual)
	end
	table.clear(pickups)
	table.clear(flights)
end

local function onEvents(events: Types.PickupEvents)
	if typeof(events) ~= "table" then
		return
	end
	if events.reset then
		clear()
	end
	local dropped = events.dropped
	for i = 1, #dropped - 3, 4 do
		local id, x, z, kind = dropped[i], dropped[i + 1], dropped[i + 2], dropped[i + 3]
		if not pickups[id] then
			local pickup = {
				visual = poolOf(kind):acquire(getFolder()),
				kind = kind,
				position = Vector3.new(x, floorY, z),
				yaw = (id * 2.4) % (2 * math.pi), -- every crate turned a little differently
			}
			pickups[id] = pickup
			place(pickup.visual, pickup.position, pickup.yaw)
		end
	end
	flushMoves()
	local now = workspace:GetServerTimeNow()
	local collected = events.collected
	for i = 1, #collected - 1, 2 do
		local id, userId = collected[i], collected[i + 1]
		local pickup = pickups[id]
		if pickup then
			pickups[id] = nil
			if userId == 0 then
				poolOf(pickup.kind):release(pickup.visual)
			else
				table.insert(flights, {
					visual = pickup.visual,
					kind = pickup.kind,
					from = pickup.position,
					yaw = pickup.yaw,
					userId = userId,
					startedAt = now,
				})
			end
		end
	end
end

local function render()
	if #flights == 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	for i = #flights, 1, -1 do
		local flight = flights[i]
		local t = (now - flight.startedAt) / FLY_SECONDS
		local target = rootPosition(flight.userId)
		if t >= 1 or not target then
			poolOf(flight.kind):release(flight.visual)
			table.remove(flights, i)
		else
			local from = flight.from
			place(flight.visual, from + (target - from) * (t * t), flight.yaw)
		end
	end
	flushMoves()
end

local function updateChip()
	local screen, label = chipScreen, chipLabel
	if not (screen and label) then
		return
	end
	local state = RunStateController.get()
	local inRun = RunStateController.getView() == "Run" and state ~= nil and state.phase == "Running"
	local parts = {}
	if bag > 0 then
		table.insert(parts, `Bag {math.round(bag)}`)
	end
	if cratesWaiting > 0 then
		table.insert(parts, if cratesWaiting == 1 then "1 crate" else `{cratesWaiting} crates`)
	end
	screen.Enabled = inRun and #parts > 0
	label.Text = table.concat(parts, " · ")
end

local function buildChip()
	local screen = Widgets.screen("Loot", 0)
	local panel = Widgets.panel({
		Name = "LootChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, CHIP_Y),
		Size = UDim2.fromOffset(200, 0),
		Parent = screen,
	})
	chipLabel = Widgets.label({
		Name = "LootText",
		Font = Theme.fontBold,
		TextSize = 16,
		TextColor3 = Theme.accent,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = panel,
	})
	chipScreen = screen
end

-- Lifecycle -------------------------------------------------------------------------

function PickupRenderer.init()
	Net.onClient("Pickups", onEvents)
	Net.onClient("OrbBag", function(value: number)
		bag = if typeof(value) == "number" then value else 0
		updateChip()
	end)
	Net.onClient("CrateOffer", function(offer: Types.CrateOffer)
		cratesWaiting = if typeof(offer) == "table" and not offer.open then offer.pending else 0
		updateChip()
	end)
end

function PickupRenderer.start()
	buildChip()
	RunStateController.Changed:Connect(updateChip)
	updateChip()
	RunService.RenderStepped:Connect(render)
end

-- Queries ---------------------------------------------------------------------------

-- Fruits and crates lying on the floor and flying to a player (smoke test).
function PickupRenderer.getCounts(): (number, number)
	local lying = 0
	for _ in pickups do
		lying += 1
	end
	return lying, #flights
end

-- The text of the bag chip, "" while it is hidden (tests).
function PickupRenderer.getChipText(): string
	local screen, label = chipScreen, chipLabel
	return if screen and label and screen.Enabled then label.Text else ""
end

return PickupRenderer
