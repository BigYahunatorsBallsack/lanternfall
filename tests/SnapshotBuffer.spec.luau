-- Unit tests for the client's snapshot buffer (EnemyRenderer/SnapshotBuffer): assembling split ticks,
-- surviving lost or late packets, and the interpolation clock.

local Snapshot = require(game:GetService("ReplicatedStorage").Shared.Net.Snapshot)
local SnapshotBuffer = require(folderProxy("src/client", "Client").Controllers.EnemyRenderer.SnapshotBuffer)

local TICK_RATE = 15
local DELAY = 0.1

-- Packets for one tick with `count` enemies; enemy i sits at x = i + tick (they walk +1 stud per tick).
local function packetsFor(tick, count)
	local columns = Snapshot.newColumns()
	for i = 1, count do
		columns.ids[i] = i
		columns.xs[i] = i + tick
		columns.zs[i] = 0
		columns.typeIds[i] = 1
		columns.hpFractions[i] = 1
	end
	return Snapshot.encode(tick, columns, count)
end

local function pushTick(snapshots, tick, count)
	for _, packet in packetsFor(tick, count) do
		snapshots:push(packet)
	end
end

describe("SnapshotBuffer", function()
	it("uses a split tick only once every part arrived", function()
		local snapshots = SnapshotBuffer.new(TICK_RATE, DELAY)
		local packets = packetsFor(10, 140)
		expect(#packets).toBe(2)
		expect(snapshots:push(packets[2])).toBe(true)
		snapshots:advance(0)
		expect(snapshots:sample()).toBe(nil)
		expect(snapshots:push(packets[1])).toBe(true)
		snapshots:advance(0)
		local before, after = snapshots:sample()
		expect(after.tick).toBe(10)
		expect(after.count).toBe(140)
		expect(after.xs[after.indexOf[140]]).toBe(150)
		expect(before).toBe(after)
	end)

	it("skips a tick with a lost part and ignores late or duplicate packets", function()
		local snapshots = SnapshotBuffer.new(TICK_RATE, DELAY)
		pushTick(snapshots, 1, 140)
		local tick2 = packetsFor(2, 140)
		snapshots:push(tick2[1]) -- part 2 is lost
		pushTick(snapshots, 3, 140)
		expect(snapshots.latestTick).toBe(3)
		expect(snapshots:push(tick2[2])).toBe(false) -- arrives too late
		expect(snapshots:push(packetsFor(3, 140)[1])).toBe(false) -- duplicate of a drawn tick
		expect(#snapshots.frames).toBe(2)
		expect(snapshots.frames[1].tick).toBe(1)
		expect(snapshots.frames[2].tick).toBe(3)
	end)

	it("rejects garbage", function()
		local snapshots = SnapshotBuffer.new(TICK_RATE, DELAY)
		expect(snapshots:push(buffer.create(2))).toBe(false)
	end)

	it("renders between the two ticks around the delayed clock", function()
		local snapshots = SnapshotBuffer.new(TICK_RATE, DELAY)
		pushTick(snapshots, 100, 1)
		snapshots:advance(1 / 60)
		-- the first tick snaps the clock to newest - delay
		expect(snapshots.renderTick).toBeNear(100 - DELAY * TICK_RATE)
		-- packets keep arriving at 15 Hz while frames render at 60 Hz
		local tick = 100
		for frame = 1, 240 do
			if frame % 4 == 0 then
				tick += 1
				pushTick(snapshots, tick, 1)
			end
			snapshots:advance(1 / 60)
		end
		local before, after, alpha = snapshots:sample()
		expect(after.tick - before.tick).toBe(1)
		expect(alpha >= 0 and alpha <= 1).toBe(true)
		-- the clock trails the newest tick by about the delay, never ahead of it
		local behind = snapshots.latestTick - snapshots.renderTick
		expect(behind > 0 and behind < 2.5).toBe(true)
		local x = before.xs[1] + (after.xs[1] - before.xs[1]) * alpha
		expect(x).toBeNear(1 + snapshots.renderTick, 1e-6)
	end)

	it("holds the newest tick when packets stop and jumps after a long gap", function()
		local snapshots = SnapshotBuffer.new(TICK_RATE, DELAY)
		pushTick(snapshots, 1, 1)
		pushTick(snapshots, 2, 1)
		snapshots:advance(0)
		for _ = 1, 60 do
			snapshots:advance(1 / 60)
		end
		local before, after, alpha = snapshots:sample()
		expect(before.tick).toBe(2)
		expect(after.tick).toBe(2)
		expect(alpha).toBe(0)
		pushTick(snapshots, 50, 1)
		snapshots:advance(1 / 60)
		expect(snapshots.renderTick).toBeNear(50 - DELAY * TICK_RATE)
	end)

	it("never goes back to an older tick while packets have stopped", function()
		local snapshots = SnapshotBuffer.new(TICK_RATE, DELAY)
		pushTick(snapshots, 1, 3)
		pushTick(snapshots, 2, 0) -- the empty tick the server sends when a wave ends
		snapshots:advance(0)
		local reachedEmpty = false
		for _ = 1, 600 do -- 10 s without packets, e.g. in the shop
			snapshots:advance(1 / 60)
			local before = snapshots:sample()
			if before.tick == 2 then
				reachedEmpty = true
			end
			if reachedEmpty then
				expect(before.tick).toBe(2)
			end
		end
		expect(reachedEmpty).toBe(true)
	end)

	it("forgets everything on reset", function()
		local snapshots = SnapshotBuffer.new(TICK_RATE, DELAY)
		pushTick(snapshots, 7, 3)
		snapshots:advance(0)
		snapshots:reset()
		expect(snapshots:sample()).toBe(nil)
		expect(snapshots.latestTick).toBe(nil)
		-- an older tick is accepted again after the reset (e.g. next run)
		expect(snapshots:push(packetsFor(3, 1)[1])).toBe(true)
	end)
end)
