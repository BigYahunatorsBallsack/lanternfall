--!strict
-- Draws the server's enemies (DESIGN.md section 15): EnemySnapshot packets go into a SnapshotBuffer, models
-- are pooled per enemy type (EnemyRenderer/Models), positions are interpolated about 100 ms behind the
-- newest tick and every part moves with one workspace:BulkMoveTo per frame. Active only while the local
-- player is in a running run (RunStateController). DebugController reads getStats().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local Models = require(script.Models)
local RunStateController = require(script.Parent.RunStateController)
local SnapshotBuffer = require(script.SnapshotBuffer)

export type Stats = {
	drawn: number, -- enemies on screen right now
	receivedKilobytesPerSecond: number,
}

type Drawn = {
	visual: Models.Visual,
	typeId: number,
	yaw: number,
	lastHp: number,
	flashUntil: number, -- 0 when not flashing
	seenFrame: number,
	bobPhase: number,
}

local FOLDER_NAME = "LanternfallEnemies"
local FLASH_COLOR = Color3.fromRGB(255, 255, 255)
local FLASH_SECONDS = 0.08
local TURN_PER_SECOND = 12 -- how quickly models turn towards where they walk
local MIN_TURN_MOVE = 0.05 -- studs between two ticks; slower enemies keep their facing
local BOB_HEIGHT = 0.15 -- studs
local BOB_SPEED = 7 -- radians per second
local GOLDEN_RATIO = 0.618034 -- spreads the bob phase of neighbouring ids
local STATS_WINDOW_SECONDS = 1

local EnemyRenderer = {}

local snapshots = SnapshotBuffer.new(Config.Simulation.tickRate, Config.Simulation.interpolationDelay)
local drawn: { [number]: Drawn } = {} -- by enemy id
local pools: { [number]: { Models.Visual } } = {} -- by typeId
local folder: Folder? = nil
local enabled = false
local frameNumber = 0
local floorY = Config.Map.arena.center.Y

-- Reused lists for workspace:BulkMoveTo.
local partList: { BasePart } = {}
local cframeList: { CFrame } = {}
local listLength = 0

local stats: Stats = { drawn = 0, receivedKilobytesPerSecond = 0 }
local window = { startedAt = os.clock(), bytes = 0 }

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

local function acquire(id: number, typeId: number, hp: number): Drawn
	local pool = pools[typeId]
	local visual: Models.Visual
	if pool and #pool > 0 then
		visual = table.remove(pool) :: Models.Visual
	else
		visual = Models.build(typeId)
	end
	visual.model.Parent = getFolder()
	local entry: Drawn = {
		visual = visual,
		typeId = typeId,
		yaw = 0,
		lastHp = hp,
		flashUntil = 0,
		seenFrame = 0,
		bobPhase = (id * GOLDEN_RATIO) % 1 * 2 * math.pi,
	}
	drawn[id] = entry
	return entry
end

local function release(id: number, entry: Drawn)
	drawn[id] = nil
	local visual = entry.visual
	if entry.flashUntil > 0 then
		visual.body.Color = visual.bodyColor
	end
	visual.model.Parent = nil
	local pool = pools[entry.typeId]
	if not pool then
		pool = {}
		pools[entry.typeId] = pool
	end
	table.insert(pool, visual)
end

local function clearLists(from: number)
	for k = from, listLength do
		partList[k] = nil
		cframeList[k] = nil
	end
	listLength = math.min(listLength, from - 1)
end

local function setEnabled(value: boolean)
	if value == enabled then
		return
	end
	enabled = value
	if not value then
		snapshots:reset()
		for id, entry in drawn do
			release(id, entry)
		end
		clearLists(1)
	end
end

-- Shortest turn from `current` towards `target` (radians), by `amount` (0-1) of the way.
local function turnTowards(current: number, target: number, amount: number): number
	local difference = (target - current + math.pi) % (2 * math.pi) - math.pi
	return current + difference * amount
end

local function updateStats()
	local now = os.clock()
	local elapsed = now - window.startedAt
	if elapsed >= STATS_WINDOW_SECONDS then
		stats.receivedKilobytesPerSecond = window.bytes / 1024 / elapsed
		window.startedAt = now
		window.bytes = 0
	end
end

local function render(dt: number)
	updateStats()
	if not enabled then
		return
	end
	snapshots:advance(dt)
	local before, after, alpha = snapshots:sample()
	frameNumber += 1
	local now = os.clock()
	local count = 0
	if before and after then
		local turn = math.min(1, TURN_PER_SECOND * dt)
		local interpolate = before ~= after
		for i = 1, after.count do
			local id = after.ids[i]
			local typeId = after.typeIds[i]
			local hp = after.hpFractions[i]
			local entry = drawn[id]
			if entry and entry.typeId ~= typeId then
				release(id, entry) -- the id now belongs to a different enemy
				entry = nil
			end
			if not entry then
				entry = acquire(id, typeId, hp)
			end
			local current = entry :: Drawn

			local x, z = after.xs[i], after.zs[i]
			local previous = if interpolate then before.indexOf[id] else nil
			if previous then
				local fromX, fromZ = before.xs[previous], before.zs[previous]
				local dx, dz = x - fromX, z - fromZ
				if dx * dx + dz * dz > MIN_TURN_MOVE * MIN_TURN_MOVE then
					-- a CFrame looks along -Z, so yaw = atan2(-dx, -dz) faces the walking direction
					current.yaw = turnTowards(current.yaw, math.atan2(-dx, -dz), turn)
				end
				x, z = fromX + dx * alpha, fromZ + dz * alpha
			end

			local visual = current.visual
			if hp < current.lastHp then
				current.flashUntil = now + FLASH_SECONDS
				visual.body.Color = FLASH_COLOR
			elseif current.flashUntil > 0 and now >= current.flashUntil then
				current.flashUntil = 0
				visual.body.Color = visual.bodyColor
			end
			current.lastHp = hp
			current.seenFrame = frameNumber

			local y = floorY + BOB_HEIGHT * (1 + math.sin(now * BOB_SPEED + current.bobPhase))
			local base = CFrame.new(x, y, z) * CFrame.Angles(0, current.yaw, 0)
			local offsets = visual.offsets
			for k, part in visual.parts do
				count += 1
				partList[count] = part
				cframeList[count] = base * offsets[k]
			end
		end
	end
	for id, entry in drawn do
		if entry.seenFrame ~= frameNumber then
			release(id, entry) -- died or despawned
		end
	end
	clearLists(count + 1)
	listLength = count
	if count > 0 then
		workspace:BulkMoveTo(partList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Lifecycle -------------------------------------------------------------------------

function EnemyRenderer.init()
	Net.onClient("EnemySnapshot", function(packet: any)
		if enabled and typeof(packet) == "buffer" then
			window.bytes += buffer.len(packet)
			snapshots:push(packet)
		end
	end)
	RunStateController.Changed:Connect(function()
		setEnabled(RunStateController.getView() == "Run")
	end)
end

function EnemyRenderer.start()
	setEnabled(RunStateController.getView() == "Run")
	RunService.RenderStepped:Connect(render)
end

-- Queries ---------------------------------------------------------------------------

function EnemyRenderer.getStats(): Stats
	local count = 0
	for _ in drawn do
		count += 1
	end
	stats.drawn = count
	return stats
end

return EnemyRenderer
