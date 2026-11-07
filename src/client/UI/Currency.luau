--!strict
-- Green material token shared by the shop, level-up reroll and combat currency counter.
local Widgets = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local Currency = {}

function Currency.mount(parent: Instance, size: number): Frame
	local root = Widgets.create("Frame", {
		Name = "ShardIcon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	local gem = Widgets.create("Frame", {
		Name = "Token",
		BackgroundColor3 = Theme.shards,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.8),
		Rotation = 24,
		Parent = root,
	}, { Widgets.corner(UDim.new(0.5, 0)), Widgets.create("UIStroke", { Color = Theme.stroke, Thickness = 2 }) })
	Widgets.create("Frame", {
		Name = "Facet",
		BackgroundColor3 = Color3.fromRGB(154, 239, 132),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.12, 0.12),
		Size = UDim2.fromScale(0.3, 0.6),
		Parent = gem,
	}, { Widgets.corner(UDim.new(0.5, 0)) })
	return root
end

return Currency
