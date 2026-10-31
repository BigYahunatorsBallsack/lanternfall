--!strict
-- Responsive lobby navigation. Mounted by LobbyController after its feature controllers create their controls.
-- Keeps the existing buttons/remotes, but separates run preparation, difficulty, party and progression.
local Widgets = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local CharacterChoice = require(script.Parent.Parent.Controllers.CharacterChoice)
local ProfileCard = require(script.Parent.Parent.Controllers.ProfileCard)
local Layout = {}
local refresh: (() -> ())? = nil

function Layout.mount(screen: ScreenGui, choose: Frame, players: Frame, record: Frame, status: Frame)
	local backdrop = Widgets.create("Frame", {
		Name = "LobbyBackdrop",
		BackgroundColor3 = Theme.canvas,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = screen,
	})
	local heading = Widgets.create("Frame", {
		Name = "LobbyHeading",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -32, 0, 100),
		Position = UDim2.fromOffset(16, 8),
		Parent = backdrop,
	})
	Widgets.label({
		Name = "Brand",
		Text = "LANTERNFALL",
		TextSize = 32,
		Font = Theme.fontBold,
		TextColor3 = Theme.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -56, 0, 44),
		Parent = heading,
	})
	Widgets.unscaled(status)
	status.Parent = heading
	status.AnchorPoint = Vector2.new(0, 0)
	status.Position = UDim2.fromOffset(0, 48)
	status.Size = UDim2.new(1, 0, 0, 44)
	status.AutomaticSize = Enum.AutomaticSize.None
	status.BackgroundTransparency = 1
	for _, child in status:GetChildren() do
		if child:IsA("UIStroke") or child:IsA("UIPadding") then
			child:Destroy()
		elseif child:IsA("TextLabel") then
			child.TextSize = 17
			child.TextColor3 = Theme.textDim
			child.TextXAlignment = Enum.TextXAlignment.Left
			child.Size = UDim2.fromScale(1, 1)
		end
	end
	local nav = Widgets.create("Frame", {
		Name = "Navigation",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 110),
		Size = UDim2.new(1, -32, 0, 46),
		Parent = backdrop,
	})
	Widgets.list(8, Enum.FillDirection.Horizontal).Parent = nav
	local scroll = Widgets.create("ScrollingFrame", {
		Name = "LobbyContent",
		Position = UDim2.fromOffset(16, 174),
		Size = UDim2.new(1, -32, 1, -190),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = backdrop,
	})
	local content = Widgets.create("Frame", {
		Name = "Page",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Parent = scroll,
	})
	local list = Widgets.list(16)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Parent = content
	local danger = screen:FindFirstChild("Danger") :: Frame
	local pages = { choose, danger, players, record }
	local titles = { "PLAY", "DIFFICULTY", "PARTY", "COLLECTION" }
	local buttons = {}
	local selected = 1
	for index, panel in pages do
		Widgets.unscaled(panel)
		panel.Parent = content
		panel.AnchorPoint = Vector2.new(0, 0)
		panel.Position = UDim2.new()
		panel.Size = UDim2.new(1, -8, 0, 0)
		panel.AutomaticSize = Enum.AutomaticSize.Y
		panel.Visible = index == selected
		buttons[index] = Widgets.button({
			Name = "Tab" .. titles[index],
			Text = titles[index],
			TextSize = 16,
			Size = UDim2.new(0.25, -6, 1, 0),
			LayoutOrder = index,
			Parent = nav,
		}, function()
			ProfileCard.closeWindows()
			selected = index
			scroll.CanvasPosition = Vector2.new(0, 0)
			for i, page in pages do
				page.Visible = i == selected
				buttons[i].BackgroundColor3 = if i == selected then Theme.accent else Theme.button
				buttons[i].TextColor3 = if i == selected then Theme.accentText else Theme.text
			end
		end)
	end
	buttons[1].BackgroundColor3 = Theme.accent
	buttons[1].TextColor3 = Theme.accentText
	refresh = function()
		local area = screen.AbsoluteSize
		if typeof(area) ~= "Vector2" or area.X <= 0 then
			area = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
		end
		local width = math.min(920, math.max(240, area.X - 48))
		content.Size = UDim2.fromOffset(width, 0)
		CharacterChoice.resize(width - 36)
		for _, button in buttons do
			button.TextSize = if area.X < 600 then 12 else 16
		end
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if refresh then
			refresh()
		end
	end)
	Layout.refresh()
end

function Layout.refresh()
	if refresh then
		refresh()
	end
end
return Layout
