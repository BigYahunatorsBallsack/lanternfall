--!strict
-- Binary enemy snapshot format. Encoded by EnemySim on the server, decoded by EnemyRenderer on the client.
--
-- Packet layout (little endian):
--   header  u32 tick, u16 count                         6 bytes
--   enemy   u16 id, i16 x, i16 z, u8 typeId, u8 hp      8 bytes each
-- x/z are world positions multiplied by POSITION_SCALE (1/32 stud precision, range +-1024 studs).
-- hp is the remaining HP fraction mapped to 0-255.
-- UnreliableRemoteEvent payloads must stay below ~900 bytes, so one tick is split into packets of
-- at most MAX_PER_PACKET enemies that share the same tick.

local Snapshot = {}

local HEADER_SIZE = 6
local ENEMY_SIZE = 8
local POSITION_SCALE = 32
local INT16_MIN, INT16_MAX = -32768, 32767

Snapshot.MAX_PER_PACKET = 100
Snapshot.POSITION_SCALE = POSITION_SCALE

export type EnemyState = {
	id: number, -- 0-65535
	x: number,
	z: number,
	typeId: number, -- 0-255, see Config.Enemies
	hpFraction: number, -- 0-1
}

local function packPosition(value: number): number
	return math.clamp(math.round(value * POSITION_SCALE), INT16_MIN, INT16_MAX)
end

-- Encodes enemies[first .. first + count - 1] into one packet.
function Snapshot.encodePacket(tick: number, enemies: { EnemyState }, first: number, count: number): buffer
	local b = buffer.create(HEADER_SIZE + count * ENEMY_SIZE)
	buffer.writeu32(b, 0, tick)
	buffer.writeu16(b, 4, count)
	local offset = HEADER_SIZE
	for i = first, first + count - 1 do
		local e = enemies[i]
		buffer.writeu16(b, offset, e.id)
		buffer.writei16(b, offset + 2, packPosition(e.x))
		buffer.writei16(b, offset + 4, packPosition(e.z))
		buffer.writeu8(b, offset + 6, e.typeId)
		buffer.writeu8(b, offset + 7, math.clamp(math.round(e.hpFraction * 255), 0, 255))
		offset += ENEMY_SIZE
	end
	return b
end

-- Encodes all enemies of one tick into as many packets as needed (at least one, so clients see empty ticks).
function Snapshot.encode(tick: number, enemies: { EnemyState }): { buffer }
	local packets = {}
	local total = #enemies
	local first = 1
	repeat
		local count = math.min(Snapshot.MAX_PER_PACKET, total - first + 1)
		table.insert(packets, Snapshot.encodePacket(tick, enemies, first, count))
		first += count
	until first > total
	return packets
end

-- Decodes one packet. Returns nil for malformed data.
function Snapshot.decode(b: buffer): (number?, { EnemyState }?)
	local length = buffer.len(b)
	if length < HEADER_SIZE then
		return nil, nil
	end
	local tick = buffer.readu32(b, 0)
	local count = buffer.readu16(b, 4)
	if length ~= HEADER_SIZE + count * ENEMY_SIZE then
		return nil, nil
	end
	local enemies = table.create(count)
	local offset = HEADER_SIZE
	for i = 1, count do
		enemies[i] = {
			id = buffer.readu16(b, offset),
			x = buffer.readi16(b, offset + 2) / POSITION_SCALE,
			z = buffer.readi16(b, offset + 4) / POSITION_SCALE,
			typeId = buffer.readu8(b, offset + 6),
			hpFraction = buffer.readu8(b, offset + 7) / 255,
		}
		offset += ENEMY_SIZE
	end
	return tick, enemies
end

return Snapshot
