--!strict
-- Scrollable modal shell with a persistent close action. Feature controllers retain their panel and handlers.
local Widgets = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local Dialog = {}
function Dialog.wrap(panel: Frame, close: (() -> ())?, maxWidth: number?)
	local parent = panel.Parent
	local width = maxWidth or panel.Size.X.Offset
	Widgets.unscaled(panel)
	local root = Widgets.create("Frame", {
		Name = panel.Name .. "Dialog",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.canvas,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 20,
		Visible = panel.Visible,
		Parent = parent,
	})
	local scroll = Widgets.create("ScrollingFrame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.stroke,
		Position = UDim2.fromOffset(12, if close then 60 else 12),
		Size = UDim2.new(1, -24, 1, if close then -76 else -24),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = root,
	})
	panel.Parent = scroll
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.fromScale(0.5, 0)
	panel.ZIndex = 1
	panel.AutomaticSize = Enum.AutomaticSize.Y
	if close then
		Widgets.button({
			Name = "Dismiss",
			Text = "CLOSE  ×",
			TextSize = 16,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 8),
			Size = UDim2.fromOffset(124, 44),
			Parent = root,
		}, close)
	end
	local function resize()
		local area = root.AbsoluteSize
		if typeof(area) ~= "Vector2" or area.X <= 0 then
			area = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
		end
		panel.Size = UDim2.fromOffset(math.max(240, math.min(width, area.X - 40)), 0)
	end
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		root.Visible = panel.Visible
		if panel.Visible then
			scroll.CanvasPosition = Vector2.new(0, 0)
			resize()
		end
	end)
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	-- Nested lists must begin at the top when their canvas becomes taller than the viewport.
	for _, child in panel:GetDescendants() do
		if child:IsA("ScrollingFrame") then
			local list = child:FindFirstChildOfClass("UIListLayout")
			if list then
				list.VerticalAlignment = Enum.VerticalAlignment.Top
			end
		end
	end
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	end
	resize()
	return root
end
return Dialog
