--!strict
-- Paket 18 lobby window "LEADERBOARDS" (DESIGN.md section 11): this week's best wave and most kills per danger level,
-- for everyone or the player's friends, with the player's own best and when the week resets. Asks the server for a
-- page (RequestLeaderboard) whenever the board, danger level or scope changes and shows the Leaderboard answer.
-- Mounted by ProfileCard next to QUESTS; one lobby window at a time.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local LeaderboardRules = require(Shared:WaitForChild("Util"):WaitForChild("LeaderboardRules"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local ROW_HEIGHT = 30
local REQUEST_DELAY = 0.25
local GIVE_UP_SECONDS = 5
local SCOPE_TEXT: { [string]: string } = { Global = "EVERYONE", Friends = "FRIENDS" }

local LeaderboardController = {}

local window: Frame? = nil
local rows: ScrollingFrame? = nil
local infoLabel: TextLabel? = nil
local boardButtons: { [string]: TextButton } = {}
local dangerButtons: { [number]: TextButton } = {}
local scopeButtons: { [string]: TextButton } = {}

local board = Config.Leaderboards.boards[1].key
local danger = 0
local scope = Config.Leaderboards.scopes[1]
local page: Types.LeaderboardPage? = nil -- the page shown (may belong to another selection while loading)
local waiting = false
local askedAt = 0 -- os.clock() of the last request; after GIVE_UP_SECONDS without an answer a click asks again

function LeaderboardController.isOpen(): boolean
	return window ~= nil and window.Visible
end

function LeaderboardController.get(): Types.LeaderboardPage?
	return page
end

local function highlight(buttons: { [any]: TextButton }, active: any)
	for key, button in buttons do
		button.BackgroundColor3 = if key == active then Theme.accent else Theme.button
		button.TextColor3 = if key == active then Theme.accentText else Theme.text
	end
end

local function infoText(shown: Types.LeaderboardPage): string
	local lines = {}
	table.insert(
		lines,
		if shown.mine > 0
			then `Your best this week: {LeaderboardRules.text(shown.board, shown.mine)}`
			else "No run on this board this week yet"
	)
	local left = shown.resetsIn - (workspace:GetServerTimeNow() - shown.sentAt)
	table.insert(lines, `New week in {Format.duration(left)} (Monday 00:00 UTC)`)
	if not shown.saved then
		table.insert(lines, "Studio test: scores are only kept in this server")
	elseif shown.failed then
		table.insert(lines, "Roblox did not answer, try again in a minute")
	end
	return table.concat(lines, "\n")
end

function LeaderboardController.render()
	highlight(boardButtons, board)
	highlight(dangerButtons, danger)
	highlight(scopeButtons, scope)
	local container = rows
	if not container then
		return
	end
	Widgets.clearRows(container)
	local shown = page
	local current = shown ~= nil and shown.board == board and shown.danger == danger and shown.scope == scope
	if infoLabel then
		infoLabel.Text = if shown and current then infoText(shown) else ""
	end
	if not (shown and current) then
		Widgets.label({ Text = "Loading...", TextSize = 15, LayoutOrder = 1, Parent = container })
		container.CanvasSize = UDim2.fromOffset(0, ROW_HEIGHT)
		return
	end
	local me = Players.LocalPlayer
	for _, entry in shown.entries do
		local mine = me ~= nil and entry.userId == me.UserId
		Widgets.label({
			Name = `Rank_{entry.rank}`,
			Text = `{entry.rank}.  {entry.name}  ·  {LeaderboardRules.text(shown.board, entry.score)}`,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if mine then Theme.accent else Theme.text,
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
			LayoutOrder = entry.rank,
			Parent = container,
		})
	end
	if #shown.entries == 0 then
		Widgets.label({
			Text = if shown.scope == "Friends"
				then "None of your friends has a score here this week"
				else "Nobody has a score here this week. Be the first!",
			TextSize = 15,
			TextColor3 = Theme.textDim,
			LayoutOrder = 1,
			Parent = container,
		})
	end
	container.CanvasSize = UDim2.fromOffset(0, math.max(1, #shown.entries) * (ROW_HEIGHT + 2))
end

-- Clicks within REQUEST_DELAY become one request for the latest selection (the remote is rate limited).
local function request()
	LeaderboardController.render()
	if waiting and os.clock() - askedAt < GIVE_UP_SECONDS then
		return
	end
	waiting = true
	askedAt = os.clock()
	task.delay(REQUEST_DELAY, function()
		Net.fireServer("RequestLeaderboard", board, danger, scope)
	end)
end

-- Picks a board, danger level and scope (nil keeps the current one) and asks the server for it.
function LeaderboardController.show(newBoard: string?, newDanger: number?, newScope: string?)
	board = newBoard or board
	danger = newDanger or danger
	scope = newScope or scope
	request()
end

-- One lobby window at a time: opening this closes the others.
function LeaderboardController.setOpen(open: boolean)
	if not window then
		return
	end
	if open then
		require(script.Parent.ProfileCard).closeWindows()
	end
	window.Visible = open
	if open then
		request()
	end
end

local function tabRow(name: string, order: number, parent: Instance): Frame
	local row = Widgets.create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = order,
		Parent = parent,
	})
	Widgets.list(6, Enum.FillDirection.Horizontal).Parent = row
	return row
end

-- Adds the LEADERBOARDS button to `row` (next to QUESTS) and builds the hidden window on `screen`.
function LeaderboardController.mount(row: Frame, screen: Instance)
	Widgets.button({
		Name = "OpenLeaderboards",
		Text = "LEADERBOARDS",
		TextSize = 16,
		Size = UDim2.new(0.5, -3, 1, 0),
		LayoutOrder = 2,
		Parent = row,
	}, function()
		LeaderboardController.setOpen(not LeaderboardController.isOpen())
	end)

	local panel = Widgets.panel({
		Name = "Leaderboards",
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
		Text = "WEEKLY LEADERBOARDS",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		LayoutOrder = 1,
		Parent = panel,
	})
	local boards = tabRow("Boards", 2, panel)
	local boardList = Config.Leaderboards.boards
	for index, entry in boardList do
		boardButtons[entry.key] = Widgets.button({
			Name = `Board_{entry.key}`,
			Text = entry.name,
			TextSize = 14,
			Size = UDim2.new(1 / #boardList, -5, 1, 0),
			LayoutOrder = index,
			Parent = boards,
		}, function()
			LeaderboardController.show(entry.key, nil, nil)
		end)
	end
	local dangers = tabRow("Dangers", 3, panel)
	local levels = #Config.Difficulty.levels
	for level = 0, levels - 1 do
		dangerButtons[level] = Widgets.button({
			Name = `Danger_{level}`,
			Text = `D{level}`,
			TextSize = 14,
			Size = UDim2.new(1 / levels, -5, 1, 0),
			LayoutOrder = level + 1,
			Parent = dangers,
		}, function()
			LeaderboardController.show(nil, level, nil)
		end)
	end
	local scopes = tabRow("Scopes", 4, panel)
	local scopeList = Config.Leaderboards.scopes
	for index, key in scopeList do
		scopeButtons[key] = Widgets.button({
			Name = `Scope_{key}`,
			Text = SCOPE_TEXT[key] or key,
			TextSize = 14,
			Size = UDim2.new(1 / #scopeList, -5, 1, 0),
			LayoutOrder = index,
			Parent = scopes,
		}, function()
			LeaderboardController.show(nil, nil, key)
		end)
	end
	infoLabel = Widgets.label({
		Name = "LeaderboardInfo",
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = Theme.textDim,
		Size = UDim2.new(1, 0, 0, 50),
		LayoutOrder = 5,
		Parent = panel,
	})
	local scroll = Widgets.create("ScrollingFrame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Size = UDim2.new(1, 0, 0, 280),
		LayoutOrder = 6,
		Parent = panel,
	})
	rows = scroll
	Widgets.list(2).Parent = scroll
	Widgets.button({
		Name = "CloseLeaderboards",
		Text = "CLOSE",
		TextSize = 18,
		Size = UDim2.fromOffset(200, 44),
		LayoutOrder = 7,
		Parent = panel,
	}, function()
		LeaderboardController.setOpen(false)
	end)
	LeaderboardController.render()
end

function LeaderboardController.init()
	Net.onClient("Leaderboard", function(payload: Types.LeaderboardPage)
		page = payload
		waiting = false
		if payload.board ~= board or payload.danger ~= danger or payload.scope ~= scope then
			request() -- the selection changed while this page was on its way
		end
		LeaderboardController.render()
	end)
end

-- Whether a page was asked for and has not arrived yet (tests).
function LeaderboardController.isWaiting(): boolean
	return waiting
end

return LeaderboardController
