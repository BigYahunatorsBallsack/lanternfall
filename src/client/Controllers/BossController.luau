--!strict
-- The boss on screen (DESIGN.md section 7, WP10; since part 2 also the champion of an elite wave): a big HP bar at
-- the top with its name and phase (BossState from BossService), the warnings of its attacks on the floor
-- (BossTelegraphs: red circles that fill up and red lines that show a dash or slash, until they strike) and the
-- embers circling it in a phase with an orbit (Config.Enemies.bosses). The server decides every hit; this only shows
-- it. Uses EnemyRenderer for where the boss stands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Enemies = require(Shared:WaitForChild("Config"):WaitForChild("Enemies"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local EnemyRenderer = require(script.Parent.EnemyRenderer)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local VisualKit = require(script.Parent.WeaponRenderer.VisualKit)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local FOLDER_NAME = "LanternfallBoss"
local WARN_COLOR = Color3.fromRGB(230, 40, 48)
local FLASH_COLOR = Color3.fromRGB(255, 220, 200)
local EMBER_COLOR = Color3.fromRGB(255, 140, 50)
local DISC_HEIGHT = 0.1 -- studs
local EDGE_TRANSPARENCY = 0.55 -- the outline of a warning
local FILL_TRANSPARENCY = 0.35 -- the inner disc that grows until it strikes
local FLASH_SECONDS = 0.18 -- a warning flashes this long when it strikes
local POOL_COLOR = Color3.fromRGB(120, 200, 60) -- WP10 part 2: mud and acid pools that stay a while
local POOL_TRANSPARENCY = 0.45
local BAR_Y = 158 -- pixels from the top, under the loot chip
local BAR_WIDTH = 420
local BAR_HEIGHT = 16
local MAX_TELEGRAPHS = 160 -- more at once are not drawn (performance budget)

type Telegraph = { info: Types.BossTelegraph, edge: BasePart, fill: BasePart }

local BossController = {}

local floorY = Config.Map.arena.center.Y
local folder: Folder? = nil
local bosses: { Types.BossInfo } = {}
local telegraphs: { Telegraph } = {}
local embers: { BasePart } = {}

local screen: ScreenGui? = nil
local nameLabel: TextLabel? = nil
local phaseLabel: TextLabel? = nil
local barFill: Frame? = nil

-- A boss or (since WP10 part 2) a champion of an elite wave.
local function kindOf(bossId: string): Enemies.Enemy?
	return Config.Enemies.bosses[bossId] or Config.Enemies.champions[bossId]
end

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

local discPool = VisualKit.pool(function(): BasePart
	return VisualKit.halo("BossWarning", Enum.PartType.Cylinder, Vector3.new(DISC_HEIGHT, 1, 1), WARN_COLOR, 1)
end)
local stripPool = VisualKit.pool(function(): BasePart
	return VisualKit.halo("BossWarningLine", Enum.PartType.Block, Vector3.new(1, DISC_HEIGHT, 1), WARN_COLOR, 1)
end)
local emberPool = VisualKit.pool(function(): BasePart
	return VisualKit.part("BossEmber", Enum.PartType.Ball, Vector3.one, EMBER_COLOR)
end)

-- HP bar -----------------------------------------------------------------------------

local function buildBar()
	local gui = Widgets.screen("Boss", 1)
	local panel = Widgets.panel({
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, BAR_Y),
		Size = UDim2.fromOffset(BAR_WIDTH, 0),
		Parent = gui,
	})
	Widgets.list(4).Parent = panel
	nameLabel = Widgets.label({
		Name = "BossName",
		Font = Theme.fontBold,
		TextColor3 = Theme.danger,
		LayoutOrder = 1,
		Parent = panel,
	})
	local back = Widgets.create("Frame", {
		Name = "Back",
		BackgroundColor3 = Theme.panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
		LayoutOrder = 2,
		Parent = panel,
	}, { Widgets.corner(UDim.new(0, 6)) })
	barFill = Widgets.create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.danger,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = back,
	}, { Widgets.corner(UDim.new(0, 6)) })
	phaseLabel = Widgets.label({
		Name = "BossPhase",
		TextSize = 14,
		TextColor3 = Theme.textDim,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 3,
		Parent = panel,
	})
	screen = gui
end

local function updateBar()
	local gui, name, phase, fill = screen, nameLabel, phaseLabel, barFill
	if not (gui and name and phase and fill) then
		return
	end
	local first = bosses[1]
	gui.Enabled = first ~= nil and RunStateController.getView() == "Run"
	if not first then
		return
	end
	local kind = kindOf(first.bossId)
	name.Text = if kind then kind.displayName else first.bossId
	if #bosses > 1 then
		name.Text ..= ` and {#bosses - 1} more`
	end
	local share = math.clamp(first.hpFraction, 0, 1)
	fill.Size = UDim2.fromScale(share, 1)
	phase.Text = `Phase {first.phase} of {first.phaseCount} · {math.ceil(share * 100)} %`
end

-- Floor warnings -----------------------------------------------------------------------

local function release(entry: Telegraph)
	if entry.info.shape == "Line" then
		stripPool:release(entry.edge)
		stripPool:release(entry.fill)
	else
		discPool:release(entry.edge)
		discPool:release(entry.fill)
	end
end

local function onTelegraphs(list: { Types.BossTelegraph })
	if typeof(list) ~= "table" then
		return
	end
	for _, info in list do
		if #telegraphs >= MAX_TELEGRAPHS then
			return
		end
		if typeof(info) ~= "table" or typeof(info.x) ~= "number" or typeof(info.hitsAt) ~= "number" then
			continue
		end
		local pool = if info.shape == "Line" then stripPool else discPool
		local edge, fill = pool:acquire(getFolder()), pool:acquire(getFolder())
		edge.Transparency = EDGE_TRANSPARENCY
		fill.Transparency = FILL_TRANSPARENCY
		edge.Color, fill.Color = WARN_COLOR, WARN_COLOR
		table.insert(telegraphs, { info = info, edge = edge, fill = fill })
	end
end

-- Places a warning: the outline shows the whole area, the inner part grows until it strikes, then both flash.
local function placeTelegraph(entry: Telegraph, now: number): boolean
	local info = entry.info
	local endsAt = info.endsAt
	if now >= (if endsAt then math.max(endsAt, info.hitsAt + FLASH_SECONDS) else info.hitsAt + FLASH_SECONDS) then
		return false
	end
	if endsAt and now >= info.hitsAt + FLASH_SECONDS then
		-- a pool: stays at full size in its own color until it dries up
		local diameter = info.radius * 2
		local upright = CFrame.new(info.x, floorY + DISC_HEIGHT, info.z) * CFrame.Angles(0, 0, math.pi / 2)
		entry.edge.Color, entry.fill.Color = POOL_COLOR, POOL_COLOR
		entry.edge.Transparency, entry.fill.Transparency = POOL_TRANSPARENCY, 1
		entry.edge.Size = Vector3.new(DISC_HEIGHT, diameter, diameter)
		entry.edge.CFrame = upright
		return true
	end
	local span = math.max(info.hitsAt - info.startsAt, 1e-3)
	local t = math.clamp((now - info.startsAt) / span, 0, 1)
	local striking = now >= info.hitsAt
	if striking then
		entry.edge.Color, entry.fill.Color = FLASH_COLOR, FLASH_COLOR
		t = 1
	end
	local y = floorY + DISC_HEIGHT
	if info.shape == "Line" then
		local dx, dz, length = info.dx or 0, info.dz or 1, info.length or 1
		local yaw = math.atan2(-dx, -dz)
		local width = info.radius * 2
		local base = CFrame.new(info.x, y, info.z) * CFrame.Angles(0, yaw, 0)
		entry.edge.Size = Vector3.new(width, DISC_HEIGHT, length)
		entry.edge.CFrame = base * CFrame.new(0, 0, -length / 2)
		local filled = math.max(length * t, 0.05)
		entry.fill.Size = Vector3.new(width * 0.9, DISC_HEIGHT * 1.5, filled)
		entry.fill.CFrame = base * CFrame.new(0, 0, -filled / 2)
	else
		local diameter = info.radius * 2
		local upright = CFrame.new(info.x, y, info.z) * CFrame.Angles(0, 0, math.pi / 2)
		entry.edge.Size = Vector3.new(DISC_HEIGHT, diameter, diameter)
		entry.edge.CFrame = upright
		local inner = math.max(diameter * t, 0.05)
		entry.fill.Size = Vector3.new(DISC_HEIGHT * 1.5, inner, inner)
		entry.fill.CFrame = upright
	end
	return true
end

-- Embers -------------------------------------------------------------------------------

local function placeEmbers(now: number)
	local used = 0
	for _, info in bosses do
		local kind = kindOf(info.bossId)
		local plan = kind and kind.boss
		local phase = plan and plan.phases[info.phase]
		local orbit = phase and phase.orbit
		local startedAt = info.orbitStartedAt
		local position = EnemyRenderer.getPosition(info.id)
		if not (orbit and startedAt and position) then
			continue
		end
		local turn = (now - startedAt) * orbit.turnsPerSecond * 2 * math.pi
		for k = 1, orbit.count do
			used += 1
			local ember = embers[used]
			if not ember then
				ember = emberPool:acquire(getFolder())
				embers[used] = ember
			end
			local angle = turn + (k - 1) / orbit.count * 2 * math.pi
			ember.Size = Vector3.one * orbit.hitRadius * 2
			ember.CFrame = CFrame.new(
				position.X + math.cos(angle) * orbit.radius,
				floorY + kind.radius * 0.6,
				position.Z + math.sin(angle) * orbit.radius
			)
		end
	end
	for k = #embers, used + 1, -1 do
		emberPool:release(embers[k])
		embers[k] = nil
	end
end

local function clearAll()
	for _, entry in telegraphs do
		release(entry)
	end
	table.clear(telegraphs)
	table.clear(bosses)
	placeEmbers(0)
	updateBar()
end

local function render()
	if RunStateController.getView() ~= "Run" then
		if #telegraphs > 0 or #embers > 0 then
			clearAll()
		end
		return
	end
	local now = workspace:GetServerTimeNow()
	for index = #telegraphs, 1, -1 do
		local entry = telegraphs[index]
		if not placeTelegraph(entry, now) then
			release(entry)
			table.remove(telegraphs, index)
		end
	end
	placeEmbers(now)
end

-- Lifecycle -------------------------------------------------------------------------

function BossController.init()
	Net.onClient("BossState", function(state: Types.BossState)
		bosses = if typeof(state) == "table" and typeof(state.bosses) == "table" then state.bosses else {}
		updateBar()
	end)
	Net.onClient("BossTelegraphs", onTelegraphs)
end

function BossController.start()
	buildBar()
	RunStateController.Changed:Connect(function()
		if RunStateController.getView() ~= "Run" then
			clearAll()
		end
		updateBar()
	end)
	updateBar()
	RunService.RenderStepped:Connect(render)
end

-- Queries ---------------------------------------------------------------------------

-- The boss bar's name and phase text, "" while hidden (tests).
function BossController.getBarText(): string
	local gui, name, phase = screen, nameLabel, phaseLabel
	if not (gui and name and phase and gui.Enabled) then
		return ""
	end
	return `{name.Text} | {phase.Text}`
end

-- Pools lying on the floor right now (WP10 part 2, tests).
function BossController.getPoolCount(): number
	local now = workspace:GetServerTimeNow()
	local count = 0
	for _, entry in telegraphs do
		if entry.info.endsAt and now >= entry.info.hitsAt then
			count += 1
		end
	end
	return count
end

-- Warnings on the floor right now and embers circling a boss (tests).
function BossController.getCounts(): (number, number)
	return #telegraphs, #embers
end

return BossController
