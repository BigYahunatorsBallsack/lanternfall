--!strict
-- Original horned Gloom face for the upcoming wave strip. Mounted by ShopComposition.
local Widgets = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local ChallengeIcon = {}

function ChallengeIcon.mount(slot: Frame)
	local root = Widgets.create("Frame", {
		Name = "ChallengeArt",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(48, 44),
		Position = UDim2.fromOffset(6, 2),
		Parent = slot,
	})
	for _, x in { 5, 34 } do
		Widgets.create("Frame", {
			BackgroundColor3 = Theme.text,
			BorderSizePixel = 0,
			Rotation = if x == 5 then -24 else 24,
			Size = UDim2.fromOffset(8, 17),
			Position = UDim2.fromOffset(x, 2),
			Parent = root,
		}, { Widgets.corner(), Widgets.create("UIStroke", { Color = Theme.stroke, Thickness = 2 }) })
	end
	local head = Widgets.create("Frame", {
		Name = "Head",
		BackgroundColor3 = Theme.gloom,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(38, 32),
		Position = UDim2.fromOffset(5, 12),
		Parent = root,
	}, { Widgets.corner(UDim.new(0.5, 0)), Widgets.create("UIStroke", { Color = Theme.stroke, Thickness = 2 }) })
	for _, x in { 7, 24 } do
		Widgets.create("Frame", {
			BackgroundColor3 = Theme.danger,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(6, 7),
			Position = UDim2.fromOffset(x, 12),
			Parent = head,
		}, { Widgets.corner(UDim.new(0.5, 0)), Widgets.create("UIStroke", { Color = Theme.stroke, Thickness = 2 }) })
	end
	local symbol = slot:FindFirstChild("Symbol")
	if symbol and symbol:IsA("TextLabel") then
		symbol.Visible = false
	end
end

function ChallengeIcon.setKind(slot: Frame, kind: string)
	local art = slot:FindFirstChild("ChallengeArt")
	local head = art and art:FindFirstChild("Head")
	if head and head:IsA("Frame") then
		head.BackgroundColor3 = if kind == "Elite" then Theme.gloom else Color3.fromRGB(178, 88, 98)
	end
end

return ChallengeIcon
