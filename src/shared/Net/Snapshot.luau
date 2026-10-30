--!strict
-- Binary enemy snapshot format. Encoded by EnemySim on the server, decoded by EnemyRenderer on the client.
--
-- Packet layout (little endian):
--   header  u32 tick, u8 part, u8 partCount, u16 count       8 bytes
--   enemy   u16 id, i16 x, i16 z, u8 typeId, u8 hp, u8 flags, u8 status   10 bytes each
-- x/z are world positions multiplied by POSITION_SCALE (1/32 stud precision, range +-1024 studs).
-- hp is the remaining HP fraction mapped to 1-255 for living enemies.
-- flags: bits 0-1 the mode of a charger (EnemySim/World.MODE_*: walk, wind-up, rush, recover), bits 2-3 the
-- elite affix (0 = none, else index into Config.Enemies.elite.affixes), bits 4-7 the rush direction of a charger
-- in 16 steps (0 = +X, growing towards +Z), see packFlags.
-- status (since B5): bit 0 burning, bit 1 slowed (STATUS_*), the other bits stay 0.
-- UnreliableRemoteEvent payloads must stay below ~900 bytes, so one tick is split evenly into `partCount`
-- packets of at most MAX_PER_PACKET enemies (`part` counts from 0). The client uses a tick only once all
-- of its parts have arrived, so a lost packet skips that tick instead of making enemies vanish.
-- Enemies travel as column arrays (Columns), so neither side creates a table per enemy and tick.

local Snapshot = {}

local HEADER_SIZE = 8
local ENEMY_SIZE = 10
local POSITION_SCALE = 32
local INT16_MIN, INT16_MAX = -32768, 32767
local MAX_PER_PACKET = 89

Snapshot.HEADER_SIZE = HEADER_SIZE
Snapshot.ENEMY_SIZE = ENEMY_SIZE
Snapshot.MAX_PER_PACKET = MAX_PER_PACKET
Snapshot.MAX_PACKET_BYTES = HEADER_SIZE + MAX_PER_PACKET * ENEMY_SIZE
Snapshot.MAX_PARTS = 255
Snapshot.MAX_ID = 65535
Snapshot.POSITION_SCALE = POSITION_SCALE
Snapshot.STATUS_BURNING = 1
Snapshot.STATUS_SLOWED = 2
Snapshot.MAX_COORDINATE = INT16_MAX / POSITION_SCALE -- largest |x| or |z| that survives encoding

-- One entry per enemy at the same index in every array.
export type Columns = {
	ids: { number }, -- 0-65535
	xs: { number },
	zs: { number },
	typeIds: { number }, -- 0-255, see Config.Enemies
	hpFractions: { number }, -- 0-1
	flags: { number }, -- 0-255, see packFlags
	statuses: { number }, -- 0-255, STATUS_* bits
}

function Snapshot.newColumns(): Columns
	return { ids = {}, xs = {}, zs = {}, typeIds = {}, hpFractions = {}, flags = {}, statuses = {} }
end

Snapshot.HEADINGS = 16 -- steps of the rush direction in the flags byte

-- One flags byte from a mode (0-3), an affix index (0-3) and a rush direction (dx, dz; zero when not charging).
function Snapshot.packFlags(mode: number, affix: number, dx: number?, dz: number?): number
	local heading = 0
	if dx and dz and (dx ~= 0 or dz ~= 0) then
		heading = math.round(math.atan2(dz, dx) / (2 * math.pi) * Snapshot.HEADINGS) % Snapshot.HEADINGS
	end
	return mode % 4 + (affix % 4) * 4 + heading * 16
end

-- Mode (0-3), affix index (0-3) and rush direction (radians from +X towards +Z) from a flags byte.
function Snapshot.unpackFlags(flags: number): (number, number, number)
	return flags % 4, (flags // 4) % 4, (flags // 16) * 2 * math.pi / Snapshot.HEADINGS
end

local function packPosition(value: number): number
	return math.clamp(math.round(value * POSITION_SCALE), INT16_MIN, INT16_MAX)
end

local function packHp(fraction: number): number
	if fraction <= 0 then
		return 0
	end
	return math.clamp(math.ceil(fraction * 255), 1, 255) -- a living enemy never reads as 0
end

local function encodePart(
	tick: number,
	part: number,
	partCount: number,
	columns: Columns,
	first: number,
	count: number
): buffer
	local b = buffer.create(HEADER_SIZE + count * ENEMY_SIZE)
	buffer.writeu32(b, 0, tick)
	buffer.writeu8(b, 4, part)
	buffer.writeu8(b, 5, partCount)
	buffer.writeu16(b, 6, count)
	local ids, xs, zs, typeIds, hps = columns.ids, columns.xs, columns.zs, columns.typeIds, columns.hpFractions
	local flags, statuses = columns.flags, columns.statuses
	local offset = HEADER_SIZE
	for i = first, first + count - 1 do
		buffer.writeu16(b, offset, ids[i])
		buffer.writei16(b, offset + 2, packPosition(xs[i]))
		buffer.writei16(b, offset + 4, packPosition(zs[i]))
		buffer.writeu8(b, offset + 6, typeIds[i])
		buffer.writeu8(b, offset + 7, packHp(hps[i]))
		buffer.writeu8(b, offset + 8, flags[i] or 0)
		buffer.writeu8(b, offset + 9, statuses[i] or 0)
		offset += ENEMY_SIZE
	end
	return b
end

-- Encodes columns[1 .. count] of one tick into as few packets as possible, split evenly.
-- Always returns at least one packet, so clients also see ticks without enemies.
function Snapshot.encode(tick: number, columns: Columns, count: number): { buffer }
	local partCount = math.max(1, math.ceil(count / MAX_PER_PACKET))
	assert(partCount <= Snapshot.MAX_PARTS, "too many enemies for one snapshot")
	local packets = table.create(partCount)
	local first = 1
	for part = 0, partCount - 1 do
		-- the remaining enemies shared by the remaining parts, rounded up
		local size = math.ceil((count - first + 1) / (partCount - part))
		packets[part + 1] = encodePart(tick, part, partCount, columns, first, size)
		first += size
	end
	return packets
end

-- Reads and checks the header. Returns nothing for malformed packets.
function Snapshot.readHeader(b: buffer): (number?, number, number, number)
	local length = buffer.len(b)
	if length < HEADER_SIZE then
		return nil, 0, 0, 0
	end
	local tick = buffer.readu32(b, 0)
	local part = buffer.readu8(b, 4)
	local partCount = buffer.readu8(b, 5)
	local count = buffer.readu16(b, 6)
	if partCount == 0 or part >= partCount or length ~= HEADER_SIZE + count * ENEMY_SIZE then
		return nil, 0, 0, 0
	end
	return tick, part, partCount, count
end

-- Appends the enemies of a packet with a valid header (see readHeader) to `columns`, starting at index
-- `start`. Returns how many were added.
function Snapshot.decodeInto(b: buffer, columns: Columns, start: number): number
	local count = buffer.readu16(b, 6)
	local ids, xs, zs, typeIds, hps = columns.ids, columns.xs, columns.zs, columns.typeIds, columns.hpFractions
	local flags, statuses = columns.flags, columns.statuses
	local offset = HEADER_SIZE
	for i = start, start + count - 1 do
		ids[i] = buffer.readu16(b, offset)
		xs[i] = buffer.readi16(b, offset + 2) / POSITION_SCALE
		zs[i] = buffer.readi16(b, offset + 4) / POSITION_SCALE
		typeIds[i] = buffer.readu8(b, offset + 6)
		hps[i] = buffer.readu8(b, offset + 7) / 255
		flags[i] = buffer.readu8(b, offset + 8)
		statuses[i] = buffer.readu8(b, offset + 9)
		offset += ENEMY_SIZE
	end
	return count
end

return Snapshot
