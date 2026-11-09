--!strict
-- Look of one material (shard) on the floor: which picture, how far it is turned and mirrored and a small size
-- change, all derived from the orb id so every client draws the same shard. Pure; called by XpOrbRenderer.

export type Settings = {
	turn: number, -- degrees: the shard is turned by up to this either way
	sizeJitter: number, -- share: the size changes by up to this either way
}

export type Look = {
	variant: number, -- 1..variantCount
	rotation: number, -- degrees
	scale: number,
	flipped: boolean,
}

local MaterialLook = {}

-- Integer hash of the id into [0, 1); `salt` gives independent values per property.
local function unit(id: number, salt: number): number
	local h = (math.floor(math.abs(id)) * 2654435761 + salt * 40503) % 4294967296
	h = (h * 1103515245 + 12345) % 2147483648
	h = (h * 1103515245 + 12345) % 2147483648
	return h / 2147483648
end

-- The picture of an id. Ids come one after another from the server, so they are dealt like a shuffled deck: every
-- `count` ids in a row hold each picture exactly once, in a new random order each time, and the same picture never
-- lies twice in a row across the edge of two decks.
local function deck(block: number, count: number): { number }
	local order = table.create(count, 0)
	for i = 1, count do
		order[i] = i
	end
	for i = count, 2, -1 do
		local j = 1 + math.min(i - 1, math.floor(unit(block, 10 + i) * i))
		order[i], order[j] = order[j], order[i]
	end
	return order
end

local function variantOf(id: number, count: number): number
	if count <= 1 then
		return 1
	end
	local index = math.floor(math.abs(id))
	local block, slot = index // count, index % count + 1
	local order = deck(block, count)
	if block > 0 and order[1] == deck(block - 1, count)[count] then
		order[1], order[2] = order[2], order[1]
	end
	return order[slot]
end

function MaterialLook.of(id: number, variantCount: number, settings: Settings): Look
	local count = math.max(1, math.floor(variantCount))
	return {
		variant = variantOf(id, count),
		rotation = (unit(id, 2) * 2 - 1) * settings.turn,
		scale = 1 + (unit(id, 3) * 2 - 1) * settings.sizeJitter,
		flipped = unit(id, 4) >= 0.5,
	}
end

return MaterialLook
