--!strict
-- Short on-screen messages from the server (Notify remote), stacked near the top and faded out.
-- Server services send them through Net.fireClient("Notify", player, text); other controllers through push (since B4:
-- item effects that pay out in the shop, ProcTextController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local SHOW_SECONDS = 3
local FADE_SECONDS = 0.4
local MAX_TOASTS = 3

local NotifyController = {}

local stack: Frame? = nil
local order = 0

local function show(parent: Frame, text: string)
	order += 1
	local toast = Widgets.panel({
		Name = "Toast",
		Size = UDim2.fromOffset(460, 0),
		LayoutOrder = order,
		Parent = parent,
	})
	local label = Widgets.label({
		Text = text,
		Font = Theme.fontBold,
		TextColor3 = Theme.accent,
		AutomaticSize = Enum.AutomaticSize.Y, -- long texts and several lines grow the toast
		Size = UDim2.new(1, 0, 0, Theme.textSize + 6),
		Parent = toast,
	})

	local toasts = {}
	for _, child in parent:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - MAX_TOASTS do
		toasts[i]:Destroy()
	end

	task.delay(SHOW_SECONDS, function()
		if not toast.Parent then
			return
		end
		local info = TweenInfo.new(FADE_SECONDS)
		TweenService:Create(toast, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		local stroke = toast:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		end
		task.wait(FADE_SECONDS)
		toast:Destroy()
	end)
end

function NotifyController.init()
	Net.onClient("Notify", function(text: unknown)
		if typeof(text) == "string" and stack then
			show(stack, text)
		end
	end)
end

-- Shows a message like one from the server (no-op before start).
function NotifyController.push(text: string)
	if stack then
		show(stack, text)
	end
end

function NotifyController.start()
	local screen = Widgets.screen("Notify", 5)
	screen.Enabled = true
	local frame = Widgets.create("Frame", {
		Name = "Stack",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.new(0, 480, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = screen,
	})
	Widgets.list(6).Parent = frame
	stack = frame
end

return NotifyController
