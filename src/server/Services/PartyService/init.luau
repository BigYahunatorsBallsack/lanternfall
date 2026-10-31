--!strict
-- Hub lobby (Paket 15): parties with invites, Play solo, Party run, Quick join and the portals in the lobby. Each
-- group goes to its own reserved run server (PlaceService) with everyone's character pick and the party's run options;
-- in Studio, where Roblox cannot teleport, the group's run starts in this server instead (RunDirector.launch).
-- Party rules in Parties (pure), ticket and quick join rules in Util/PlaceRules. Sends each player their view
-- (remote PartyState) in every role; outside the hub that only says which place this is, the run place's view comes
-- from RunPlaceService. Listens to RunDirector, MapService (portals) and PlayerDataService (danger levels).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DangerRules = require(Shared.Util.DangerRules)
local Net = require(Shared.Net)
local PlaceRules = require(Shared.Util.PlaceRules)
local Types = require(Shared.Net.Types)

local MapService = require(script.Parent.MapService)
local Parties = require(script.Parties)
local PlaceService = require(script.Parent.PlaceService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RunDirector = require(script.Parent.RunDirector)
local WeaponService = require(script.Parent.WeaponService)

local TICK_SECONDS = 0.25 -- invites, countdowns and the quick join queue are checked this often

-- Player-facing texts for refused actions (reason codes from Parties and this service).
local REASON_TEXT: { [string]: string } = {
	Self = "You cannot invite yourself",
	NotLeader = "Only your party leader can do that",
	Full = "The party is full",
	TheyAreInParty = "They are already in a party",
	InParty = "Leave your party first",
	NoInvite = "That invite is no longer open",
	NotInParty = "Not in your party",
	Busy = "Not possible right now",
	TheyAreBusy = "They are busy right now",
	SoloOnly = "Leave your party to play solo, or start a party run",
	Queued = "You are in quick join; cancel it first",
	Unknown = "Please wait a moment and try again",
	RunHere = "A run is already going in this server (Studio runs one group at a time)",
}

local PartyService = {}

local book = Parties.new(Config.Places.party.maxSize)
local optionsOf: { [number]: Types.RunOptions } = {} -- each player's own pick, used while they lead
local queue: { number } = {} -- quick join: leader userIds in arrival order (solo players or whole parties)
local quickStartsAt: number? = nil -- the forming group leaves at this time
local quickGroup: { number } = {} -- leaders in the forming group
local partyStartsAt: { [number]: number } = {} -- leader -> party run countdown end
local teleporting: { [number]: number } = {} -- userId -> give up waiting at this time
local sentVersion = -1
local dirty = true
local elapsed = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function touch()
	dirty = true
end

local function playerOf(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

local function notify(player: Player, reason: string?)
	Net.fireClient("Notify", player, REASON_TEXT[reason or ""] or reason or "Not possible right now")
end

local function inQueue(leader: number): boolean
	return table.find(queue, leader) ~= nil
end

local function removeFromQueue(leader: number)
	local index = table.find(queue, leader)
	if index then
		table.remove(queue, index)
		touch()
	end
end

-- Teleporting or playing a run in this server (Studio).
local function isBusy(userId: number): boolean
	if teleporting[userId] then
		return true
	end
	local player = playerOf(userId)
	return player ~= nil
		and RunDirector.getParticipantState(player) ~= nil
		and RunDirector.getPhase() ~= "Lobby"
		and RunDirector.getPhase() ~= "Countdown"
end

local function anyBusy(userIds: { number }): boolean
	for _, userId in userIds do
		if isBusy(userId) then
			return true
		end
	end
	return false
end

-- The party changed (join, leave, kick): its queue entry and countdown no longer fit.
local function resetGroupOf(userId: number)
	local leader = book:leaderOf(userId)
	removeFromQueue(leader)
	removeFromQueue(userId)
	if partyStartsAt[leader] or partyStartsAt[userId] then
		partyStartsAt[leader] = nil
		partyStartsAt[userId] = nil
	end
	touch()
end

-- Highest danger level someone in the group has open with the character they picked (Paket 13 rule, per party).
local function dangerCap(userIds: { number }): number
	local cap = Config.Progress.startDanger
	for _, userId in userIds do
		local player = playerOf(userId)
		if player then
			cap = math.max(cap, PlayerDataService.maxDanger(player, RunDirector.getSelectedClassId(player)))
		end
	end
	return cap
end

-- The run options of the player's party: the leader's pick, capped for the party.
local function optionsFor(userId: number): Types.RunOptions
	local leader = book:leaderOf(userId)
	local options = table.clone(optionsOf[leader] or DangerRules.defaultOptions())
	options.danger = math.min(options.danger, dangerCap(book:membersOf(userId)))
	return DangerRules.clean(options)
end

local function present(userIds: { number }): { Player }
	local list = {}
	for _, userId in userIds do
		local player = playerOf(userId)
		if player then
			table.insert(list, player)
		end
	end
	return list
end

local function pickOf(player: Player): PlaceRules.Pick?
	local classId = RunDirector.getSelectedClassId(player)
	if not classId then
		return nil
	end
	return { classId = classId, weaponId = WeaponService.getStartWeapon(player, classId) }
end

-- Sends a group to its run: a reserved run server, or in Studio a run in this server.
local function launch(userIds: { number }, options: Types.RunOptions, leader: number)
	local players = present(userIds)
	if #players == 0 then
		return
	end
	for _, player in players do
		removeFromQueue(player.UserId)
		partyStartsAt[player.UserId] = nil
	end
	touch()

	if not PlaceService.canTeleport() then
		if RunDirector.getPhase() ~= "Lobby" then
			for _, player in players do
				notify(player, "RunHere")
			end
			return
		end
		local ok, reason = RunDirector.launch(players, options, false)
		if not ok then
			for _, player in players do
				notify(player, if reason == "Busy" then "RunHere" else reason)
			end
		end
		return
	end

	local party = book:get(leader)
	local partyId = (party and party.tag) or PlaceService.newPartyId()
	book:setTag(leader, partyId)
	local picks: { [number]: PlaceRules.Pick } = {}
	local group = {}
	local deadline = now() + Config.Places.teleport.timeoutSeconds
	for _, player in players do
		table.insert(group, player.UserId)
		teleporting[player.UserId] = deadline
		local pick = pickOf(player)
		if pick then
			picks[player.UserId] = pick
		end
		Net.fireClient("Notify", player, "Teleporting to your run...")
	end
	local ticket: PlaceRules.RunTicket = {
		partyId = partyId,
		leader = if table.find(group, leader) then leader else group[1],
		group = group,
		options = options,
		picks = picks,
		hubJobId = if game.JobId ~= "" then game.JobId else nil,
	}
	print(`[Lanternfall] Teleporting {#players} player(s) to a run ({DangerRules.label(options)})`)
	task.spawn(function()
		local ok, err = PlaceService.teleportToRun(players, ticket)
		if not ok then
			warn(`[Lanternfall] Teleport to the run place failed: {err}`)
			for _, player in players do
				teleporting[player.UserId] = nil
				if player.Parent == Players then
					Net.fireClient("Notify", player, "The teleport failed. Please try again.")
				end
			end
			touch()
		end
	end)
end

-- Actions -------------------------------------------------------------------------

local function playSolo(player: Player)
	local userId = player.UserId
	if #book:membersOf(userId) > 1 then
		notify(player, "SoloOnly")
		return
	end
	if isBusy(userId) then
		notify(player, "Busy")
		return
	end
	launch({ userId }, optionsFor(userId), userId)
end

local function startParty(player: Player)
	local userId = player.UserId
	local members = book:membersOf(userId)
	if not book:isLeader(userId) then
		notify(player, "NotLeader")
		return
	end
	if partyStartsAt[userId] then
		partyStartsAt[userId] = nil -- pressing again cancels
		touch()
		return
	end
	if anyBusy(members) then
		notify(player, "Busy")
		return
	end
	removeFromQueue(userId)
	partyStartsAt[userId] = now() + Config.Places.party.startCountdownSeconds
	touch()
end

local function joinQuick(player: Player)
	local userId = player.UserId
	if not book:isLeader(userId) then
		notify(player, "NotLeader")
		return
	end
	if inQueue(userId) then
		return
	end
	if anyBusy(book:membersOf(userId)) then
		notify(player, "Busy")
		return
	end
	partyStartsAt[userId] = nil
	table.insert(queue, userId)
	touch()
end

local function cancel(player: Player)
	local leader = book:leaderOf(player.UserId)
	if leader ~= player.UserId then
		notify(player, "NotLeader")
		return
	end
	removeFromQueue(leader)
	if partyStartsAt[leader] then
		partyStartsAt[leader] = nil
		touch()
	end
end

local function play(player: Player, mode: string)
	if not PlaceService.isHub() then
		return
	end
	if not PlayerDataService.isLoaded(player) then
		notify(player, "Unknown")
		return
	end
	if mode == "Solo" then
		playSolo(player)
	elseif mode == "Party" then
		if #book:membersOf(player.UserId) < 2 then
			playSolo(player) -- the party portal alone = solo run
		else
			startParty(player)
		end
	elseif mode == "QuickJoin" then
		joinQuick(player)
	elseif mode == "Cancel" then
		cancel(player)
	end
end

-- Clock ---------------------------------------------------------------------------

local function queueEntries(): { { id: number, size: number } }
	local entries = {}
	for _, leader in queue do
		table.insert(entries, { id = leader, size = #book:membersOf(leader) })
	end
	return entries
end

local function updateQuickJoin(t: number)
	local settings = Config.Places.quickJoin
	local ids, total = PlaceRules.quickGroup(queueEntries(), Config.Places.party.maxSize)
	quickGroup = ids
	if total < settings.minPlayers then
		if quickStartsAt then
			quickStartsAt = nil
			touch()
		end
		return
	end
	local endsAt = quickStartsAt or (t + settings.countdownSeconds)
	if total >= Config.Places.party.maxSize then
		endsAt = math.min(endsAt, t + settings.fullCountdownSeconds)
	end
	if endsAt ~= quickStartsAt then
		quickStartsAt = endsAt
		touch()
	end
	if t < endsAt then
		return
	end
	-- the group leaves
	local userIds = {}
	local dangers = {}
	for _, leader in ids do
		table.insert(dangers, optionsFor(leader).danger)
		for _, member in book:membersOf(leader) do
			table.insert(userIds, member)
		end
	end
	quickStartsAt = nil
	quickGroup = {}
	launch(userIds, PlaceRules.quickOptions(dangers), ids[1])
end

local function update(t: number)
	local before = book.version
	book:expire(t)
	if book.version ~= before then
		touch()
	end
	for userId, deadline in teleporting do
		if t >= deadline then
			teleporting[userId] = nil
			local player = playerOf(userId)
			if player then
				PlaceService.forget(player)
				Net.fireClient("Notify", player, "The teleport took too long. Please try again.")
			end
			touch()
		end
	end
	for leader, startsAt in partyStartsAt do
		if t >= startsAt then
			partyStartsAt[leader] = nil
			local members = book:membersOf(leader)
			if anyBusy(members) then
				touch()
			else
				launch(members, optionsFor(leader), leader)
			end
		end
	end
	updateQuickJoin(t)
end

-- Views ---------------------------------------------------------------------------

local function statusOf(userId: number): string
	if isBusy(userId) then
		return "Busy"
	elseif inQueue(book:leaderOf(userId)) then
		return "Queue"
	elseif book:get(userId) then
		return "Party"
	end
	return "Solo"
end

local function nameOf(userId: number): string
	local player = playerOf(userId)
	return if player then player.DisplayName else tostring(userId)
end

local function viewFor(player: Player): Types.PartyState
	local role = PlaceService.getRole()
	local userId = player.UserId
	local state: Types.PartyState = {
		role = role,
		canTeleport = PlaceService.canTeleport(),
		leaderId = userId,
		members = { { userId = userId, name = player.DisplayName } },
		options = DangerRules.defaultOptions(),
		teleporting = teleporting[userId] ~= nil,
		players = {},
	}
	if role ~= "Hub" then
		return state
	end
	local leader = book:leaderOf(userId)
	state.leaderId = leader
	state.members = {}
	for _, member in book:membersOf(userId) do
		table.insert(state.members, { userId = member, name = nameOf(member) })
	end
	state.options = optionsFor(userId)
	local invite = book:inviteTo(userId)
	if invite then
		state.invite = { fromId = invite.from, fromName = nameOf(invite.from), expiresAt = invite.expiresAt }
	end
	if inQueue(leader) then
		local queued = 0
		for _, entry in queueEntries() do
			queued += entry.size
		end
		local inGroup = table.find(quickGroup, leader) ~= nil
		local _, groupSize = PlaceRules.quickGroup(queueEntries(), Config.Places.party.maxSize)
		state.queue = {
			players = queued,
			groupSize = if inGroup then groupSize else #book:membersOf(leader),
			startsAt = if inGroup then quickStartsAt else nil,
		}
	end
	state.launchAt = partyStartsAt[leader]
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(state.players, {
				userId = other.UserId,
				name = other.DisplayName,
				status = statusOf(other.UserId),
				partySize = #book:membersOf(other.UserId),
				invited = book:hasInvited(userId, other.UserId),
			})
		end
	end
	table.sort(state.players, function(a, b)
		return a.name < b.name
	end)
	return state
end

local function send(player: Player)
	if PlaceService.isRunPlace() then
		return -- RunPlaceService sends the run place's view
	end
	Net.fireClient("PartyState", player, viewFor(player))
end

local function sendAll()
	for _, player in Players:GetPlayers() do
		send(player)
	end
end

-- Lifecycle -------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	if PlaceService.isHub() then
		local ticket = PlaceRules.parseHubTicket(
			PlaceService.getTeleportData(player),
			player.UserId,
			Config.Places.party.maxSize
		)
		if ticket then
			book:arrive(player.UserId, ticket.partyId, ticket.leader, now(), Config.Places.runPlace.hubTagSeconds)
		end
	end
	touch()
end

local function onPlayerRemoving(player: Player)
	local userId = player.UserId
	resetGroupOf(userId)
	book:remove(userId)
	optionsOf[userId] = nil
	teleporting[userId] = nil
	partyStartsAt[userId] = nil
	touch()
end

function PartyService.init()
	Net.onServer("InviteToParty", function(player, targetId: number)
		if not PlaceService.isHub() then
			return
		end
		local target = playerOf(targetId)
		if not target then
			notify(player, "Unknown")
			return
		end
		if isBusy(targetId) then
			notify(player, "TheyAreBusy")
			return
		end
		if inQueue(book:leaderOf(player.UserId)) then
			notify(player, "Queued")
			return
		end
		local ok, reason = book:invite(player.UserId, targetId, now(), Config.Places.party.inviteSeconds)
		if not ok then
			notify(player, reason)
			return
		end
		Net.fireClient("Notify", player, `Invite sent to {target.DisplayName}`)
		touch()
	end)

	Net.onServer("AnswerInvite", function(player, fromId: number, accept: boolean)
		if not PlaceService.isHub() then
			return
		end
		if accept and (isBusy(player.UserId) or inQueue(book:leaderOf(player.UserId))) then
			notify(player, if inQueue(book:leaderOf(player.UserId)) then "Queued" else "Busy")
			return
		end
		local ok, reason = book:answer(player.UserId, fromId, accept)
		touch()
		if not ok then
			notify(player, reason)
			return
		end
		if accept then
			resetGroupOf(fromId)
			local inviter = playerOf(fromId)
			if inviter then
				Net.fireClient("Notify", inviter, `{player.DisplayName} joined your party`)
			end
		end
	end)

	Net.onServer("LeaveParty", function(player)
		if not PlaceService.isHub() then
			return
		end
		resetGroupOf(player.UserId)
		local ok, reason = book:leave(player.UserId)
		if not ok then
			notify(player, reason)
		end
		touch()
	end)

	Net.onServer("KickFromParty", function(player, targetId: number)
		if not PlaceService.isHub() then
			return
		end
		if not book:isLeader(player.UserId) then
			notify(player, "NotLeader")
			return
		end
		resetGroupOf(player.UserId)
		local ok, reason = book:kick(player.UserId, targetId)
		if not ok then
			notify(player, reason)
		else
			local target = playerOf(targetId)
			if target then
				Net.fireClient("Notify", target, "You left the party")
			end
		end
		touch()
	end)

	Net.onServer("PlayFromHub", function(player, mode: string)
		play(player, mode)
	end)

	MapService.PortalTriggered:Connect(function(player: Player, mode: string)
		play(player, mode)
	end)

	RunDirector.OptionsRequested:Connect(function(player: Player, options: Types.RunOptions)
		if not book:isLeader(player.UserId) then
			notify(player, "NotLeader")
			touch() -- resend, so the panel shows the leader's pick again
			return
		end
		local cap = dangerCap(book:membersOf(player.UserId))
		if options.danger > cap then
			Net.fireClient(
				"Notify",
				player,
				`Danger {options.danger} is locked. Win danger {options.danger - 1} with your character to open it.`
			)
		end
		optionsOf[player.UserId] = options
		touch()
	end)

	RunDirector.ClassSelected:Connect(touch)
	RunDirector.PhaseChanged:Connect(touch)
	RunDirector.SyncRequested:Connect(send)
	PlayerDataService.Loaded:Connect(touch)
	PlayerDataService.Changed:Connect(touch)
	PlaceService.TeleportFailed:Connect(function(player: Player)
		if teleporting[player.UserId] then
			teleporting[player.UserId] = nil
			Net.fireClient("Notify", player, "The teleport failed. Please try again.")
			touch()
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= TICK_SECONDS then
			elapsed = 0
			if PlaceService.isHub() then
				update(now())
			end
		end
		if dirty or book.version ~= sentVersion then
			dirty = false
			sentVersion = book.version
			sendAll()
		end
	end)
end

-- Queries (tests and other services) -------------------------------------------------

-- Everyone in the player's party (the player alone when solo), leader first.
function PartyService.getMembers(player: Player): { number }
	return book:membersOf(player.UserId)
end

function PartyService.getLeader(player: Player): number
	return book:leaderOf(player.UserId)
end

-- The run options the player's party would start with.
function PartyService.getOptions(player: Player): Types.RunOptions
	return optionsFor(player.UserId)
end

function PartyService.isQueued(player: Player): boolean
	return inQueue(book:leaderOf(player.UserId))
end

function PartyService.isTeleporting(player: Player): boolean
	return teleporting[player.UserId] ~= nil
end

-- Whatever the player would get on the screen (tests).
function PartyService.getView(player: Player): Types.PartyState
	return viewFor(player)
end

return PartyService
