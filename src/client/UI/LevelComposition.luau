--!strict
-- Reference level-up card geometry. Mounted by LevelUpController; all choices and deadlines stay in that controller.
local Widgets = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local Layout = require(script.Parent.ShopLayout)
local Currency = require(script.Parent.Currency)
local Composition = {}

local function place(object: GuiObject, x: number, y: number, width: number, height: number)
	object.AnchorPoint = Vector2.new(0, 0)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(width, height)
end

function Composition.mount(ctx: any)
	local storage = Widgets.create("Folder", { Parent = ctx.screen })
	for _, child in ctx.panel:GetChildren() do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			child.Parent = storage
		end
	end
	Widgets.unscaled(ctx.panel)
	ctx.panel:FindFirstChildOfClass("UIStroke").Thickness = 0
	ctx.panel.BackgroundTransparency = 1
	ctx.panel.AutomaticSize = Enum.AutomaticSize.None
	local scroll = Widgets.create("ScrollingFrame", {
		Name = "LevelChoices",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = ctx.screen,
	})
	ctx.panel.Parent = scroll
	local scale = Widgets.create("UIScale", { Parent = ctx.panel })
	local grid = ctx.cardRow:FindFirstChildOfClass("UIGridLayout")
	for _, view in ctx.cards do
		for _, child in view.button:GetChildren() do
			if child:IsA("UIListLayout") or child:IsA("UIPadding") then
				child.Parent = storage
			end
		end
		view.name.Font = Theme.font
		view.badge.Font = Theme.font
		view.badge.TextColor3 = Theme.statLabel
		view.badge.TextSize = 16
		view.name.TextXAlignment, view.name.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
		view.detail.TextXAlignment = Enum.TextXAlignment.Left
		view.badge.TextXAlignment = Enum.TextXAlignment.Left
		local key = view.button:FindFirstChild("Key")
		if key then
			key.Visible = false
		end
		local choose = Widgets.label({
			Name = "Choose",
			Text = "Choose",
			TextSize = 28,
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.price,
			Parent = view.button,
		})
		Widgets.corner().Parent = choose
		view.button.MouseEnter:Connect(function()
			choose.BackgroundColor3, choose.TextColor3 = Theme.accent, Theme.accentText
		end)
		view.button.MouseLeave:Connect(function()
			choose.BackgroundColor3, choose.TextColor3 = Theme.price, Theme.text
		end)
	end
	Currency.mount(ctx.reroll, 28).Position = UDim2.new(1, -42, 0.5, -14)
	ctx.title.TextStrokeTransparency = 0
	local function resize()
		local area = ctx.screen.AbsoluteSize
		if typeof(area) ~= "Vector2" or area.X <= 0 then
			area = workspace.CurrentCamera.ViewportSize
		end
		local layout = Layout.measure(area)
		local compact = layout.compact
		local width = if compact then area.X - 24 else layout.leftWidth - 28
		local columns = if compact then (if width < 560 then 1 else 2) else #ctx.cards
		local cardWidth = (width - (columns - 1) * 6) / columns
		local cardHeight = if compact then 230 else 232
		local rows = math.ceil(#ctx.cards / columns)
		local cardTop = if compact then 70 else 68
		local height = rows * (cardHeight + 8) + cardTop + 84
		scale.Scale = layout.scale
		place(
			scroll,
			12,
			if compact then 96 else 164 * layout.scale,
			width * layout.scale,
			area.Y - (if compact then 164 else 174 * layout.scale)
		)
		place(ctx.panel, 0, 0, width, height)
		place(ctx.title, 0, 0, width, 50)
		ctx.title.TextSize = if compact then 32 else 40
		ctx.subtitle.Visible = false
		grid.CellSize = UDim2.fromOffset(cardWidth, cardHeight)
		grid.CellPadding = UDim2.fromOffset(6, 8)
		grid.FillDirectionMaxCells = columns
		place(ctx.cardRow, 0, cardTop, width, rows * (cardHeight + 8))
		for _, view in ctx.cards do
			place(view.icon, 12, 12, 64, 64)
			view.icon.BackgroundTransparency = 0
			view.icon.BackgroundColor3 = Theme.price
			view.icon:FindFirstChildOfClass("UICorner").CornerRadius = Theme.corner
			place(view.name, 86, 12, cardWidth - 98, 28)
			view.name.TextSize = 18
			place(view.badge, 86, 42, cardWidth - 98, 28)
			place(view.detail, 12, 98, cardWidth - 24, 64)
			view.detail.TextSize = 16
			place(view.button.Choose, 12, cardHeight - 46, cardWidth - 24, 34)
		end
		local bottom = cardTop + rows * (cardHeight + 8)
		place(ctx.timer, 0, bottom + 6, width, 3)
		place(ctx.reroll, math.max(0, (width - 320) / 2), bottom + 30, math.min(width, 320), 44)
		ctx.reroll.TextSize = 24
	end
	ctx.screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	end
	resize()
end

return Composition
