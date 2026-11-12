--!strict
-- Displays a generated fog bitmap without uploads; allocation failure uses a bounded GUI-cell fallback with the same mask.
local AssetService = game:GetService("AssetService")
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config.NativeFog).runtimeCompatibility
local Surface = {}
function Surface.new(parent: Instance, aspect: number): any
	local height = C.renderHeight
	local width = math.max(1, math.ceil(height * aspect))
	local image: any = nil
	local label: ImageLabel? = nil
	local ok = pcall(function()
		image = AssetService:CreateEditableImage({ Size = Vector2.new(width, height) })
		if not image then
			return
		end
		local created = Instance.new("ImageLabel")
		label = created
		created.BackgroundTransparency = 1
		created.Size = UDim2.fromScale(1, 1)
		created.ImageContent = Content.fromObject(image)
		created.Parent = parent
	end)
	if not ok or not image then
		if label then
			label:Destroy()
		end
		if image then
			image:Destroy()
		end
		image, label = nil, nil
		height = C.fallbackHeight
		width = math.max(1, math.ceil(height * aspect))
	end
	local cells = {}
	if not image then
		for y = 0, height - 1 do
			for x = 0, width - 1 do
				local cell = Instance.new("Frame")
				cell.Name = "FogCell"
				cell.BackgroundColor3 = Color3.new(0, 0, 0)
				cell.BorderSizePixel = 0
				cell.Position = UDim2.fromScale(x / width, y / height)
				cell.Size = UDim2.new(1 / width, 1, 1 / height, 1)
				cell.Parent = parent
				table.insert(cells, cell)
			end
		end
	end
	return {
		width = width,
		height = height,
		bitmap = image ~= nil,
		write = function(pixels: buffer)
			if image then
				image:WritePixelsBuffer(Vector2.zero, Vector2.new(width, height), pixels)
			else
				for i, cell in cells do
					cell.BackgroundTransparency = 1 - buffer.readu8(pixels, (i - 1) * 4 + 3) / 255
				end
			end
		end,
		destroy = function()
			if label then
				label:Destroy()
			end
			if image then
				image:Destroy()
			end
			for _, cell in cells do
				cell:Destroy()
			end
		end,
	}
end
return Surface
