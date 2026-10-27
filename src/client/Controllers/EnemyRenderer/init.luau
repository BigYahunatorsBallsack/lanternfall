--!strict
-- Draws the server's enemies (DESIGN.md section 15): EnemySnapshot packets go into a SnapshotBuffer, models
-- are pooled per enemy type (EnemyRenderer/Models), positions are interpolated about 100 ms behind the
-- newest tick and every part moves with one workspace:BulkMoveTo per frame. Models.pose animates the walk: the step
-- cycle advances with the distance an enemy covers, so legs and bobbing match its speed. Hits flash the model
-- white; the snapshot flags show a charger's wind-up and rush (it then faces its rush direction from the flags) and
-- an elite's affix (Models.setMode, setAffix). An enemy that drops out of the snapshots died: it leaves a glowing
-- puff (DeathBursts), an elite also shakes the camera. Big crowds switch the plain enemies to low detail (Models.setDetail, limits in
-- Config.Feedback.enemyDetail). Active only while the local player is in a running run (RunStateController).
-- DebugController reads getStats().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local Snapshot = require(Shared:WaitForChild("Net"):WaitForChild("Snapshot"))

local CameraController = require(script.Parent.CameraController)
local DeathBursts = require(script.DeathBursts)
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
	seenFrame: number, -- 0 until it was drawn once
	seed: number, -- spreads idle motions of neighbouring ids
	phase: number, -- step cycle in radians
	move: number, -- 0 standing to 1 walking at its own speed, smoothed
	x: number, -- where it was drawn last, for its walk and death burst
	z: number,
}

local FOLDER_NAME = "LanternfallEnemies"
local FLASH_SECONDS = 0.1
local TURN_PER_SECOND = 12 -- how quickly models turn towards where they walk
local CHARGE_TURN_PER_SECOND = 30 -- how quickly a winding-up charger turns towards its rush
local MIN_TURN_MOVE = 0.05 -- studs between two ticks; slower enemies keep their facing
local MOVE_SMOOTHING = 8 -- per second; how quickly the walk animation follows speed changes
local MAX_STEP_STUDS = 4 -- per frame; longer jumps (an enemy moved to a new spawn point) do not count as walking
local GOLDEN_RATIO = 0.618034 -- spreads the seeds of neighbouring ids
local STATS_WINDOW_SECONDS = 1

local EnemyRenderer = {}

local snapshots = SnapshotBuffer.new(Config.Simulation.tickRate, Config.Simulation.interpolationDelay)
local drawn: { [number]: Drawn } = {} -- by enemy id
local pools: { [number]: { Models.Visual } } = {} -- by typeId
local folder: Folder? = nil
local enabled = false
local lowDetail = false
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
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
	if visual.hpBar then
		visual.hpBar.Size = UDim2.fromScale(hp, 1)
	end
	local entry: Drawn = {
		visual = visual,
		typeId = typeId,
		yaw = 0,
		lastHp = hp,
		flashUntil = 0,
		seenFrame = 0,
		seed = (id * GOLDEN_RATIO) % 1 * 2 * math.pi,
		phase = (id * GOLDEN_RATIO) % 1 * 2 * math.pi,
		move = 0,
		x = 0,
		z = 0,
	}
	drawn[id] = entry
	return entry
end

local function release(id: number, entry: Drawn)
	drawn[id] = nil
	local visual = entry.visual
	Models.reset(visual)
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

-- Low detail above the crowd limit, back to full detail only well below it, so it does not flicker at the limit.
local function updateDetail(enemies: number)
	local settings = Config.Feedback.enemyDetail
	local limit = if touch then settings.lowAboveTouch else settings.lowAbove
	lowDetail = enemies > (if lowDetail then limit * settings.backBelowShare else limit)
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
		local chargeTurn = math.min(1, CHARGE_TURN_PER_SECOND * dt)
		local interpolate = before ~= after
		updateDetail(after.count)
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

			local mode, affix, heading = Snapshot.unpackFlags(after.flags[i])
			if mode ~= 0 then
				-- a charger from the wind-up on faces where it rushes, not where neighbours push it
				current.yaw = turnTowards(current.yaw, math.atan2(-math.cos(heading), -math.sin(heading)), chargeTurn)
			end
			local x, z = after.xs[i], after.zs[i]
			local previous = if interpolate then before.indexOf[id] else nil
			if previous then
				local fromX, fromZ = before.xs[previous], before.zs[previous]
				local dx, dz = x - fromX, z - fromZ
				if mode == 0 and dx * dx + dz * dz > MIN_TURN_MOVE * MIN_TURN_MOVE then
					-- a CFrame looks along -Z, so yaw = atan2(-dx, -dz) faces the walking direction
					current.yaw = turnTowards(current.yaw, math.atan2(-dx, -dz), turn)
				end
				x, z = fromX + dx * alpha, fromZ + dz * alpha
			end

			local visual = current.visual
			Models.setAffix(visual, affix)
			Models.setMode(visual, mode)
			Models.setDetail(visual, lowDetail and visual.hpBar == nil) -- elites keep every detail
			if hp < current.lastHp then
				current.flashUntil = now + FLASH_SECONDS
				Models.setFlash(visual, true)
				if visual.hpBar then
					visual.hpBar.Size = UDim2.fromScale(hp, 1)
				end
			elseif current.flashUntil > 0 and now >= current.flashUntil then
				current.flashUntil = 0
				Models.setFlash(visual, false)
			end
			current.lastHp = hp

			-- the walk: the step cycle follows the distance covered since the last frame
			local walked = 0
			if current.seenFrame > 0 then
				local wx, wz = x - current.x, z - current.z
				walked = math.sqrt(wx * wx + wz * wz)
				if walked > MAX_STEP_STUDS then
					walked = 0
				end
			end
			local speed = if dt > 0 then walked / dt else 0
			local target = math.min(1, speed / math.max(visual.speed, 1))
			current.move += (target - current.move) * math.min(1, MOVE_SMOOTHING * dt)
			current.phase = (current.phase + walked / visual.gait.stride * 2 * math.pi) % (2 * math.pi)
			current.seenFrame = frameNumber
			current.x, current.z = x, z

			local base = CFrame.new(x, floorY, z) * CFrame.Angles(0, current.yaw, 0)
			count =
				Models.pose(visual, base, current.phase, current.move, now, current.seed, partList, cframeList, count)
		end
	end
	for id, entry in drawn do
		if entry.seenFrame ~= frameNumber then
			-- died (enemies only leave the snapshots when killed, or all at once when the run ends)
			local elite = entry.visual.hpBar ~= nil
			DeathBursts.burst(entry.x, floorY, entry.z, entry.visual.glowColor, elite)
			if elite then
				CameraController.shake(Config.Feedback.shake.eliteKill)
			end
			release(id, entry)
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
