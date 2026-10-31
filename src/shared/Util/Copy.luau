--!strict
-- Deep copies of plain data tables (no cycles, no Instances as keys that must stay shared). Used by the services'
-- "Retry wave" checkpoints (RunDirector.addCheckpoint, B11 part 2). Metatables are kept.

local Copy = {}

function Copy.deep<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value :: any do
		result[key] = Copy.deep(item)
	end
	return setmetatable(result, getmetatable(value :: any)) :: any
end

return Copy
