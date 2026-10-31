--!strict
-- Tooltips (Paket 14, DESIGN.md section 13): a small panel with a title and rich-text lines for HUD rows, stat rows and
-- weapon slots. With a mouse it follows the pointer while it is over the object; on touch a tap opens it next to
-- the object and it closes after Config.Settings.tooltip.touchSeconds or with the next tap. The text is asked for
-- when it opens, so it is always current. Used by HUDController, StatsController and ShopController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Settings = Config.Settings.tooltip
local OFFSET = 16 -- pixels between the pointer and the panel
local EDGE = 8 -- pixels the panel keeps from the screen edges

-- Returns the title and the lines (rich text), or nil for no tooltip right now.
export type Provider = () -> (string?, string?)

local Tooltip = {}

local screen: ScreenGui? = nil
local panel: Frame
local titleLabel: TextLabel
local bodyLabel: TextLabel
local owner: GuiObject? = nil -- the object whose tooltip is open
local openedAt = 0
local tapGuard = false -- the tap that opened a tooltip must not close it
local providers: { [GuiObject]: Provider } = setmetatable({}, { __mode = "k" }) :: any

local function build()
	if screen then
		return
	end
	local gui = Widgets.screen("Tooltip", 50)
	gui.IgnoreGuiInset = true -- positions are raw pointer positions
	gui.Enabled = true
	screen = gui
	panel = Widgets.panel({
		Name = "Tooltip",
		Size = UDim2.fromOffset(Settings.width, 0),
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	Widgets.list(4).Parent = panel
	titleLabel = Widgets.label({
		Name = "Title",
		Font = Theme.fontBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 10,
		LayoutOrder = 1,
		Parent = panel,
	})
	bodyLabel = Widgets.label({
		Name = "Body",
		RichText = true,
		TextSize = 15,
		TextColor3 = Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 10,
		LayoutOrder = 2,
		Parent = panel,
	})
	-- A tap anywhere else closes a tooltip that a tap opened.
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch and owner and not tapGuard then
			Tooltip.hide()
		end
	end)
end

-- Places the panel next to `at` (screen pixels) and keeps it on the screen.
local function place(at: Vector2)
	local viewport = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
	local size = panel.AbsoluteSize or Vector2.new(Settings.width, 100)
	local x = at.X + OFFSET
	local y = at.Y + OFFSET
	if x + size.X > viewport.X - EDGE then
		x = at.X - OFFSET - size.X
	end
	if y + size.Y > viewport.Y - EDGE then
		y = viewport.Y - EDGE - size.Y
	end
	panel.Position = UDim2.fromOffset(math.max(EDGE, x), math.max(EDGE, y))
end

local function show(object: GuiObject, provider: Provider, at: Vector2): boolean
	local title, body = provider()
	if not title then
		return false
	end
	titleLabel.Text = title
	bodyLabel.Text = body or ""
	bodyLabel.Visible = body ~= nil and body ~= ""
	owner = object
	openedAt = os.clock()
	panel.Visible = true
	place(at)
	task.defer(place, at) -- again once the panel has its size
	return true
end

function Tooltip.hide()
	owner = nil
	if screen then
		panel.Visible = false
	end
end

-- Gives `object` a tooltip. `provider` is called each time it opens.
function Tooltip.attach(object: GuiObject, provider: Provider)
	build()
	providers[object] = provider
	object.MouseEnter:Connect(function(x: number, y: number)
		if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
			show(object, provider, Vector2.new(x, y))
		end
	end)
	object.MouseMoved:Connect(function(x: number, y: number)
		if owner == object then
			place(Vector2.new(x, y))
		end
	end)
	object.MouseLeave:Connect(function()
		if owner == object then
			Tooltip.hide()
		end
	end)
	object.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if owner == object then
			Tooltip.hide()
			return
		end
		local position = object.AbsolutePosition + Vector2.new(0, object.AbsoluteSize.Y)
		if show(object, provider, position) then
			tapGuard = true
			task.defer(function()
				tapGuard = false
			end)
			local opened = openedAt
			task.delay(Settings.touchSeconds, function()
				if owner == object and openedAt == opened then
					Tooltip.hide()
				end
			end)
		end
	end)
	object.AncestryChanged:Connect(function()
		if owner == object and not object.Parent then
			Tooltip.hide()
		end
	end)
end

-- The open tooltip's title and lines, or nil (tests).
function Tooltip.getShown(): (string?, string?)
	if not (screen and owner and panel.Visible) then
		return nil, nil
	end
	return titleLabel.Text, bodyLabel.Text
end

-- Opens the tooltip attached to `object` (tests); false if it has none or nothing to show.
function Tooltip.open(object: GuiObject): boolean
	local provider = providers[object]
	return provider ~= nil and show(object, provider, Vector2.new(0, 0))
end

return Tooltip
