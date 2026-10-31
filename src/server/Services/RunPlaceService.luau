--!strict
-- Run place (Paket 15): players arrive from the hub with a ticket (Util/PlaceRules) naming their group, the party's
-- run options and everyone's character pick. Once the whole group is here and loaded (at the latest
-- Config.Places.runPlace.waitForGroupSeconds after the first arrival) their run starts (RunDirector.launch); who comes
-- later joins the next run. After a run the lobby here works as before (READY = play again), and "Back to hub"
-- (remote ReturnToHub) teleports a player back, to the hub server they came from if it still has room, so the hub can
-- put the party back together. Sends the run place's PartyState. Uses PlaceService, RunDirector, WeaponService and
-- PlayerDataService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DangerRules = require(Shared.Util.DangerRules)
local Net = require(Shared.Net)
local PlaceRules = require(Shared.Util.PlaceRules)
local Types = require(Shared.Net.Types)

local PlaceService = require(script.Parent.PlaceService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RunDirector = require(script.Parent.RunDirector)
local WeaponService = require(script.Parent.WeaponService)

local TICK_SECONDS = 0.25

local RunPlaceService = {}

local group: PlaceRules.RunTicket? = nil -- the first valid ticket that arrived
local firstArrivalAt: number? = nil
local launched = false
local tickets: { [Player]: PlaceRules.RunTicket } = {}
local here: { [Player]: boolean } = {} -- arrived and checked for a ticket
local picked: { [Player]: boolean } = {} -- the hub pick was applied (after the profile loaded)
local leaving: { [Player]: boolean } = {} -- "Back to hub" in progress
local elapsed = 0
local dirty = true

local function now(): number
	return workspace:GetServerTimeNow()
end

local function isClass(id: string): boolean
	return Config.Classes[id] ~= nil
end

local function isWeapon(id: string): boolean
	return Config.Weapons[id] ~= nil
end

-- Members of the group who are in this server.
local function arrived(): { Player }
	local list = {}
	if not group then
		return list
	end
	for _, userId in group.group do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			table.insert(list, player)
		end
	end
	return list
end

-- Applies the character and weapon the player picked in the hub (checked like lobby input), once: after the ticket
-- was read, the profile loaded (unlocks) and RunDirector knows the player (signal order is not fixed).
local function applyPick(player: Player)
	if picked[player] or not here[player] or not PlayerDataService.isLoaded(player) then
		return
	end
	if RunDirector.getSelectedClassId(player) == nil then
		return
	end
	picked[player] = true
	local ticket = tickets[player]
	local pick = ticket and ticket.picks[player.UserId]
	if pick then
		local ok = RunDirector.selectClass(player, pick.classId)
		if ok and pick.weaponId then
			WeaponService.selectStartWeapon(player, pick.classId, pick.weaponId)
		end
	end
	if launched then
		RunDirector.setReady(player, true) -- late: joins the next run
	end
	dirty = true
end

local function tryLaunch(t: number)
	for player in here do
		applyPick(player)
	end
	if launched or not group or not firstArrivalAt then
		return
	end
	if RunDirector.getPhase() ~= "Lobby" then
		launched = true -- someone readied up by hand meanwhile
		return
	end
	local ready = {}
	for _, player in arrived() do
		if picked[player] then
			table.insert(ready, player)
		end
	end
	local everyone = #ready == #group.group
	local waitedEnough = t - firstArrivalAt >= Config.Places.runPlace.waitForGroupSeconds
	if #ready == 0 or not (everyone or waitedEnough) then
		return
	end
	launched = true
	local ok, reason = RunDirector.launch(ready, group.options, true)
	if not ok then
		warn(`[Lanternfall] Could not start the group's run: {reason}`)
	else
		print(`[Lanternfall] Group run starts with {#ready} of {#group.group} player(s)`)
	end
	dirty = true
end

local function viewFor(player: Player): Types.PartyState
	local state: Types.PartyState = {
		role = "Run",
		canTeleport = PlaceService.canTeleport(),
		leaderId = if group then group.leader else player.UserId,
		members = {},
		options = if group then group.options else DangerRules.defaultOptions(),
		teleporting = leaving[player] == true,
		players = {},
	}
	for _, member in Players:GetPlayers() do
		table.insert(state.members, { userId = member.UserId, name = member.DisplayName })
	end
	if group and not launched then
		state.group = {
			arrived = #arrived(),
			expected = #group.group,
			startsBy = if firstArrivalAt then firstArrivalAt + Config.Places.runPlace.waitForGroupSeconds else nil,
		}
	end
	return state
end

local function sendAll()
	for _, player in Players:GetPlayers() do
		Net.fireClient("PartyState", player, viewFor(player))
	end
end

local function returnToHub(player: Player)
	if not PlaceService.isRunPlace() then
		Net.fireClient("Notify", player, "You are already in the hub")
		return
	end
	if RunDirector.isOngoing() and RunDirector.getParticipantState(player) ~= nil then
		RunDirector.notifyRejection(player, "InRun")
		return
	end
	if not PlaceService.canTeleport() then
		Net.fireClient("Notify", player, "The teleport to the hub only works in the published game")
		return
	end
	if leaving[player] then
		return
	end
	leaving[player] = true
	dirty = true
	RunDirector.setReady(player, false)
	local ticket = tickets[player] or group
	local hubTicket: PlaceRules.HubTicket? = if ticket
		then { partyId = ticket.partyId, leader = ticket.leader, group = ticket.group }
		else nil
	task.spawn(function()
		local ok, err = PlaceService.teleportToHub(player, hubTicket, if ticket then ticket.hubJobId else nil)
		if not ok then
			warn(`[Lanternfall] Teleport to the hub failed: {err}`)
			leaving[player] = nil
			dirty = true
			if player.Parent == Players then
				Net.fireClient("Notify", player, "The teleport failed. Please try again.")
			end
		end
	end)
end

local function onPlayerAdded(player: Player)
	if not PlaceService.isRunPlace() then
		return
	end
	local ticket = PlaceRules.parseRunTicket(
		PlaceService.getTeleportData(player),
		player.UserId,
		Config.Places.party.maxSize,
		isClass,
		isWeapon
	)
	if ticket then
		tickets[player] = ticket
		if not group then
			group = ticket
			firstArrivalAt = now()
		end
	end
	here[player] = true
	applyPick(player)
	dirty = true
end

function RunPlaceService.init()
	Net.onServer("ReturnToHub", returnToHub)
	PlaceService.TeleportFailed:Connect(function(player: Player)
		if leaving[player] then
			leaving[player] = nil
			Net.fireClient("Notify", player, "The teleport failed. Please try again.")
			dirty = true
		end
	end)
	if not PlaceService.isRunPlace() then
		return
	end
	PlayerDataService.Loaded:Connect(applyPick)
	RunDirector.SyncRequested:Connect(function()
		dirty = true
	end)
	RunDirector.PhaseChanged:Connect(function()
		dirty = true
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		tickets[player] = nil
		here[player] = nil
		picked[player] = nil
		leaving[player] = nil
		dirty = true
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= TICK_SECONDS then
			elapsed = 0
			tryLaunch(now())
		end
		if dirty then
			dirty = false
			sendAll()
		end
	end)
end

-- Tests: whether the group's run was started.
function RunPlaceService.hasLaunched(): boolean
	return launched
end

return RunPlaceService
