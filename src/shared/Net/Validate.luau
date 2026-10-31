--!strict
-- Argument validators for remotes. Used by Net/Remotes definitions; checked server-side by Net.

export type Validator = (value: any) -> boolean

local Validate = {}

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

function Validate.number(min: number, max: number): Validator
	return function(value)
		return typeof(value) == "number" and isFinite(value) and value >= min and value <= max
	end
end

function Validate.integer(min: number, max: number): Validator
	return function(value)
		return typeof(value) == "number"
			and isFinite(value)
			and value == math.floor(value)
			and value >= min
			and value <= max
	end
end

function Validate.string(maxLength: number): Validator
	return function(value)
		return typeof(value) == "string" and #value > 0 and #value <= maxLength and utf8.len(value) ~= nil
	end
end

function Validate.boolean(): Validator
	return function(value)
		return typeof(value) == "boolean"
	end
end

function Validate.oneOf(allowed: { string }): Validator
	local set = {}
	for _, entry in allowed do
		set[entry] = true
	end
	return function(value)
		return typeof(value) == "string" and set[value] == true
	end
end

-- String that is a key of `map`, e.g. a class id from Config.Classes.
function Validate.keyOf(map: { [string]: any }): Validator
	return function(value)
		return typeof(value) == "string" and map[value] ~= nil
	end
end

-- Direction-like vectors: finite components, magnitude at most `maxMagnitude`.
function Validate.vector3(maxMagnitude: number): Validator
	return function(value)
		if typeof(value) ~= "Vector3" then
			return false
		end
		local v = value :: Vector3
		return isFinite(v.X) and isFinite(v.Y) and isFinite(v.Z) and v.Magnitude <= maxMagnitude
	end
end

function Validate.optional(inner: Validator): Validator
	return function(value)
		return value == nil or inner(value)
	end
end

return Validate
