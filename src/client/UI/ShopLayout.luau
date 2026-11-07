--!strict
-- Shared shop/stat geometry from the approved 1280x720 composition. Called by both controllers.
local ShopLayout = {}

function ShopLayout.measure(area: Vector2)
	local compact = area.X < 1000 or area.Y < 600
	local scale = if compact then 1 else math.min(area.X / 1280, area.Y / 720)
	local width, height = area.X / scale, area.Y / scale
	return {
		compact = compact,
		scale = scale,
		width = width,
		height = height,
		leftWidth = width - 310,
		statsX = width - 290,
		statsWidth = 274,
		statsHeight = height - 204,
		cardY = 98,
		cardHeight = math.clamp(height * 0.455, 310, 400),
		inventoryY = math.clamp(height * 0.455, 310, 400) + 195,
	}
end

return ShopLayout
