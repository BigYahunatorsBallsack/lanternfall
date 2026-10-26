--!strict
-- Owns the run flow: lobby, countdown, run timer, boss phase and results (rules in RunFlow).
-- Moves characters via MapService, checks classes via PlayerDataService and syncs clients via RunState.
-- Other services listen to its signals and call setParticipantState / endRun / setBossEncounter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Net.Types)

local MapService = require(script.Parent.MapService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RunFlow = require(script.RunFlow)

-- Player-facing texts for rejected requests (reason codes come from RunFlow).
local REJECTION_TEXT: { [string]: string } = {
	InRun = "Not possible during your run",
	NotRunning = "Only possible while a run is going",
	NotParticipant = "You are not part of this run",
	AlreadyPast = "The timer is already past that point",
	UnknownPlayer = "Please wait a moment and try again",
	Locked = "This class is not unlocked yet",
	NoCharacter = "Your character has not loaded yet",
	EnemyCap = "The enemy limit is reached",
}

local RunDirector = {}

-- (participants: { Player })
RunDirector.RunStarted = Signal.new()
-- (results: Types.Results)
RunDirector.RunEnded = Signal.new()
-- (phase: Types.Phase, previous: Types.Phase)
RunDirector.PhaseChanged = Signal.new()
-- (player: Player, state: Types.ParticipantState)
RunDirector.ParticipantStateChanged = Signal.new()
-- (player: Player): a client asked for a full sync; other services send their state too
RunDirector.SyncRequested = Signal.new()

local flow = RunFlow.new({
	countdownSeconds = Config.Run.flow.countdownSeconds,
	allReadyCountdownSeconds = Config.Run.flow.allReadyCountdownSeconds,
	resultsSeconds = Config.Run.flow.resultsSeconds,
	durationSeconds = Config.Run.durationSeconds,
	maxPlayers = Config.Run.maxPlayers,
	defaultClassId = Config.Run.flow.defaultClassId,
	difficulty = Config.Run.flow.defaultDifficulty,
})

local sentVersion = -1
local processing = false
local inArena: { [Player]: boolean } = {} -- characters that belong in the arena until the next lobby phase
local bossEncounter: (() -> ())? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function toPlayers(userIds: { number }): { Player }
	local list = {}
	for _, userId in userIds do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			table.insert(list, player)
		end
	end
	return list
end

local function notifyParticipants(text: string)
	for _, player in toPlayers(flow:getParticipantIds()) do
		Net.fireClient("Notify", player, text)
	end
end

local function sendToArena(players: { Player })
	for index, player in players do
		inArena[player] = true
		task.spawn(MapService.placeCharacter, player, "Arena", index, #players)
	end
end

local function returnToLobby()
	for player in inArena do
		if player.Parent then
			task.spawn(MapService.placeCharacter, player, "Lobby", 1, 1)
		end
	end
	table.clear(inArena)
end

local function startBoss()
	if bossEncounter then
		notifyParticipants(`{Config.Enemies.boss.displayName} awakens!`)
		task.spawn(bossEncounter)
	else
		print("[Lanternfall] No boss yet (WP10): reaching the boss phase counts as a victory")
		notifyParticipants("The boss is not in the game yet - victory!")
		flow:endRun("Victory", now())
	end
end

local function handle(event: RunFlow.Event)
	if event.kind == "RunStarted" then
		local players = toPlayers(event.userIds)
		print(`[Lanternfall] Run started with {#players} player(s), difficulty {flow.difficulty}`)
		sendToArena(players)
		notifyParticipants("Survive until dawn!")
		RunDirector.RunStarted:Fire(players)
	elseif event.kind == "RunEnded" then
		local results = event.results
		print(`[Lanternfall] Run ended: {results.outcome} after {Format.time(results.survivedSeconds)}`)
		RunDirector.RunEnded:Fire(results)
	elseif event.kind == "PhaseChanged" then
		RunDirector.PhaseChanged:Fire(event.phase, event.previous)
		if event.phase == "Lobby" then
			returnToLobby()
		elseif event.phase == "Boss" then
			startBoss()
		end
	elseif event.kind == "ParticipantStateChanged" then
		local player = Players:GetPlayerByUserId(event.userId)
		if player then
			RunDirector.ParticipantStateChanged:Fire(player, event.state)
		end
	end
end

-- Handles queued RunFlow events, then sends the new state to every client if anything changed.
-- Not re-entrant: changes made while handling (e.g. by signal listeners) are picked up by the loop.
local function process()
	if processing then
		return
	end
	processing = true
	while flow:hasEvents() do
		for _, event in flow:drainEvents() do
			local ok, err = pcall(handle, event)
			if not ok then
				task.spawn(error, `[Lanternfall] RunDirector failed to handle {event.kind}: {err}`, 0)
			end
		end
	end
	processing = false
	if flow.version ~= sentVersion then
		sentVersion = flow.version
		Net.fireAllClients("RunState", flow:snapshot())
	end
end

local function reject(player: Player, reason: string?)
	Net.fireClient("Notify", player, REJECTION_TEXT[reason or ""] or "Not possible right now")
end

local function onCharacterAdded(player: Player)
	-- Respawns land in the lobby (MapService sets RespawnLocation); participants go back to the arena.
	if inArena[player] then
		MapService.placeCharacter(player, "Arena", 1, 1)
	else
		MapService.ensureInZone(player, "Lobby")
	end
end

local function onPlayerAdded(player: Player)
	flow:addPlayer(player.UserId, player.DisplayName)
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player)
	end
	process()
end

local function onPlayerRemoving(player: Player)
	inArena[player] = nil
	flow:removePlayer(player.UserId, now())
	process()
end

-- Lifecycle -------------------------------------------------------------------------

function RunDirector.init()
	Net.onServer("RequestSync", function(player)
		Net.fireClient("RunState", player, flow:snapshot())
		RunDirector.SyncRequested:Fire(player)
	end)

	Net.onServer("SelectClass", function(player, classId: string)
		local class = Config.Classes[classId]
		if not (class and class.available and PlayerDataService.ownsClass(player, classId)) then
			reject(player, "Locked")
			return
		end
		local ok, reason = flow:setClass(player.UserId, classId)
		if not ok then
			reject(player, reason)
		end
		process()
	end)

	Net.onServer("SetReady", function(player, ready: boolean)
		local ok, reason = flow:setReady(player.UserId, ready, now())
		if not ok then
			reject(player, reason)
		end
		process()
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	RunService.Heartbeat:Connect(function()
		flow:update(now())
		process()
	end)
end

-- Queries ---------------------------------------------------------------------------

function RunDirector.getPhase(): Types.Phase
	return flow.phase
end

-- Running or Boss.
function RunDirector.isActive(): boolean
	return flow:isActive()
end

-- Seconds since the run started (frozen after it ended), 0 outside a run.
function RunDirector.getElapsed(): number
	return flow:getElapsed(now())
end

function RunDirector.getDifficulty(): string
	return flow.difficulty
end

-- Participants of the current run who are still in the server.
function RunDirector.getParticipants(): { Player }
	return toPlayers(flow:getParticipantIds())
end

function RunDirector.getParticipantState(player: Player): Types.ParticipantState?
	return flow:getParticipantState(player.UserId)
end

-- Class the player plays in the current run, nil outside of it.
function RunDirector.getParticipantClassId(player: Player): string?
	return flow:getParticipantClassId(player.UserId)
end

-- Commands --------------------------------------------------------------------------

-- Down/Out/Alive for ReviveService (WP11). Ends the run when nobody is alive any more.
function RunDirector.setParticipantState(player: Player, state: Types.ParticipantState): (boolean, string?)
	local ok, reason = flow:setParticipantState(player.UserId, state, now())
	process()
	return ok, reason
end

-- Ends the active run, e.g. "Victory" when the boss dies (WP10).
function RunDirector.endRun(outcome: Types.Outcome): (boolean, string?)
	local ok, reason = flow:endRun(outcome, now())
	process()
	return ok, reason
end

-- Moves the run timer forward (admin debug command).
function RunDirector.skipTo(elapsedSeconds: number): (boolean, string?)
	local ok, reason = flow:skipTo(elapsedSeconds, now())
	process()
	return ok, reason
end

-- Called at 12:00 instead of the placeholder victory. The boss service (WP10) registers this and calls
-- RunDirector.endRun("Victory") when the boss dies.
function RunDirector.setBossEncounter(start: () -> ())
	bossEncounter = start
end

function RunDirector.notifyRejection(player: Player, reason: string?)
	reject(player, reason)
end

return RunDirector
