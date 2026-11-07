--!strict
-- Quiet stones and grass behind lobby/shop controls; mounted by LobbyLayout and ShopController.
local Widgets = require(script.Parent.Widgets)
local Backdrop = {}

function Backdrop.mount(parent: Instance): Frame
	local root = Widgets.create("Frame", {
		Name = "MenuBackground",
		BackgroundColor3 = Color3.fromRGB(94, 90, 83),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = parent,
	})
	for index = 1, 48 do
		local x, y = ((index * 73) % 101) / 100, ((index * 47) % 101) / 100
		local stone = Widgets.create("Frame", {
			Name = "Stone",
			BackgroundColor3 = Color3.fromRGB(75, 73, 66),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(22 + index % 4 * 5, 13 + index % 3 * 4),
			Rotation = index % 5 * 16 - 32,
			ZIndex = 0,
			Parent = root,
		}, {
			Widgets.corner(UDim.new(0.35, 0)),
			Widgets.create("UIStroke", { Color = Color3.fromRGB(48, 47, 42), Thickness = 3, Transparency = 0.65 }),
		})
		if index % 3 == 0 then
			for blade = 1, 3 do
				Widgets.create("Frame", {
					Name = "Grass",
					BorderSizePixel = 0,
					BackgroundColor3 = Color3.fromRGB(101, 109, 73),
					BackgroundTransparency = 0.5,
					Size = UDim2.fromOffset(4, 18),
					Position = UDim2.fromOffset(blade * 5, -6),
					Rotation = (blade - 2) * 23,
					ZIndex = 0,
					Parent = stone,
				}, { Widgets.corner(UDim.new(0.5, 0)) })
			end
		end
	end
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
