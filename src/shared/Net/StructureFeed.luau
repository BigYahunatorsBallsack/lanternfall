--!strict
-- Binary format of the B12 structures (Structures remote) and their attack rays (StructureBeams), since Paket 22.
-- Encoded by StructureService on the server, decoded by StructureRenderer on the client into the same rows as before.
--
-- Structures packet (little endian):
--   header   u16 count, u8 owners, f64 userId per owner
--   row      u32 id, u8 owner (index into the header's owners), kind, f32 x, f32 z
-- Beams packet:
--   header   u16 count
--   beam     kind, f32 x, f32 z, f32 tx, f32 tz
-- kind is an index into KINDS (sorted Config.Structures.kinds, 1-based); 0 means u8 length + text follows.

local Config = require(script.Parent.Parent.Config)

export type Row = { id: number, ownerId: number, kind: string, x: number, z: number }
export type Beam = { x: number, z: number, tx: number, tz: number, kind: string }

local MAX_COUNT = 65535

local function kindNames(): { string }
	local names = {}
	for id in Config.Structures.kinds do
		table.insert(names, id)
	end
	table.sort(names)
	return names
end

local KINDS = kindNames()
local KIND_INDEX: { [string]: number } = {}
for index, name in KINDS do
	KIND_INDEX[name] = index
end

local StructureFeed = {}

StructureFeed.KINDS = KINDS

local function kindSize(kind: string): number
	return if KIND_INDEX[kind] then 1 else 2 + math.min(#kind, 255)
end

local function writeKind(b: buffer, offset: number, kind: string): number
	local index = KIND_INDEX[kind]
	if index then
		buffer.writeu8(b, offset, index)
		return offset + 1
	end
	local text = string.sub(kind, 1, 255)
	buffer.writeu8(b, offset, 0)
	buffer.writeu8(b, offset + 1, #text)
	buffer.writestring(b, offset + 2, text)
	return offset + 2 + #text
end

local function readKind(b: buffer, offset: number): (string, number)
	local index = buffer.readu8(b, offset)
	if index > 0 then
		return KINDS[index] or "", offset + 1
	end
	local length = buffer.readu8(b, offset + 1)
	return buffer.readstring(b, offset + 2, length), offset + 2 + length
end

function StructureFeed.encodeStructures(rows: { Row }): buffer
	local count = math.min(#rows, MAX_COUNT)
	local owners: { number } = {}
	local ownerIndex: { [number]: number } = {}
	local size = 3
	for i = 1, count do
		local row = rows[i]
		if not ownerIndex[row.ownerId] and #owners < 255 then
			table.insert(owners, row.ownerId)
			ownerIndex[row.ownerId] = #owners - 1
			size += 8
		end
		size += 4 + 1 + kindSize(row.kind) + 8
	end
	local b = buffer.create(size)
	buffer.writeu16(b, 0, count)
	buffer.writeu8(b, 2, #owners)
	local offset = 3
	for _, userId in owners do
		buffer.writef64(b, offset, userId)
		offset += 8
	end
	for i = 1, count do
		local row = rows[i]
		buffer.writeu32(b, offset, row.id % 4294967296)
		buffer.writeu8(b, offset + 4, ownerIndex[row.ownerId] or 0)
		offset = writeKind(b, offset + 5, row.kind)
		buffer.writef32(b, offset, row.x)
		buffer.writef32(b, offset + 4, row.z)
		offset += 8
	end
	return b
end

local function decodeStructuresUnsafe(b: buffer): { Row }
	local count = buffer.readu16(b, 0)
	local ownerCount = buffer.readu8(b, 2)
	local owners = table.create(ownerCount)
	local offset = 3
	for i = 1, ownerCount do
		owners[i] = buffer.readf64(b, offset)
		offset += 8
	end
	local rows = table.create(count)
	for i = 1, count do
		local id = buffer.readu32(b, offset)
		local ownerId = owners[buffer.readu8(b, offset + 4) + 1] or 0
		local kind
		kind, offset = readKind(b, offset + 5)
		rows[i] = {
			id = id,
			ownerId = ownerId,
			kind = kind,
			x = buffer.readf32(b, offset),
			z = buffer.readf32(b, offset + 4),
		}
		offset += 8
	end
	assert(offset == buffer.len(b), "packet length")
	return rows
end

-- The structures of a packet; an empty list for malformed packets.
function StructureFeed.decodeStructures(b: buffer): { Row }
	local ok, rows = pcall(decodeStructuresUnsafe, b)
	return if ok then rows else {}
end

function StructureFeed.encodeBeams(beams: { Beam }): buffer
	local count = math.min(#beams, MAX_COUNT)
	local size = 2
	for i = 1, count do
		size += kindSize(beams[i].kind) + 16
	end
	local b = buffer.create(size)
	buffer.writeu16(b, 0, count)
	local offset = 2
	for i = 1, count do
		local beam = beams[i]
		offset = writeKind(b, offset, beam.kind)
		buffer.writef32(b, offset, beam.x)
		buffer.writef32(b, offset + 4, beam.z)
		buffer.writef32(b, offset + 8, beam.tx)
		buffer.writef32(b, offset + 12, beam.tz)
		offset += 16
	end
	return b
end

local function decodeBeamsUnsafe(b: buffer): { Beam }
	local count = buffer.readu16(b, 0)
	local beams = table.create(count)
	local offset = 2
	for i = 1, count do
		local kind
		kind, offset = readKind(b, offset)
		beams[i] = {
			kind = kind,
			x = buffer.readf32(b, offset),
			z = buffer.readf32(b, offset + 4),
			tx = buffer.readf32(b, offset + 8),
			tz = buffer.readf32(b, offset + 12),
		}
		offset += 16
	end
	assert(offset == buffer.len(b), "packet length")
	return beams
end

-- The beams of a packet; an empty list for malformed packets.
function StructureFeed.decodeBeams(b: buffer): { Beam }
	local ok, beams = pcall(decodeBeamsUnsafe, b)
	return if ok then beams else {}
end

return StructureFeed
