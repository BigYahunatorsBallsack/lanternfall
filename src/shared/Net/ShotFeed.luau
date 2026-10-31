--!strict
-- Binary format of the enemy projectile events (EnemyShots remote, since Paket 22). Encoded by EnemySim on the
-- server, decoded by EnemyShotRenderer on the client into the same Net/Types.EnemyShotEvents as before (a table with
-- eight string keys per shot cost about 100 bytes on the wire, this 32).
--
-- Packet layout (little endian):
--   header  u8 reset, u16 fired, u16 ended, f64 at (server time the first shot was fired)   13 bytes
--   fired   u32 id, f32 x, z, dx, dz, speed, range, f32 at offset                         32 bytes each
--   ended   u32 id, f32 distance flown                                                     8 bytes each

local Types = require(script.Parent.Types)

local HEADER_SIZE = 13
local FIRED_SIZE = 32
local ENDED_SIZE = 8
local MAX_COUNT = 65535
local U32 = 4294967296

local ShotFeed = {}

function ShotFeed.encode(events: Types.EnemyShotEvents): buffer
	local fired, ended = events.fired, events.ended
	local firedCount = math.min(#fired, MAX_COUNT)
	local endedCount = math.min(#ended // 2, MAX_COUNT)
	local baseAt = if firedCount > 0 then fired[1].at else 0
	local b = buffer.create(HEADER_SIZE + firedCount * FIRED_SIZE + endedCount * ENDED_SIZE)
	buffer.writeu8(b, 0, if events.reset then 1 else 0)
	buffer.writeu16(b, 1, firedCount)
	buffer.writeu16(b, 3, endedCount)
	buffer.writef64(b, 5, baseAt)
	local offset = HEADER_SIZE
	for i = 1, firedCount do
		local shot = fired[i]
		buffer.writeu32(b, offset, shot.id % U32)
		buffer.writef32(b, offset + 4, shot.x)
		buffer.writef32(b, offset + 8, shot.z)
		buffer.writef32(b, offset + 12, shot.dx)
		buffer.writef32(b, offset + 16, shot.dz)
		buffer.writef32(b, offset + 20, shot.speed)
		buffer.writef32(b, offset + 24, shot.range)
		buffer.writef32(b, offset + 28, shot.at - baseAt)
		offset += FIRED_SIZE
	end
	for k = 1, endedCount do
		buffer.writeu32(b, offset, ended[2 * k - 1] % U32)
		buffer.writef32(b, offset + 4, ended[2 * k])
		offset += ENDED_SIZE
	end
	return b
end

local EMPTY: Types.EnemyShotEvents = table.freeze({ fired = table.freeze({}), ended = table.freeze({}) }) :: any

-- The events of a packet; no events for malformed packets.
function ShotFeed.decode(b: buffer): Types.EnemyShotEvents
	local length = buffer.len(b)
	if length < HEADER_SIZE then
		return EMPTY
	end
	local firedCount, endedCount = buffer.readu16(b, 1), buffer.readu16(b, 3)
	if length ~= HEADER_SIZE + firedCount * FIRED_SIZE + endedCount * ENDED_SIZE then
		return EMPTY
	end
	local baseAt = buffer.readf64(b, 5)
	local fired = table.create(firedCount)
	local offset = HEADER_SIZE
	for i = 1, firedCount do
		fired[i] = {
			id = buffer.readu32(b, offset),
			x = buffer.readf32(b, offset + 4),
			z = buffer.readf32(b, offset + 8),
			dx = buffer.readf32(b, offset + 12),
			dz = buffer.readf32(b, offset + 16),
			speed = buffer.readf32(b, offset + 20),
			range = buffer.readf32(b, offset + 24),
			at = baseAt + buffer.readf32(b, offset + 28),
		}
		offset += FIRED_SIZE
	end
	local ended = table.create(endedCount * 2)
	for k = 1, endedCount do
		ended[2 * k - 1] = buffer.readu32(b, offset)
		ended[2 * k] = buffer.readf32(b, offset + 4)
		offset += ENDED_SIZE
	end
	return { reset = buffer.readu8(b, 0) == 1, fired = fired, ended = ended }
end

return ShotFeed
