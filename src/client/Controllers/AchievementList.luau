--!strict
-- Paket 13 lobby window: every achievement with its progress, Embers and what it unlocks (Config.Progress,
-- Util/ProgressRules), opened from the "ACHIEVEMENTS" button of ProfileCard. Reads the ProfileInfo ProfileCard keeps.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ProgressRules = require(Shared:WaitForChild("Util"):WaitForChild("ProgressRules"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local ROW_HEIGHT = 58

local AchievementList = {}

local window: Frame?
local rows: ScrollingFrame?

function AchievementList.isOpen(): boolean
	return window ~= nil and window.Visible
end

function AchievementList.setOpen(open: boolean)
	if window then
		window.Visible = open
	end
end

local function rowText(achievement: any, info: Types.ProfileInfo): (string, boolean)
	local done = info.achievements ~= nil and info.achievements[achievement.id] == true
	local goal = if achievement.winWith then 1 else achievement.goal or 1
	local current = math.min(goal, if info.progress then info.progress[achievement.id] or 0 else 0)
	local status = if done then "DONE" else `{current}/{goal}`
	local reward = `+{achievement.embers} Embers`
	local names = ProgressRules.unlockNames(achievement)
	if #names > 0 then
		reward ..= ` · unlocks {table.concat(names, ", ")}`
	end
	return `{achievement.name} · {status}\n{ProgressRules.text(achievement)} · {reward}`, done
end

function AchievementList.render(info: Types.ProfileInfo?)
	if not (rows and info) then
		return
	end
	Widgets.clearRows(rows)
	for index, achievement in Config.Progress.achievements do
		local text, done = rowText(achievement, info)
		Widgets.label({
			Name = `Achievement_{achievement.id}`,
			Text = text,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if done then Theme.accent else Theme.text,
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
			LayoutOrder = index,
			Parent = rows,
		})
	end
	rows.CanvasSize = UDim2.fromOffset(0, #Config.Progress.achievements * (ROW_HEIGHT + 4))
end

-- Builds the (hidden) window in the middle of the lobby screen.
function AchievementList.mount(screen: Instance)
	local panel = Widgets.panel({
		Name = "Achievements",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 0),
		Visible = false,
		ZIndex = 5,
		Parent = screen,
	})
	window = panel
	Widgets.list(8).Parent = panel
	Widgets.label({
		Text = "ACHIEVEMENTS",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		LayoutOrder = 1,
		Parent = panel,
	})
	local list = Widgets.create("ScrollingFrame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Size = UDim2.new(1, 0, 0, 360),
		LayoutOrder = 2,
		Parent = panel,
	})
	rows = list
	Widgets.list(4).Parent = list
	Widgets.button({
		Name = "CloseAchievements",
		Text = "CLOSE",
		TextSize = 18,
		Size = UDim2.fromOffset(200, 44),
		LayoutOrder = 3,
		Parent = panel,
	}, function()
		AchievementList.setOpen(false)
	end)
end

return AchievementList
