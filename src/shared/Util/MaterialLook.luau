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

function MaterialLook.of(id: number, variantCount: number, settings: Settings): Look
	local count = math.max(1, math.floor(variantCount))
	return {
		variant = 1 + math.min(count - 1, math.floor(unit(id, 1) * count)),
		rotation = (unit(id, 2) * 2 - 1) * settings.turn,
		scale = 1 + (unit(id, 3) * 2 - 1) * settings.sizeJitter,
		flipped = unit(id, 4) >= 0.5,
	}
end

return MaterialLook
