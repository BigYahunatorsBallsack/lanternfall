--!strict
-- Draws fruits and crates on the arena floor (DESIGN.md section 3, since B6) from the server's Pickups events
-- (LootService): sprites of the authored green fruit and the two outlined cartoon loot boxes. Picked up they fly
-- into the player like orbs; left at the wave end they simply vanish. Lying ones are placed once; only flying ones move
-- each frame, together in one workspace:BulkMoveTo. Also shows a small chip under the timer with the team's bag
-- (OrbBag, ExperienceService) while a run is on; crates waiting for the end of the wave are icons in the top-right
-- corner (PendingRewardsController). Legendary crates use a larger crimson and gold mesh with a glow. The server decides every
-- pickup; this only shows it.

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local VisualKit = require(script.Parent.WeaponRenderer.VisualKit)
local WorldSprite = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("WorldSprite")
)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local FOLDER_NAME = "LanternfallPickups"
local FLY_SECONDS = 0.3
local CRATE, LEGENDARY = 2, 3 -- kinds in Net/Types.PickupEvents (1 = fruit)
local LEGENDARY_GLOW = Color3.fromRGB(255, 80, 80)
local LEGENDARY_GLOW_STUDS = 5.4
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

local function pickupSprite(name: string): WorldSprite.Sprite
	local art = Config.Sprites.pickups[name]
	return WorldSprite.create({
		name = name,
		image = if art then art.image else "",
		studs = if art then art.studs else 2,
		ground = if art then art.ground or 0 else 0,
		center = if art then art.center else nil,
	})
end

local fruitPool = VisualKit.objectPool(function(): Visual
	return { parts = { pickupSprite("Fruit").anchor :: BasePart }, offsets = { CFrame.identity } }
end, partsOf)

local cratePool = VisualKit.objectPool(function(): Visual
	return { parts = { pickupSprite("Crate").anchor :: BasePart }, offsets = { CFrame.identity } }
end, partsOf)

local legendaryPool = VisualKit.objectPool(function(): Visual
	local glow = WorldSprite.glow("LegendaryGlow", LEGENDARY_GLOW_STUDS, LEGENDARY_GLOW)
	return {
		parts = { pickupSprite("LegendaryCrate").anchor :: BasePart, glow.anchor :: BasePart },
		-- a little behind the crate, so it shines around it
		offsets = { CFrame.identity, CFrame.new(0, 1.034, -0.3) },
	}
end, partsOf)

local function preloadImages()
	local probes: { Instance } = {}
	for _, art in Config.Sprites.pickups do
		local probe = Instance.new("ImageLabel")
		probe.Image = art.image
		table.insert(probes, probe)
	end
	pcall(function()
		ContentProvider:PreloadAsync(probes)
	end)
	for _, probe in probes do
		probe:Destroy()
	end
end

local pickups: { [number]: Pickup } = {}
local flights: { Flight } = {}
local bag = 0

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

local function place(visual: Visual, position: Vector3, _yaw: number)
	local at = CFrame.new(position)
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
		TextSize = 16 * Theme.hudTextScale,
		TextColor3 = Theme.accent,
		Size = UDim2.new(1, 0, 0, 18 * Theme.hudTextScale),
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
end

function PickupRenderer.start()
	buildChip()
	task.spawn(preloadImages)
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
