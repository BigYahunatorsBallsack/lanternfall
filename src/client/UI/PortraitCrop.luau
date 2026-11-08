--!strict
-- Square picture cutouts for character portraits (head zoom on select tiles, tight figure in the summary card).
-- Pure math on the figure shares from Config/SpriteImages; used by UI/Icons.
local PortraitCrop = {}

export type Figure = { pixels: number, center: number, ground: number, height: number }
export type Rect = { x: number, y: number, side: number }

-- Share of the figure height that the head cutout shows, measured from slightly above the top of the figure.
local HEAD_SHARE = 0.9
local HEAD_MARGIN = 0.03
-- Extra room around the whole figure so outlines and held weapons are not cut.
local FIGURE_MARGIN = 0.08

local function square(figure: Figure, top: number, side: number): Rect
	side = math.min(side, 1)
	local left = math.clamp(figure.center - side / 2, 0, 1 - side)
	top = math.clamp(top, 0, 1 - side)
	local pixels = figure.pixels
	return {
		x = math.floor(left * pixels + 0.5),
		y = math.floor(top * pixels + 0.5),
		side = math.floor(side * pixels + 0.5),
	}
end

-- Head and upper body, filling the square like the select tiles of the reference game.
function PortraitCrop.head(figure: Figure): Rect
	local top = 1 - figure.ground - figure.height
	return square(figure, top - HEAD_MARGIN * figure.height, HEAD_SHARE * figure.height)
end

-- The whole figure with a small margin, centered on the figure (held weapons included).
function PortraitCrop.figure(figure: Figure): Rect
	local side = figure.height * (1 + 2 * FIGURE_MARGIN)
	local middle = 1 - figure.ground - figure.height / 2
	return square(figure, middle - side / 2, side)
end

-- Like `figure`, but centered on the middle of the picture, where the body sits, so small tiles look symmetric
-- even when a held weapon sticks out to one side.
function PortraitCrop.badge(figure: Figure): Rect
	local side = figure.height * (1 + 2 * FIGURE_MARGIN)
	local middle = 1 - figure.ground - figure.height / 2
	return square(
		{ pixels = figure.pixels, center = 0.5, ground = figure.ground, height = figure.height },
		middle - side / 2,
		side
	)
end

return table.freeze(PortraitCrop)
