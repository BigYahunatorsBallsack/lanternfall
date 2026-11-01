--!strict
--!native
-- Draws the server's enemies (DESIGN.md section 15): EnemySnapshot packets go into a SnapshotBuffer, models
-- are pooled per enemy type (EnemyRenderer/Models), positions are interpolated about 100 ms behind the
-- newest tick and every part moves with one workspace:BulkMoveTo per frame. Models.pose animates the walk: the step
-- cycle advances with the distance an enemy covers, so legs and bobbing match its speed. Hits flash the model
-- white; the snapshot flags show a charger's wind-up and rush (it then faces its rush direction from the flags) and
-- an elite's affix (Models.setMode, setAffix), the status byte (B5) burning and slowed enemies (Models.setStatus;
-- burning ones also give off embers, Config.Feedback.burnEmbers). An enemy that drops out of the snapshots died: it leaves a glowing
-- puff (DeathBursts), an elite also shakes the camera. Big crowds switch the plain enemies to low detail (Models.setDetail, limits in
-- Config.Feedback.enemyDetail). Since Paket 22 enemies off the screen (Util/ViewBounds, Config.Graphics) are not posed
-- and leave no particles; Low graphics (GraphicsController) uses the touch limits on every device.
-- Active only while the local player is in a running run (RunStateController).
-- DebugController reads getStats(), the smoke test getStatus().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local Snapshot = require(Shared:WaitForChild("Net"):WaitForChild("Snapshot"))
local EnemyKinds = require(Shared:WaitForChild("Util"):WaitForChild("EnemyKinds"))
local ViewBounds = require(Shared:WaitForChild("Util"):WaitForChild("ViewBounds"))
local Bursts = require(script.Parent.Parent.Vfx.Bursts)

local CameraController = require(script.Parent.CameraController)
local DeathBursts = require(script.DeathBursts)
local GraphicsController = require(script.Parent.GraphicsController)
local Models = require(script.Models)
local RunStateController = require(script.Parent.RunStateController)
local SnapshotBuffer = require(script.SnapshotBuffer)

export type Stats = {
	drawn: number, -- enemies with a model right now
	culled: number, -- of these, not posed in the last frame (off the screen)
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
	x: number, -- where it was last frame, for its walk and death burst
	z: number,
	posedX: number, -- where its model was last placed (off the screen it stays there)
	posedZ: number,
	emberAt: number, -- os.clock() of the next ember puff while burning
	alwaysPosed: boolean, -- elites and bosses are placed even off the screen (HP bar, glow)
}

local FOLDER_NAME = "LanternfallEnemies"
local FLASH_SECONDS = 0.1
local TURN_PER_SECOND = 12 -- how quickly models turn towards where they walk
local CHARGE_TURN_PER_SECOND = 30 -- how quickly a winding-up charger turns towards its rush
local MIN_TURN_MOVE = 0.05 -- studs between two ticks; slower enemies keep their facing
local MOVE_SMOOTHING = 8 -- per second; how quickly the walk animation follows speed changes
local MAX_STEP_STUDS = 4 -- per frame; longer jumps (an enemy moved to a new spawn point) do not count as walking
local GOLDEN_RATIO = 0.618034 -- spreads the seeds of neighbouring ids
local EMBER_COLOR = Color3.fromRGB(255, 120, 40)
local EMBER_HEIGHT = 1.6 -- times the enemy radius above the floor
local STATS_WINDOW_SECONDS = 1

local EnemyRenderer = {}

local snapshots = SnapshotBuffer.new(Config.Simulation.tickRate, Config.Simulation.interpolationDelay)
local drawn: { [number]: Drawn } = {} -- by enemy id
local pools: { [number]: { Models.Visual } } = {} -- by typeId
local folder: Folder? = nil
local enabled = false
local lowDetail = false
local frameNumber = 0
local floorY = Config.Map.arena.center.Y
local view = ViewBounds.new()

-- Reused lists for workspace:BulkMoveTo.
local partList: { BasePart } = {}
local cframeList: { CFrame } = {}
local listLength = 0

local stats: Stats = { drawn = 0, culled = 0, receivedKilobytesPerSecond = 0 }
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
	local kind: any = EnemyKinds.byTypeId(typeId)
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
		posedX = 0,
		posedZ = 0,
		emberAt = 0,
		alwaysPosed = visual.hpBar ~= nil or (kind ~= nil and kind.boss ~= nil),
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
	local limit = if GraphicsController.isLow() then settings.lowAboveTouch else settings.lowAbove
	lowDetail = enemies > (if lowDetail then limit * settings.backBelowShare else limit)
end

-- Places the view of this frame (CameraController's focus, the camera's field of view and screen shape); without a
-- focus or with culling off everything counts as on the screen.
local function updateView()
	local focus = CameraController.getFocus()
	local camera = workspace.CurrentCamera
	if not (Config.Graphics.cullOffscreen and focus and camera) then
		view.valid = false
		return
	end
	local size = camera.ViewportSize
	local aspect = if size.Y > 0 then size.X / size.Y else 1
	local pitchDegrees, distance = CameraController.getView() -- Paket 24: capture shots change both
	ViewBounds.update(view, focus.X, focus.Y, focus.Z, pitchDegrees, distance, camera.FieldOfView, aspect)
end

-- Whether a model of `radius` standing at floor point (x, z) may show on the screen: a sphere around its middle with
-- the margins of Config.Graphics (its height, the camera shake, a frame of lag).
local function onScreen(x: number, z: number, radius: number): boolean
	local graphics = Config.Graphics
	local margin = radius * graphics.cullMarginRadii + graphics.cullMarginStuds
	return ViewBounds.contains(view, x, floorY + radius, z, margin)
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
	local culled = 0
	updateView()
	if before and after then
		local turn = math.min(1, TURN_PER_SECOND * dt)
		local chargeTurn = math.min(1, CHARGE_TURN_PER_SECOND * dt)
		local interpolate = before ~= after
		local embers = Config.Feedback.burnEmbers
		local low = GraphicsController.isLow()
		local embersLeft = if embers.enabled then (if low then embers.maxPerFrameTouch else embers.maxPerFrame) else 0
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
			-- off the screen (now and where the model stands) a plain enemy keeps its model where it is; new ones,
			-- elites, bosses and enemies in a wind-up, rush or pulse (their telegraph reaches far) are always placed
			local visible = current.seenFrame == 0
				or current.alwaysPosed
				or mode ~= 0
				or onScreen(x, z, visual.radius)
				or onScreen(current.posedX, current.posedZ, visual.radius)
			Models.setAffix(visual, affix)
			Models.setMode(visual, mode)
			Models.setDetail(visual, lowDetail and visual.hpBar == nil) -- elites keep every detail
			local status = after.statuses[i] or 0
			local burning = bit32.btest(status, Snapshot.STATUS_BURNING)
			Models.setStatus(
				visual,
				burning,
				bit32.btest(status, Snapshot.STATUS_SLOWED),
				bit32.btest(status, Snapshot.STATUS_BUFFED)
			)
			if burning and visible and embersLeft > 0 and now >= current.emberAt then
				embersLeft -= 1
				current.emberAt = now + embers.interval
				local position = Vector3.new(x, floorY + visual.radius * EMBER_HEIGHT, z)
				Bursts.emit("ember", EMBER_COLOR, position, embers.particles)
			end
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

			if visible then
				current.posedX, current.posedZ = x, z
				local base = CFrame.new(x, floorY, z) * CFrame.Angles(0, current.yaw, 0)
				count = Models.pose(
					visual,
					base,
					current.phase,
					current.move,
					now,
					current.seed,
					partList,
					cframeList,
					count
				)
			else
				culled += 1
			end
		end
	end
	stats.culled = culled
	for id, entry in drawn do
		if entry.seenFrame ~= frameNumber then
			-- died (enemies only leave the snapshots when killed, or all at once when the run ends)
			local elite = entry.visual.hpBar ~= nil
			local seen = elite or onScreen(entry.x, entry.z, entry.visual.radius)
			DeathBursts.burst(entry.x, floorY, entry.z, entry.visual.glowColor, elite, seen)
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
	task.spawn(Models.preload)
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

-- Whether a drawn enemy shows as burning, as slowed (B5) and as buffed by a Herald (B9; tests). All false for
-- enemies not drawn.
function EnemyRenderer.getStatus(id: number): (boolean, boolean, boolean)
	local entry = drawn[id]
	if not entry then
		return false, false, false
	end
	return entry.visual.burning, entry.visual.slowed, entry.visual.buffed
end

-- Where a drawn enemy stands right now (interpolated, on the floor), nil for enemies not drawn (BossController, WP10).
function EnemyRenderer.getPosition(id: number): Vector3?
	local entry = drawn[id]
	if not entry or entry.seenFrame == 0 then
		return nil
	end
	return Vector3.new(entry.x, floorY, entry.z)
end

function EnemyRenderer.getStats(): Stats
	local count = 0
	for _ in drawn do
		count += 1
	end
	stats.drawn = count
	return stats
end

return EnemyRenderer
