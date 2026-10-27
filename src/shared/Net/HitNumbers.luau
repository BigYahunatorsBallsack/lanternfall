--!strict
-- Binary format of the damage numbers a player's own weapons dealt in one simulation step (DamageNumbers remote,
-- unreliable). Encoded by WeaponService on the server, decoded by DamageNumberController on the client.
--
-- Packet layout (little endian):
--   header  u8 count                                       1 byte
--   hit     i16 x, i16 z, u16 amount, u8 flags            7 bytes each
-- x/z are the enemy's floor position in Snapshot.POSITION_SCALE units; amount is the damage rounded, at least 1,
-- at most 65535; flags bit 0 = critical hit, bit 1 = the hit killed. At most MAX_HITS per packet (well below the
-- ~900 bytes an unreliable remote carries); the sender drops the rest.

local Snapshot = require(script.Parent.Snapshot)

local HEADER_SIZE = 1
local HIT_SIZE = 7
local SCALE = Snapshot.POSITION_SCALE
local INT16_MIN, INT16_MAX = -32768, 32767

local HitNumbers = {}

HitNumbers.MAX_HITS = 100
HitNumbers.FLAG_CRIT = 1
HitNumbers.FLAG_KILL = 2

export type Hit = { x: number, z: number, amount: number, crit: boolean, killed: boolean }

local function packPosition(value: number): number
	return math.clamp(math.round(value * SCALE), INT16_MIN, INT16_MAX)
end

-- Encodes the first `count` hits (columns of x, z, amount and flags) into one packet, at most MAX_HITS of them.
function HitNumbers.encode(
	xs: { number },
	zs: { number },
	amounts: { number },
	flags: { number },
	count: number
): buffer
	local n = math.min(count, HitNumbers.MAX_HITS)
	local b = buffer.create(HEADER_SIZE + n * HIT_SIZE)
	buffer.writeu8(b, 0, n)
	local offset = HEADER_SIZE
	for i = 1, n do
		buffer.writei16(b, offset, packPosition(xs[i]))
		buffer.writei16(b, offset + 2, packPosition(zs[i]))
		buffer.writeu16(b, offset + 4, math.clamp(math.round(amounts[i]), 1, 65535))
		buffer.writeu8(b, offset + 6, flags[i] % 256)
		offset += HIT_SIZE
	end
	return b
end

-- Decodes a packet into a list of hits; an empty list for malformed packets.
function HitNumbers.decode(b: buffer): { Hit }
	local length = buffer.len(b)
	if length < HEADER_SIZE then
		return {}
	end
	local n = buffer.readu8(b, 0)
	if length ~= HEADER_SIZE + n * HIT_SIZE then
		return {}
	end
	local hits = table.create(n)
	local offset = HEADER_SIZE
	for i = 1, n do
		local flags = buffer.readu8(b, offset + 6)
		hits[i] = {
			x = buffer.readi16(b, offset) / SCALE,
			z = buffer.readi16(b, offset + 2) / SCALE,
			amount = buffer.readu16(b, offset + 4),
			crit = flags % 2 == 1,
			killed = (flags // 2) % 2 == 1,
		}
		offset += HIT_SIZE
	end
	return hits
end

return HitNumbers
