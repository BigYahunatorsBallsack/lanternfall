--!strict
-- Scrollable modal shell with a persistent close action. Feature controllers retain their panel and handlers.
local Widgets = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local Dialog = {}
local layers: { [ScreenGui]: { order: number, roots: { Frame } } } = {}
function Dialog.wrap(panel: Frame, close: (() -> ())?, maxWidth: number?)
	local parent = panel.Parent
	local width = maxWidth or panel.Size.X.Offset
	Widgets.unscaled(panel)
	local root = Widgets.create("Frame", {
		Name = panel.Name .. "Dialog",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.canvas,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 20,
		Visible = panel.Visible,
		Parent = parent,
	})
	local host = parent
	while host and not host:IsA("ScreenGui") do
		host = host.Parent
	end
	local function updateLayer()
		if not host then
			return
		end
		local gui = host :: ScreenGui
		local layer = layers[gui]
		local open = false
		for _, modal in layer.roots do
			open = open or modal.Visible
		end
		gui.DisplayOrder = if open then math.max(20, layer.order) else layer.order
	end
	if host then
		local gui = host :: ScreenGui
		layers[gui] = layers[gui] or { order = gui.DisplayOrder, roots = {} }
		table.insert(layers[gui].roots, root)
		updateLayer()
	end
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
	local function center()
		local available, size = scroll.AbsoluteSize, panel.AbsoluteSize
		if typeof(available) == "Vector2" and typeof(size) == "Vector2" then
			local y = math.max(0, math.floor((available.Y - size.Y) / 2))
			panel.Position = UDim2.new(0.5, 0, 0, y)
		end
	end
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(center)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(center)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		root.Visible = panel.Visible
		updateLayer()
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
