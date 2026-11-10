--!strict
-- Original green material sprite shared by shop prices, level-up rerolls and the combat currency counter.
local Widgets = require(script.Parent.Widgets)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Currency = {}

function Currency.mount(parent: Instance, size: number): Frame
	local root = Widgets.create("Frame", {
		Name = "ShardIcon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	Widgets.create("ImageLabel", {
		Name = "Material",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Fit,
		Image = Config.Sprites.images.material,
		Parent = root,
	})
	return root
end

function Currency.setKind(root: Instance?, kind: string?)
	if not root then
		return
	end
	local image = root:FindFirstChild("Material")
	if image and image:IsA("ImageLabel") then
		image.Image = if kind == "MaxHp"
			then require(script.Parent.StatImages).maxHp
			else Config.Sprites.images.material
	end
end
return Currency
