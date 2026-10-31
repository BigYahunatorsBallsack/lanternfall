--!strict
-- Estimates how many bytes Roblox sends for one remote call (Paket 22). Used by the server's network meter
-- (Net.setMetering, AdminService debug panel) and the performance spec. Roblox does not document its format;
-- the sizes follow community measurements of the remote serializer: every value carries a type byte, numbers are
-- 8-byte doubles, strings and buffers a length prefix, and every table entry repeats its string key in full.
-- Cheap enough to run per call while an admin watches the debug panel; off otherwise.

local Config = require(script.Parent.Parent.Config)

local SIZES = Config.Simulation.netSize

local NetSize = {}

-- Bytes of a length prefix (variable-length integer: 7 bits per byte).
local function lengthPrefix(length: number): number
	local bytes = 1
	while length >= 128 do
		length //= 128
		bytes += 1
	end
	return bytes
end

local function sizeOf(value: any, depth: number): number
	local kind = typeof(value)
	if kind == "nil" then
		return SIZES.typeByte
	elseif kind == "boolean" then
		return SIZES.typeByte + 1
	elseif kind == "number" then
		return SIZES.typeByte + SIZES.number
	elseif kind == "string" then
		local length = #value
		return SIZES.typeByte + lengthPrefix(length) + length
	elseif kind == "buffer" then
		local length = buffer.len(value)
		return SIZES.typeByte + lengthPrefix(length) + length
	elseif kind == "table" then
		if depth > SIZES.maxDepth then
			return SIZES.typeByte
		end
		local bytes, count = SIZES.typeByte, 0
		local arrayLength = #value
		for key, entry in value do
			count += 1
			if type(key) == "number" and key >= 1 and key <= arrayLength and key % 1 == 0 then
				bytes += sizeOf(entry, depth + 1)
			else
				-- dictionaries send each key as a string (number keys too, as text)
				local text = if type(key) == "string" then key else tostring(key)
				bytes += lengthPrefix(#text) + #text + sizeOf(entry, depth + 1)
			end
		end
		return bytes + lengthPrefix(count)
	end
	return SIZES.typeByte + (SIZES.other[kind] or SIZES.other.default)
end

-- Bytes of one call with these arguments, overhead of the call included.
function NetSize.call(...: any): number
	local bytes = SIZES.callOverhead
	for i = 1, select("#", ...) do
		bytes += sizeOf((select(i, ...)), 0)
	end
	return bytes
end

-- Bytes of one value as a remote argument.
function NetSize.value(value: any): number
	return sizeOf(value, 0)
end

return NetSize
