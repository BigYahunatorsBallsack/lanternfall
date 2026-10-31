--!strict
-- Paket 15: hub parties and portals on the lobby screen. Keeps the latest PartyState (which place this is, the party,
-- invites, quick join) and builds the lobby parts for it: the party and player list with Invite/Kick/Leave, the
-- buttons Play solo / Start party run / Quick join, the invite popup and on the run place "Back to hub". Mounted and
-- rendered by LobbyController (DangerChoice reads the party's options, ResultsController the role). Sends
-- InviteToParty, AnswerInvite, LeaveParty, KickFromParty, PlayFromHub and ReturnToHub.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local BUTTON_COOLDOWN = 0.3 -- seconds; keeps taps below the server rate limits
local LIST_MAX_HEIGHT = 230 -- the party and player list scrolls beyond this (24 players in a hub)
local ROW_HEIGHT = 30

local STATUS_TEXT: { [string]: string } = {
	Party = "in a party",
	Queue = "in quick join",
	Busy = "busy",
	Solo = "",
}

local PartyController = {}

-- (state: Types.PartyState)
PartyController.Changed = Signal.new()

local state: Types.PartyState? = nil
local lastPress = 0

local actions: Frame? = nil
local primaryButton: TextButton? = nil
local quickButton: TextButton? = nil
local backButton: TextButton? = nil
local hubList: ScrollingFrame? = nil
local defaultRows: Frame? = nil
local listTitle: TextLabel? = nil
local invitePanel: Frame? = nil
local inviteLabel: TextLabel? = nil
local renderedRows = ""

local function canPress(): boolean
	local now = os.clock()
	if now - lastPress < BUTTON_COOLDOWN then
		return false
	end
	lastPress = now
	return true
end

local function myId(): number
	return Players.LocalPlayer.UserId
end

function PartyController.init()
	Net.onClient("PartyState", function(received: Types.PartyState)
		state = received
		PartyController.Changed:Fire(received)
	end)
end

function PartyController.get(): Types.PartyState?
	return state
end

-- "Hub", "Run" or "Single" ("Single" until the server said otherwise).
function PartyController.getRole(): string
	return if state then state.role else "Single"
end

function PartyController.isHub(): boolean
	return PartyController.getRole() == "Hub"
end

-- Leads the party, or plays solo.
function PartyController.isLeader(): boolean
	return state == nil or state.leaderId == myId()
end

-- Status line on the hub and run place; nil = LobbyController's usual text.
function PartyController.statusText(): string?
	local current = state
	if not current then
		return nil
	end
	local now = RunStateController.now()
	if current.teleporting then
		return if current.role == "Run" then "Teleporting to the hub..." else "Teleporting to your run..."
	end
	if current.role == "Run" then
		local group = current.group
		if group and group.arrived < group.expected then
			return `Waiting for your group ({group.arrived}/{group.expected})...`
		end
		return nil
	elseif current.role ~= "Hub" then
		return nil
	end
	if current.launchAt then
		return `Party run starts in {math.max(0, math.ceil(current.launchAt - now))}`
	end
	local queue = current.queue
	if queue then
		if queue.startsAt then
			local seconds = math.max(0, math.ceil(queue.startsAt - now))
			return `Quick join: group of {queue.groupSize} found - leaving in {seconds}`
		end
		return `Quick join: waiting for players ({queue.groupSize}/{Config.Places.party.maxSize})...`
	end
	local run = RunStateController.get()
	local me = RunStateController.getLocalPlayer()
	if run and run.phase ~= "Lobby" and not (me and me.participant) then
		return `A test run is going in this server ({Format.time(RunStateController.getElapsed())})`
	end
	if not PartyController.isLeader() then
		return "Your party leader starts the run"
	end
	return "Pick a character, then Play solo, Party run or Quick join"
end

-- Rows ------------------------------------------------------------------------------

local function row(parent: Instance, order: number, text: string, color: Color3?): Frame
	local frame = Widgets.create("Frame", {
		Name = `Row{order}`,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
		LayoutOrder = order,
		Parent = parent,
	})
	Widgets.label({
		Name = "Text",
		Text = text,
		TextColor3 = color or Theme.text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Size = UDim2.new(1, -86, 1, 0),
		Parent = frame,
	})
	return frame
end

local function rowButton(frame: Frame, name: string, text: string, onClick: () -> ()): TextButton
	return Widgets.button({
		Name = name,
		Text = text,
		TextSize = 14,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(80, ROW_HEIGHT - 4),
		Parent = frame,
	}, onClick)
end

local function header(parent: Instance, order: number, text: string)
	Widgets.label({
		Name = `Header{order}`,
		Text = text,
		Font = Theme.fontBold,
		TextSize = 14,
		TextColor3 = Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -8, 0, 20),
		LayoutOrder = order,
		Parent = parent,
	})
end

-- A cheap fingerprint, so the list is only rebuilt when it changes (taps on a rebuilt button would get lost).
local function rowsKey(current: Types.PartyState): string
	local parts = { tostring(current.leaderId) }
	for _, member in current.members do
		table.insert(parts, `{member.userId}:{member.name}`)
	end
	table.insert(parts, "|")
	for _, other in current.players do
		table.insert(parts, `{other.userId}:{other.name}:{other.status}:{other.partySize}:{other.invited}`)
	end
	return table.concat(parts, ",")
end

local function renderRows(current: Types.PartyState)
	local list = hubList
	if not list then
		return
	end
	local key = rowsKey(current)
	if key == renderedRows then
		return
	end
	renderedRows = key
	Widgets.clearRows(list)
	local maxSize = Config.Places.party.maxSize
	local leading = current.leaderId == myId()
	local inParty = #current.members > 1
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	header(list, nextOrder(), if inParty then `YOUR PARTY ({#current.members}/{maxSize})` else "YOUR PARTY (solo)")
	for _, member in current.members do
		local isLeader = member.userId == current.leaderId
		local isMe = member.userId == myId()
		local text = `{if isLeader then "★ " else ""}{member.name}{if isMe then " (you)" else ""}`
		local frame = row(list, nextOrder(), text, if isLeader then Theme.accent else Theme.text)
		if leading and not isMe then
			local targetId = member.userId
			rowButton(frame, "Kick", "Kick", function()
				if canPress() then
					Net.fireServer("KickFromParty", targetId)
				end
			end)
		end
	end
	if inParty then
		local frame = row(list, nextOrder(), "", nil)
		local leave = rowButton(frame, "LeaveParty", "Leave", function()
			if canPress() then
				Net.fireServer("LeaveParty")
			end
		end)
		leave.BackgroundColor3 = Theme.danger
		leave.TextColor3 = Theme.accentText
	end

	header(list, nextOrder(), `PLAYERS HERE ({#current.players})`)
	if #current.players == 0 then
		row(list, nextOrder(), "Nobody else yet - invite friends to the game", Theme.textDim)
	end
	local canInvite = leading and #current.members < maxSize and current.queue == nil
	for _, other in current.players do
		local status = STATUS_TEXT[other.status] or ""
		if other.status == "Party" then
			status = `in a party ({other.partySize})`
		end
		local text = if status ~= "" then `{other.name} · {status}` else other.name
		local frame = row(list, nextOrder(), text, if other.status == "Solo" then Theme.text else Theme.textDim)
		if other.invited then
			Widgets.label({
				Name = "Invited",
				Text = "invited",
				TextSize = 13,
				TextColor3 = Theme.success,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(80, ROW_HEIGHT - 4),
				Parent = frame,
			})
		elseif canInvite and other.status == "Solo" then
			local targetId = other.userId
			rowButton(frame, "Invite", "Invite", function()
				if canPress() then
					Net.fireServer("InviteToParty", targetId)
				end
			end)
		end
	end
end

-- Mounting --------------------------------------------------------------------------

-- The party and player list goes into the lobby's player panel; `rows` (the plain list) hides on the hub.
function PartyController.mountRows(panel: Frame, rows: Frame, title: TextLabel?)
	defaultRows = rows
	listTitle = title
	local list = Widgets.create("ScrollingFrame", {
		Name = "HubList",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Size = UDim2.new(1, 0, 0, LIST_MAX_HEIGHT),
		Visible = false,
		LayoutOrder = 2,
		Parent = panel,
	})
	Widgets.list(2).Parent = list
	hubList = list
end

-- Play solo / Start party run / Quick join in the choose card (the hub has no READY); "Back to hub" on the run place.
function PartyController.mountActions(card: Frame)
	local frame = Widgets.create("Frame", {
		Name = "HubActions",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 60),
		Visible = false,
		LayoutOrder = 6,
		Parent = card,
	})
	Widgets.list(10, Enum.FillDirection.Horizontal).Parent = frame
	primaryButton = Widgets.button({
		Name = "Play",
		Text = "PLAY SOLO",
		TextSize = 22,
		Size = UDim2.new(0.5, -5, 1, 0),
		LayoutOrder = 1,
		Parent = frame,
	}, function()
		local current = state
		if not (current and canPress()) or current.teleporting then
			return
		end
		if not PartyController.isLeader() then
			return
		end
		Net.fireServer("PlayFromHub", if #current.members > 1 then "Party" else "Solo")
	end)
	quickButton = Widgets.button({
		Name = "QuickJoin",
		Text = "QUICK JOIN",
		TextSize = 22,
		Size = UDim2.new(0.5, -5, 1, 0),
		LayoutOrder = 2,
		Parent = frame,
	}, function()
		local current = state
		if not (current and canPress()) or current.teleporting then
			return
		end
		Net.fireServer("PlayFromHub", if current.queue then "Cancel" else "QuickJoin")
	end)
	actions = frame

	backButton = Widgets.button({
		Name = "BackToHub",
		Text = "BACK TO HUB",
		TextSize = 20,
		Size = UDim2.fromOffset(320, 48),
		Visible = false,
		LayoutOrder = 7,
		Parent = card,
	}, function()
		if canPress() then
			Net.fireServer("ReturnToHub")
		end
	end)
end

-- "<name> invites you to their party" with JOIN / NO, under the status line.
function PartyController.mountInvite(screen: ScreenGui)
	local panel = Widgets.panel({
		Name = "Invite",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(420, 0),
		Visible = false,
		Parent = screen,
	})
	Widgets.list(8).Parent = panel
	inviteLabel = Widgets.label({ Name = "Text", Font = Theme.fontBold, LayoutOrder = 1, Parent = panel })
	local buttons = Widgets.create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 2,
		Parent = panel,
	})
	Widgets.list(10, Enum.FillDirection.Horizontal).Parent = buttons
	local function answer(accept: boolean)
		local current = state
		local invite = current and current.invite
		if invite and canPress() then
			Net.fireServer("AnswerInvite", invite.fromId, accept)
		end
	end
	local join = Widgets.button({
		Name = "Join",
		Text = "JOIN",
		Size = UDim2.fromOffset(150, 44),
		LayoutOrder = 1,
		Parent = buttons,
	}, function()
		answer(true)
	end)
	join.BackgroundColor3 = Theme.success
	join.TextColor3 = Theme.accentText
	Widgets.button({
		Name = "Decline",
		Text = "NO",
		Size = UDim2.fromOffset(150, 44),
		LayoutOrder = 2,
		Parent = buttons,
	}, function()
		answer(false)
	end)
	invitePanel = panel
end

-- Rendering -------------------------------------------------------------------------

local function renderActions(current: Types.PartyState)
	local primary, quick = primaryButton, quickButton
	if not (primary and quick) then
		return
	end
	local inParty = #current.members > 1
	local leading = current.leaderId == myId()
	if current.teleporting then
		primary.Text = "TELEPORTING..."
		primary.BackgroundColor3 = Theme.button
		primary.TextColor3 = Theme.textDim
	elseif not leading then
		primary.Text = "LEADER STARTS"
		primary.BackgroundColor3 = Theme.button
		primary.TextColor3 = Theme.textDim
	elseif current.launchAt then
		primary.Text = "CANCEL START"
		primary.BackgroundColor3 = Theme.button
		primary.TextColor3 = Theme.text
	else
		primary.Text = if inParty
			then `START PARTY RUN ({#current.members}/{Config.Places.party.maxSize})`
			else "PLAY SOLO"
		primary.BackgroundColor3 = Theme.success
		primary.TextColor3 = Theme.accentText
	end
	quick.Visible = leading
	quick.Text = if current.queue then "CANCEL QUICK JOIN" else "QUICK JOIN"
	quick.BackgroundColor3 = if current.queue then Theme.button else Theme.accent
	quick.TextColor3 = if current.queue then Theme.text else Theme.accentText
end

local function renderInvite(current: Types.PartyState?)
	local panel, label = invitePanel, inviteLabel
	if not (panel and label) then
		return
	end
	local invite = current and current.invite
	local open = invite ~= nil and invite.expiresAt > RunStateController.now()
	panel.Visible = open
	if invite and open then
		local seconds = math.max(0, math.ceil(invite.expiresAt - RunStateController.now()))
		label.Text = `{invite.fromName} invites you to their party ({seconds})`
	end
end

-- Updates the invite countdown (LobbyController calls this every frame while the lobby shows).
function PartyController.tick()
	renderInvite(state)
end

-- Shows the parts for this place; called by LobbyController on every change.
function PartyController.render()
	local current = state
	local role = PartyController.getRole()
	local hub = role == "Hub"
	if actions then
		actions.Visible = hub
	end
	if backButton then
		backButton.Visible = role == "Run"
		local leaving = current ~= nil and current.teleporting
		backButton.Text = if leaving then "TELEPORTING..." else "BACK TO HUB"
	end
	if hubList then
		hubList.Visible = hub
	end
	if defaultRows then
		defaultRows.Visible = not hub
	end
	if listTitle then
		listTitle.Text = if hub then "PARTY AND PLAYERS" else `PLAYERS (max {Config.Run.maxPlayers} per run)`
	end
	renderInvite(current)
	if current and hub then
		renderActions(current)
		renderRows(current)
	end
end

return PartyController
