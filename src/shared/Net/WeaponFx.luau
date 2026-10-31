--!strict
-- Binary format of the weapon effects of one simulation step (WeaponEffects remote, since Paket 22). Encoded by
-- WeaponService on the server, decoded by WeaponRenderer and AudioController on the client back into the same
-- Net/Types.WeaponEffect tables as before, so the visuals do not change. A table per effect with string keys cost
-- about 140 bytes on the wire (every key is sent as text); this format needs about 30-45.
--
-- Packet layout (little endian):
--   header   u16 count, f64 at (server time of the step), u8 owners, f64 userId per owner
--   effect   u16 mask, u8 weapon, u8 kind, u8 owner, then the fields of the mask in this order:
--            bit 14: f32 at offset (only when the effect's time differs from the header's)
--            bits 0-9: f32 x, z, dx, dz, speed, range, radius, distance, duration, angle
--            bit 10: u32 id, or bit 11: f64 id (ids that are no 32-bit integers)
--            bit 12: points, u16 count + f32 each
--            bit 13: other fields, u8 count + per field u8 key length, key, u8 type and value
--                    (1 f64 number, 2 u16 length + text, 3 true, 4 false, 5 u16 count + f64 numbers)
-- weapon and kind are indexes into WEAPONS and KINDS (1-based); 0 means the name follows as u8 length + text, so an
-- unknown name still arrives. owner is an index into the header's owners, 255 = no userId.

local Config = require(script.Parent.Parent.Config)

export type Effect = { [string]: any }

local FLOATS = { "x", "z", "dx", "dz", "speed", "range", "radius", "distance", "duration", "angle" }
local BIT_ID = 1024
local BIT_ID_WIDE = 2048
local BIT_POINTS = 4096
local BIT_EXTRA = 8192
local BIT_AT = 16384
local NO_OWNER = 255
local MAX_COUNT = 65535
local MAX_U32 = 4294967295

local KNOWN = { weapon = true, userId = true, kind = true, at = true, id = true, points = true }
for _, key in FLOATS do
	KNOWN[key] = true
end

-- Kinds the behaviors emit (WeaponService/Behaviors, Arsenal); others travel as text.
local KINDS = { "Fire", "End", "Pulse", "Chain", "Drop", "Blast", "Strike", "Burn", "Explosion" }

-- Visual names: every weapon and evolution behavior plus the shared "Explosion"; sorted, so server and client agree.
local function weaponNames(): { string }
	local seen: { [string]: boolean } = { Explosion = true }
	for _, weapon in Config.Weapons do
		local behavior = (weapon :: any).behavior
		if type(behavior) == "string" then
			seen[behavior] = true
		end
	end
	for _, evolution in Config.Evolutions do
		local behavior = (evolution :: any).behavior
		if type(behavior) == "string" then
			seen[behavior] = true
		end
	end
	local names = {}
	for name in seen do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local WEAPONS = weaponNames()

local function indexOf(list: { string }): { [string]: number }
	local map = {}
	for index, name in list do
		map[name] = index
	end
	return map
end

local WEAPON_INDEX = indexOf(WEAPONS)
local KIND_INDEX = indexOf(KINDS)

local WeaponFx = {}

WeaponFx.WEAPONS = WEAPONS
WeaponFx.KINDS = KINDS

local warned: { [string]: boolean } = {}
local function warnOnce(key: string, text: string)
	if not warned[key] then
		warned[key] = true
		warn(`[Lanternfall] WeaponFx: {text}`)
	end
end

local function nameSize(index: number?, name: any): number
	if index then
		return 1
	end
	return 2 + (if type(name) == "string" then math.min(#name, 255) else 0)
end

local function extraSize(key: string, value: any): number
	local head = 2 + math.min(#key, 255)
	local kind = type(value)
	if kind == "number" then
		return head + 8
	elseif kind == "string" then
		return head + 2 + math.min(#value, 65535)
	elseif kind == "boolean" then
		return head
	elseif kind == "table" then
		return head + 2 + 8 * math.min(#value, 65535)
	end
	return 0
end

local function isExtra(key: any, value: any): boolean
	if type(key) ~= "string" or KNOWN[key] then
		return false
	end
	local kind = type(value)
	if kind == "number" or kind == "string" or kind == "boolean" then
		return true
	elseif kind == "table" then
		for _, entry in value do
			if type(entry) ~= "number" then
				warnOnce(key, `field "{key}" holds a table that is not a list of numbers; it is not sent`)
				return false
			end
		end
		return true
	end
	warnOnce(key, `field "{key}" of type {kind} is not sent`)
	return false
end

local function writeName(b: buffer, offset: number, index: number?, name: any): number
	if index then
		buffer.writeu8(b, offset, index)
		return offset + 1
	end
	local text = if type(name) == "string" then string.sub(name, 1, 255) else ""
	buffer.writeu8(b, offset, 0)
	buffer.writeu8(b, offset + 1, #text)
	buffer.writestring(b, offset + 2, text)
	return offset + 2 + #text
end

local function readName(b: buffer, offset: number, list: { string }): (string?, number)
	local index = buffer.readu8(b, offset)
	if index > 0 then
		return list[index], offset + 1
	end
	local length = buffer.readu8(b, offset + 1)
	local text = buffer.readstring(b, offset + 2, length)
	return if length > 0 then text else nil, offset + 2 + length
end

-- Encodes a list of effects (at most 65535) into one packet. All effects of a step share the step's time.
function WeaponFx.encode(effects: { Effect }): buffer
	local count = math.min(#effects, MAX_COUNT)
	local baseAt = if count > 0 then tonumber(effects[1].at) or 0 else 0
	local owners: { number } = {}
	local ownerIndex: { [number]: number } = {}
	local size = 2 + 8 + 1
	for i = 1, count do
		local effect = effects[i]
		local userId = effect.userId
		if type(userId) == "number" and not ownerIndex[userId] and #owners < NO_OWNER then
			table.insert(owners, userId)
			ownerIndex[userId] = #owners - 1
			size += 8
		end
		size += 2 + 1 + nameSize(WEAPON_INDEX[effect.weapon], effect.weapon) + nameSize(
			KIND_INDEX[effect.kind],
			effect.kind
		)
		if effect.at ~= nil and effect.at ~= baseAt then
			size += 4
		end
		for _, key in FLOATS do
			if type(effect[key]) == "number" then
				size += 4
			end
		end
		local id = effect.id
		if type(id) == "number" then
			size += if id >= 0 and id <= MAX_U32 and id % 1 == 0 then 4 else 8
		end
		local points = effect.points
		if type(points) == "table" then
			size += 2 + 4 * math.min(#points, MAX_COUNT)
		end
		local extras = 0
		for key, value in effect do
			if isExtra(key, value) then
				extras += 1
				size += extraSize(key, value)
			end
		end
		if extras > 0 then
			size += 1
		end
	end

	local b = buffer.create(size)
	buffer.writeu16(b, 0, count)
	buffer.writef64(b, 2, baseAt)
	buffer.writeu8(b, 10, #owners)
	local offset = 11
	for _, userId in owners do
		buffer.writef64(b, offset, userId)
		offset += 8
	end
	for i = 1, count do
		local effect = effects[i]
		local mask = 0
		for bit, key in FLOATS do
			if type(effect[key]) == "number" then
				mask += 2 ^ (bit - 1)
			end
		end
		local id = effect.id
		local wideId = false
		if type(id) == "number" then
			wideId = not (id >= 0 and id <= MAX_U32 and id % 1 == 0)
			mask += if wideId then BIT_ID_WIDE else BIT_ID
		end
		local points = effect.points
		if type(points) == "table" then
			mask += BIT_POINTS
		end
		local extras: { string } = {}
		for key, value in effect do
			if isExtra(key, value) and #extras < 255 then
				table.insert(extras, key)
			end
		end
		if #extras > 0 then
			mask += BIT_EXTRA
		end
		local at = tonumber(effect.at)
		if effect.at ~= nil and at ~= baseAt then
			mask += BIT_AT
		end

		buffer.writeu16(b, offset, mask)
		offset = writeName(b, offset + 2, WEAPON_INDEX[effect.weapon], effect.weapon)
		offset = writeName(b, offset, KIND_INDEX[effect.kind], effect.kind)
		local userId = effect.userId
		buffer.writeu8(b, offset, if type(userId) == "number" then ownerIndex[userId] or NO_OWNER else NO_OWNER)
		offset += 1
		if bit32.btest(mask, BIT_AT) then
			buffer.writef32(b, offset, (at or baseAt) - baseAt)
			offset += 4
		end
		for _, key in FLOATS do
			local value = effect[key]
			if type(value) == "number" then
				buffer.writef32(b, offset, value)
				offset += 4
			end
		end
		if type(id) == "number" then
			if wideId then
				buffer.writef64(b, offset, id)
				offset += 8
			else
				buffer.writeu32(b, offset, id)
				offset += 4
			end
		end
		if type(points) == "table" then
			local n = math.min(#points, MAX_COUNT)
			buffer.writeu16(b, offset, n)
			offset += 2
			for k = 1, n do
				buffer.writef32(b, offset, tonumber(points[k]) or 0)
				offset += 4
			end
		end
		if #extras > 0 then
			table.sort(extras)
			buffer.writeu8(b, offset, #extras)
			offset += 1
			for _, key in extras do
				local value = effect[key]
				local name = string.sub(key, 1, 255)
				buffer.writeu8(b, offset, #name)
				buffer.writestring(b, offset + 1, name)
				offset += 1 + #name
				local kind = type(value)
				if kind == "number" then
					buffer.writeu8(b, offset, 1)
					buffer.writef64(b, offset + 1, value)
					offset += 9
				elseif kind == "string" then
					local text = string.sub(value, 1, 65535)
					buffer.writeu8(b, offset, 2)
					buffer.writeu16(b, offset + 1, #text)
					buffer.writestring(b, offset + 3, text)
					offset += 3 + #text
				elseif kind == "boolean" then
					buffer.writeu8(b, offset, if value then 3 else 4)
					offset += 1
				else
					local n = math.min(#value, 65535)
					buffer.writeu8(b, offset, 5)
					buffer.writeu16(b, offset + 1, n)
					offset += 3
					for k = 1, n do
						buffer.writef64(b, offset, value[k])
						offset += 8
					end
				end
			end
		end
	end
	return b
end

local function decodeUnsafe(b: buffer): { Effect }
	local count = buffer.readu16(b, 0)
	local baseAt = buffer.readf64(b, 2)
	local ownerCount = buffer.readu8(b, 10)
	local owners = table.create(ownerCount)
	local offset = 11
	for i = 1, ownerCount do
		owners[i] = buffer.readf64(b, offset)
		offset += 8
	end
	local effects = table.create(count)
	for i = 1, count do
		local mask = buffer.readu16(b, offset)
		local effect: Effect = {}
		effect.weapon, offset = readName(b, offset + 2, WEAPONS)
		effect.kind, offset = readName(b, offset, KINDS)
		local owner = buffer.readu8(b, offset)
		offset += 1
		effect.userId = if owner ~= NO_OWNER then owners[owner + 1] else nil
		if bit32.btest(mask, BIT_AT) then
			effect.at = baseAt + buffer.readf32(b, offset)
			offset += 4
		else
			effect.at = baseAt
		end
		for bit, key in FLOATS do
			if bit32.btest(mask, 2 ^ (bit - 1)) then
				effect[key] = buffer.readf32(b, offset)
				offset += 4
			end
		end
		if bit32.btest(mask, BIT_ID) then
			effect.id = buffer.readu32(b, offset)
			offset += 4
		elseif bit32.btest(mask, BIT_ID_WIDE) then
			effect.id = buffer.readf64(b, offset)
			offset += 8
		end
		if bit32.btest(mask, BIT_POINTS) then
			local n = buffer.readu16(b, offset)
			offset += 2
			local points = table.create(n)
			for k = 1, n do
				points[k] = buffer.readf32(b, offset)
				offset += 4
			end
			effect.points = points
		end
		if bit32.btest(mask, BIT_EXTRA) then
			local extras = buffer.readu8(b, offset)
			offset += 1
			for _ = 1, extras do
				local length = buffer.readu8(b, offset)
				local key = buffer.readstring(b, offset + 1, length)
				offset += 1 + length
				local kind = buffer.readu8(b, offset)
				if kind == 1 then
					effect[key] = buffer.readf64(b, offset + 1)
					offset += 9
				elseif kind == 2 then
					local textLength = buffer.readu16(b, offset + 1)
					effect[key] = buffer.readstring(b, offset + 3, textLength)
					offset += 3 + textLength
				elseif kind == 3 or kind == 4 then
					effect[key] = kind == 3
					offset += 1
				elseif kind == 5 then
					local n = buffer.readu16(b, offset + 1)
					offset += 3
					local list = table.create(n)
					for k = 1, n do
						list[k] = buffer.readf64(b, offset)
						offset += 8
					end
					effect[key] = list
				else
					error("unknown field type")
				end
			end
		end
		effects[i] = effect
	end
	assert(offset == buffer.len(b), "packet length")
	return effects
end

-- Decodes a packet back into effect tables; an empty list for malformed packets.
function WeaponFx.decode(b: buffer): { Effect }
	local ok, effects = pcall(decodeUnsafe, b)
	return if ok then effects else {}
end

-- Same as decode, but the second listener of the same packet (WeaponRenderer, AudioController) gets the first one's
-- tables instead of decoding again. Anything that is not a buffer gives an empty list.
local lastPacket: buffer? = nil
local lastEffects: { Effect } = {}
function WeaponFx.decodeShared(packet: any): { Effect }
	if typeof(packet) ~= "buffer" then
		return {}
	end
	if packet ~= lastPacket then
		lastPacket = packet
		lastEffects = WeaponFx.decode(packet)
	end
	return lastEffects
end

return WeaponFx
