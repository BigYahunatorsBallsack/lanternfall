--!strict
-- Tiled floor and subdued shading shared by the lobby and between-wave shop screens.
local Widgets = require(script.Parent.Widgets)
local Images = require(game:GetService("ReplicatedStorage").Shared.Config.SpriteImages)
local Backdrop = {}

function Backdrop.mount(parent: Instance): Frame
	local root = Widgets.create("Frame", {
		Name = "MenuBackground",
		BackgroundColor3 = Color3.fromRGB(72, 69, 63),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = parent,
	})
	Widgets.create("ImageLabel", {
		Name = "FloorPattern",
		Image = Images.floors.Lobby,
		ImageColor3 = Color3.fromRGB(155, 148, 130),
		ImageTransparency = 0.64,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(420, 420),
		ZIndex = 0,
		Parent = root,
	})
	local shade = Widgets.create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = root,
	})
	Widgets.create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(1, 0),
		Parent = shade,
	})
	return root
end

return Backdrop
