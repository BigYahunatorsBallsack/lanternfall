--!strict
-- First start "First Night" (Paket 19, DESIGN.md section 19): once a new player's data loaded (tutorial.firstNight
-- false), sends them into a short, easier solo run (Config.FirstNight; on the hub through PartyService.launchSolo, in a
-- single server through RunDirector.launch when nobody else is there). In the run's Looter wave a Looter shows up
-- near the player. "Skip" (remote SkipFirstNight) marks it done and ends the run; any finished run marks it done too
-- (ProfileRecords.applyRun). After a First Night (played or skipped) the lobby hint is sent once (remote
-- FirstNightLobby; on the hub after the teleport back). Hints on the client: FirstNightController. Debug button:
-- AdminService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DangerRules = require(Shared.Util.DangerRules)
local Net = require(Shared.Net)

local MapService = require(script.Parent.MapService)
local PartyService = require(script.Parent.PartyService)
local PlaceService = require(script.Parent.PlaceService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RunDirector = require(script.Parent.RunDirector)
local SpawnDirector = require(script.Parent.SpawnDirector)

local FirstNight = Config.FirstNight

local FirstNightService = {}

local startInStudio = FirstNight.autoStartInStudio
local looterToken = 0 -- a newer wave or run cancels a Looter that is still waiting

local function isFirstNightRun(): boolean
	return RunDirector.isOngoing() and RunDirector.getRunOptions().firstNight == true
end

-- True while the player's data says the First Night was not played yet.
function FirstNightService.isPending(player: Player): boolean
	local data = PlayerDataService.get(player)
	return data ~= nil and not (data.tutorial and data.tutorial.firstNight)
end

-- Whether a First Night should start for this player now (automatic start after loading).
local function shouldStart(player: Player): boolean
	if not (FirstNight.enabled and FirstNightService.isPending(player)) then
		return false
	end
	if RunService:IsStudio() and not startInStudio then
		return false
	end
	if PlaceService.isRunPlace() then
		return false -- the group's run starts there (RunPlaceService); the hub sent this player
	end
	if PlaceService.isHub() then
		return true
	end
	-- single server: only when nobody else is here, so no one has to wait for the newcomer's run
	return #Players:GetPlayers() == 1 and RunDirector.getPhase() == "Lobby"
end

-- Starts a First Night for the player right away (also the debug button; not named start: Loader runs start()). False if that is not possible now.
function FirstNightService.launch(player: Player): boolean
	local options = DangerRules.firstNightOptions()
	if PlaceService.isHub() then
		return PartyService.launchSolo(player, options)
	end
	if RunDirector.getPhase() ~= "Lobby" then
		return false
	end
	local ok = RunDirector.launch({ player }, options, false)
	return ok
end

local function onLoaded(player: Player)
	if not shouldStart(player) then
		return
	end
	task.delay(FirstNight.startDelaySeconds, function()
		if player.Parent == Players and shouldStart(player) then
			if FirstNightService.launch(player) then
				print(`[Lanternfall] First Night started for {player.Name}`)
			end
		end
	end)
end

-- The Looter of the Looter wave, a few seconds in, next to a participant.
local function onPhaseChanged(phase: string)
	looterToken += 1
	if phase ~= "Running" or not isFirstNightRun() or RunDirector.getWave() ~= FirstNight.looterWave then
		return
	end
	local token = looterToken
	task.delay(FirstNight.looterDelaySeconds, function()
		if token ~= looterToken or not isFirstNightRun() then
			return
		end
		for _, player in RunDirector.getParticipants() do
			local position = MapService.getRootPosition(player)
			if position and RunDirector.getParticipantState(player) == "Alive" then
				SpawnDirector.spawnLooter(position)
				return
			end
		end
	end)
end

-- Shows the lobby hint after a First Night once (not on the run place: the player is about to go back to the hub).
local function sendLobbyHint(player: Player)
	local data = PlayerDataService.get(player)
	if not (data and data.tutorial and data.tutorial.lobbyHint) or PlaceService.isRunPlace() then
		return
	end
	if RunDirector.getPhase() ~= "Lobby" and RunDirector.getParticipantState(player) ~= nil then
		return -- still in a run here; the next lobby phase sends it
	end
	data.tutorial.lobbyHint = false
	Net.fireClient("FirstNightLobby", player)
end

local function onRunRecorded(_player: Player, data: any, run: any)
	if run.firstNight then
		data.tutorial.lobbyHint = true
	end
end

-- "Skip": the First Night counts as done and the run ends for everyone in it (it is a solo run).
function FirstNightService.skip(player: Player): (boolean, string?)
	if not (isFirstNightRun() and RunDirector.getParticipantState(player) ~= nil) then
		return false, "NotRunning"
	end
	local data = PlayerDataService.get(player)
	if data then
		data.tutorial = { firstNight = true, lobbyHint = true }
		PlayerDataService.refresh(player)
	end
	print(`[Lanternfall] {player.Name} skipped the First Night`)
	return RunDirector.endRun("Abandoned")
end

-- Tests: start the First Night automatically in Studio too (the mock is Studio).
function FirstNightService.allowStudio(allow: boolean)
	startInStudio = allow
end

function FirstNightService.init()
	Net.onServer("SkipFirstNight", function(player)
		local ok, reason = FirstNightService.skip(player)
		if not ok then
			RunDirector.notifyRejection(player, reason)
		end
	end)
	PlayerDataService.Loaded:Connect(function(player)
		onLoaded(player)
		task.delay(FirstNight.startDelaySeconds, function()
			if player.Parent == Players then
				sendLobbyHint(player)
			end
		end)
	end)
	PlayerDataService.onRunRecorded(onRunRecorded)
	RunDirector.PhaseChanged:Connect(function(phase)
		onPhaseChanged(phase)
		if phase == "Lobby" then
			task.defer(function() -- after RunStatsService saved a defeat it held back for "Retry wave"
				for _, player in Players:GetPlayers() do
					sendLobbyHint(player)
				end
			end)
		end
	end)
end

return FirstNightService
