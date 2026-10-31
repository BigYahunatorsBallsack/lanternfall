--!strict
--!native
-- Collects enemy snapshot packets (Net/Snapshot) into complete ticks and picks the two ticks to draw
-- between. Used by EnemyRenderer; pure Luau, tested in tests/SnapshotBuffer.spec.luau.
--
-- Render clock: it trails the newest complete tick by `delaySeconds` and runs at real time, gently pulled
-- towards that target, so uneven packet arrival does not make enemies stutter. After a long gap (lag
-- spike, first packet) it jumps straight to the target; it never runs past the newest tick.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Snapshot = require(Shared:WaitForChild("Net"):WaitForChild("Snapshot"))

-- One complete tick: Snapshot.Columns plus a lookup from enemy id to index.
export type Frame = {
	tick: number,
	count: number,
	ids: { number },
	xs: { number },
	zs: { number },
	typeIds: { number },
	hpFractions: { number },
	flags: { number },
	statuses: { number },
	indexOf: { [number]: number },
}

type Pending = {
	frame: Frame,
	partCount: number,
	received: { [number]: boolean },
	receivedCount: number,
}

local MAX_FRAMES = 8 -- complete ticks kept; drawing needs the two around the render clock
local MAX_PENDING = 4 -- incomplete ticks waiting for their other parts
local SNAP_TICKS = 4 -- the clock jumps when it is further than this from its target
local CORRECTION_PER_SECOND = 2 -- share of the clock error corrected per second

local SnapshotBuffer = {}
SnapshotBuffer.__index = SnapshotBuffer

export type SnapshotBuffer = typeof(setmetatable(
	{} :: {
		tickRate: number,
		delayTicks: number,
		frames: { Frame }, -- complete, oldest first
		pending: { [number]: Pending }, -- by tick
		pool: { Frame },
		latestTick: number?, -- newest complete tick
		renderTick: number?,
	},
	SnapshotBuffer
))

function SnapshotBuffer.new(tickRate: number, delaySeconds: number): SnapshotBuffer
	return setmetatable({
		tickRate = tickRate,
		delayTicks = delaySeconds * tickRate,
		frames = {},
		pending = {},
		pool = {},
		latestTick = nil,
		renderTick = nil,
	}, SnapshotBuffer)
end

local function takeFrame(self: SnapshotBuffer, tick: number): Frame
	local frame = table.remove(self.pool)
	if frame then
		frame.tick = tick
		frame.count = 0
		table.clear(frame.indexOf)
		return frame
	end
	return {
		tick = tick,
		count = 0,
		ids = {},
		xs = {},
		zs = {},
		typeIds = {},
		hpFractions = {},
		flags = {},
		statuses = {},
		indexOf = {},
	}
end

local function recycle(self: SnapshotBuffer, frame: Frame)
	table.insert(self.pool, frame)
end

local function dropPendingUpTo(self: SnapshotBuffer, tick: number)
	for pendingTick, entry in self.pending do
		if pendingTick <= tick then
			self.pending[pendingTick] = nil
			recycle(self, entry.frame)
		end
	end
end

local function commit(self: SnapshotBuffer, frame: Frame)
	table.insert(self.frames, frame)
	self.latestTick = frame.tick
	while #self.frames > MAX_FRAMES do
		recycle(self, table.remove(self.frames, 1) :: Frame)
	end
	dropPendingUpTo(self, frame.tick) -- older ticks can never be drawn now
end

-- Adds one packet. Returns false for malformed, duplicate or outdated packets.
function SnapshotBuffer.push(self: SnapshotBuffer, packet: buffer): boolean
	local tick, part, partCount = Snapshot.readHeader(packet)
	if not tick then
		return false
	end
	if self.latestTick and tick <= self.latestTick then
		return false
	end
	local entry = self.pending[tick]
	if not entry then
		local waiting = 0
		local oldest = math.huge
		for pendingTick in self.pending do
			waiting += 1
			oldest = math.min(oldest, pendingTick)
		end
		if waiting >= MAX_PENDING then
			local dropped = self.pending[oldest]
			self.pending[oldest] = nil
			recycle(self, dropped.frame)
		end
		entry = { frame = takeFrame(self, tick), partCount = partCount, received = {}, receivedCount = 0 }
		self.pending[tick] = entry
	end
	if entry.partCount ~= partCount or entry.received[part] then
		return false
	end
	entry.received[part] = true
	entry.receivedCount += 1

	local frame = entry.frame
	local first = frame.count + 1
	local added = Snapshot.decodeInto(packet, frame, first)
	for i = first, first + added - 1 do
		frame.indexOf[frame.ids[i]] = i
	end
	frame.count += added

	if entry.receivedCount == partCount then
		self.pending[tick] = nil
		commit(self, frame)
	end
	return true
end

-- Moves the render clock forward by dt seconds.
function SnapshotBuffer.advance(self: SnapshotBuffer, dt: number)
	local latest = self.latestTick
	if not latest then
		return
	end
	local target = latest - self.delayTicks
	local renderTick = self.renderTick
	if not renderTick or math.abs(target - renderTick) > SNAP_TICKS then
		self.renderTick = target
		return
	end
	renderTick += dt * self.tickRate
	renderTick += (target - renderTick) * math.min(1, CORRECTION_PER_SECOND * dt)
	-- Never run past the newest tick: when packets stop (shop between waves, run end) the clock would drift ahead,
	-- snap back to the target and draw the older ticks again, so enemies kept vanishing and coming back.
	self.renderTick = math.min(renderTick, latest)
end

-- The complete ticks just before and after the render clock and how far the clock is between them (0-1).
-- Before the first or after the last tick both frames are the same; nil before any tick arrived.
function SnapshotBuffer.sample(self: SnapshotBuffer): (Frame?, Frame?, number)
	local frames = self.frames
	local count = #frames
	local renderTick = self.renderTick
	if count == 0 or not renderTick then
		return nil, nil, 0
	end
	for k = count, 1, -1 do
		local before = frames[k]
		if before.tick <= renderTick then
			local after = frames[k + 1]
			if not after then
				return before, before, 0
			end
			return before, after, (renderTick - before.tick) / (after.tick - before.tick)
		end
	end
	return frames[1], frames[1], 0
end

-- Forgets every tick (run ended or the local player left the run).
function SnapshotBuffer.reset(self: SnapshotBuffer)
	for _, frame in self.frames do
		recycle(self, frame)
	end
	table.clear(self.frames)
	dropPendingUpTo(self, math.huge)
	self.latestTick = nil
	self.renderTick = nil
end

return SnapshotBuffer
