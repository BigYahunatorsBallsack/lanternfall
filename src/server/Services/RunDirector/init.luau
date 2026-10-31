--!strict
-- Owns the run flow: lobby, countdown, waves with a shop between them and results (rules in RunFlow). The last wave
-- is the boss wave (BossService, WP10): surviving it wins, and BossService calls endRun("Victory") when its bosses die.
-- Moves characters via MapService, checks classes via PlayerDataService and syncs clients via RunState.
-- Other services listen to its signals and call setParticipantState / endRun.
-- Since B11 the lobby picks the run options (danger level, endless mode, enemy sliders; remote SetRunOptions), and in
-- endless mode the run goes on after wave 20 (Util/RunSchedule has the endless waves).
-- Since Paket 13 the lobby's danger level is capped by the highest level someone in the lobby has opened with the
-- character they picked (PlayerDataService.maxDanger); teammates without it may play along.
-- B11 part 2 "Retry wave": services register a checkpoint (addCheckpoint) that is saved when a wave starts (after
-- WaveStarting, before PhaseChanged) and restored when a participant retries the lost wave on the results (remote
-- RetryWave); then WaveRetried fires and the wave starts again with PhaseChanged Ended -> Running.
-- Paket 15: on the hub (PlaceService) players do not ready up; PartyService teleports each group to its own run server
-- (in Studio it starts the group's run here with launch), the hub's run options belong to the parties
-- (OptionsRequested), and READY only counts as "Play again" after a run. On the run place RunPlaceService launches the
-- group that arrived.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DangerRules = require(Shared.Util.DangerRules)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local RunSchedule = require(Shared.Util.RunSchedule)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Net.Types)

local MapService = require(script.Parent.MapService)
local PlaceService = require(script.Parent.PlaceService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RunFlow = require(script.RunFlow)

-- Player-facing texts for rejected requests (reason codes come from RunFlow).
local REJECTION_TEXT: { [string]: string } = {
	InRun = "Not possible during your run",
	NotRunning = "Only possible while a run is going",
	NotParticipant = "You are not part of this run",
	AlreadyPast = "The timer is already past that point",
	NotShopping = "The shop is closed",
	UnknownPlayer = "Please wait a moment and try again",
	Locked = "This character is not unlocked yet",
	NoCharacter = "Your character has not loaded yet",
	EnemyCap = "The enemy limit is reached",
	NotDefeated = "Only after a defeat",
	NoRetriesLeft = "No retries left in this run",
	UseHub = "Pick Play solo, Party run or Quick join",
	Busy = "A run is already going in this server",
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
-- (wave: number): a wave is about to start (from the shop or the countdown); fired before the checkpoint is saved and
-- before PhaseChanged, e.g. for UpgradeService to pick the cards still open (B11 part 2)
RunDirector.WaveStarting = Signal.new()
-- (wave: number): the lost wave starts again; every checkpoint was restored, PhaseChanged to Running comes next
RunDirector.WaveRetried = Signal.new()
-- (player: Player, classId: string): a player picked a character in the lobby (Paket 15: PartyService resends)
RunDirector.ClassSelected = Signal.new()
-- (player: Player, options: Types.RunOptions): on the hub, a player picked run options for their party (Paket 15)
RunDirector.OptionsRequested = Signal.new()

-- B11 part 2: what the services keep from the start of the current wave for "Retry wave".
type Checkpoint = { name: string, save: () -> any, restore: (any) -> () }
local checkpoints: { Checkpoint } = {}
local savedCheckpoint: { [string]: any } = {}

local flow = RunFlow.new({
	countdownSeconds = Config.Run.flow.countdownSeconds,
	allReadyCountdownSeconds = Config.Run.flow.allReadyCountdownSeconds,
	resultsSeconds = Config.Run.flow.resultsSeconds,
	waveEnds = (function()
		local ends = {}
		for number = 1, RunSchedule.waveCount() do
			table.insert(ends, RunSchedule.wave(number).endsAt)
		end
		return ends
	end)(),
	shopSeconds = Config.Shop.phaseSeconds,
	maxPlayers = Config.Run.maxPlayers,
	maxRetries = Config.Run.flow.maxRetries,
	defaultClassId = Config.Run.flow.defaultClassId,
	waveEndAt = function(number: number): number
		return RunSchedule.wave(number).endsAt
	end,
})

local sentVersion = -1
local capOverride = false -- Paket 13: options set by tests or admins (RunDirector.setOptions) skip the danger cap
local processing = false
local inArena: { [Player]: boolean } = {} -- characters that belong in the arena until the next lobby phase

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

-- Saves every service's checkpoint; one that fails is reported and skipped.
local function saveCheckpoints()
	table.clear(savedCheckpoint)
	for _, checkpoint in checkpoints do
		local ok, result = pcall(checkpoint.save)
		if ok then
			savedCheckpoint[checkpoint.name] = result
		else
			task.spawn(error, `[Lanternfall] Checkpoint {checkpoint.name} failed to save: {result}`, 0)
		end
	end
end

local function restoreCheckpoints()
	for _, checkpoint in checkpoints do
		local data = savedCheckpoint[checkpoint.name]
		if data ~= nil then
			local ok, err = pcall(checkpoint.restore, data)
			if not ok then
				task.spawn(error, `[Lanternfall] Checkpoint {checkpoint.name} failed to restore: {err}`, 0)
			end
		end
	end
end

local function handle(event: RunFlow.Event)
	if event.kind == "RunStarted" then
		local players = toPlayers(event.userIds)
		print(`[Lanternfall] Run started with {#players} player(s), {DangerRules.label(flow:getRunOptions())}`)
		sendToArena(players)
		notifyParticipants("Survive until dawn!")
		RunDirector.RunStarted:Fire(players)
	elseif event.kind == "RunEnded" then
		local results = event.results
		print(`[Lanternfall] Run ended: {results.outcome} after {Format.time(results.survivedSeconds)}`)
		RunDirector.RunEnded:Fire(results)
	elseif event.kind == "PhaseChanged" then
		if event.phase == "Running" and (event.previous == "Shop" or event.previous == "Countdown") then
			RunDirector.WaveStarting:Fire(flow.wave)
			saveCheckpoints()
		end
		RunDirector.PhaseChanged:Fire(event.phase, event.previous)
		if event.phase == "Lobby" then
			returnToLobby()
		end
	elseif event.kind == "ParticipantStateChanged" then
		local player = Players:GetPlayerByUserId(event.userId)
		if player then
			RunDirector.ParticipantStateChanged:Fire(player, event.state)
		end
	elseif event.kind == "WaveRetried" then
		print(`[Lanternfall] Wave {event.wave} retried`)
		restoreCheckpoints()
		sendToArena(toPlayers(flow:getParticipantIds()))
		RunDirector.WaveRetried:Fire(event.wave)
		local left = Config.Run.flow.maxRetries - flow.retries
		notifyParticipants(`Wave {event.wave} starts again ({left} {if left == 1 then "retry" else "retries"} left)`)
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

-- Paket 13: highest danger level someone in the lobby has open with the character they picked.
local function dangerCap(): number
	local cap = 0
	for _, player in Players:GetPlayers() do
		if flow.players[player.UserId] then
			cap = math.max(cap, PlayerDataService.maxDanger(player, RunDirector.getSelectedClassId(player)))
		end
	end
	return cap
end

-- Paket 13: lowers the lobby's danger level when nobody has it open any more (character change, leave, new record).
local function enforceDangerCap()
	if capOverride then
		return
	end
	local cap = dangerCap()
	if flow.options.danger > cap then
		local options = table.clone(flow.options)
		options.danger = cap
		flow:setOptions(DangerRules.clean(options))
	end
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
	enforceDangerCap()
	process()
end

-- Lifecycle -------------------------------------------------------------------------

function RunDirector.init()
	Net.onServer("RequestSync", function(player)
		Net.fireClient("RunState", player, flow:snapshot())
		RunDirector.SyncRequested:Fire(player)
	end)

	Net.onServer("SelectClass", function(player, classId: string)
		local ok, reason = RunDirector.selectClass(player, classId)
		if not ok then
			reject(player, reason)
		end
	end)

	Net.onServer(
		"SetRunOptions",
		function(
			player,
			danger: number,
			endless: boolean,
			enemyHp: number,
			enemyDamage: number,
			enemySpeed: number,
			enemyCount: number?
		)
			if not flow.players[player.UserId] then
				reject(player, "UnknownPlayer")
				return
			end
			if PlaceService.isHub() then -- Paket 15: the party's options, kept by PartyService
				RunDirector.OptionsRequested:Fire(
					player,
					DangerRules.clean({
						danger = danger,
						endless = endless,
						enemyHp = enemyHp,
						enemyDamage = enemyDamage,
						enemySpeed = enemySpeed,
						enemyCount = enemyCount,
					})
				)
				return
			end
			local cap = dangerCap()
			if danger > cap then
				Net.fireClient(
					"Notify",
					player,
					`Danger {danger} is locked. Win danger {danger - 1} with your character to open it.`
				)
				danger = cap
			end
			capOverride = false
			flow:setOptions(DangerRules.clean({
				danger = danger,
				endless = endless,
				enemyHp = enemyHp,
				enemyDamage = enemyDamage,
				enemySpeed = enemySpeed,
				enemyCount = enemyCount,
			}))
			process()
		end
	)

	Net.onServer("SetShopReady", function(player, ready: boolean)
		local ok, reason = flow:setShopReady(player.UserId, ready, now())
		if not ok then
			reject(player, reason)
		end
		process()
	end)

	Net.onServer("RetryWave", function(player)
		local ok, reason = flow:retryWave(player.UserId, now())
		if not ok then
			reject(player, reason)
		end
		process()
	end)

	Net.onServer("SetReady", function(player, ready: boolean)
		-- Paket 15: on the hub READY is only "Play again" on the results of a run played here (Studio)
		if PlaceService.isHub() and ready and not (flow.phase == "Ended" and flow:isParticipant(player.UserId)) then
			reject(player, "UseHub")
			return
		end
		local ok, reason = flow:setReady(player.UserId, ready, now())
		if not ok then
			reject(player, reason)
		end
		process()
	end)

	local function onProgress()
		enforceDangerCap()
		process()
	end
	PlayerDataService.Loaded:Connect(onProgress)
	PlayerDataService.Changed:Connect(onProgress)

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

-- Running (or the old Boss phase, no longer entered since WP10).
function RunDirector.isActive(): boolean
	return flow:isActive()
end

-- Running, Shop or Boss.
function RunDirector.isOngoing(): boolean
	return flow:isOngoing()
end

-- Current wave (while the Shop is open: the wave that just ended), 0 outside a run.
function RunDirector.getWave(): number
	return flow.wave
end

-- Fighting seconds since the run started (stopped in the shop and after the run ended), 0 outside a run.
function RunDirector.getElapsed(): number
	return flow:getElapsed(now())
end

-- Label of the current run's options, e.g. "Danger 3 · Endless" (B11).
function RunDirector.getDifficulty(): string
	return DangerRules.label(flow:getRunOptions())
end

-- B11: the options (danger level, endless, enemy sliders) the current run started with.
function RunDirector.getRunOptions(): Types.RunOptions
	return table.clone(flow:getRunOptions())
end

-- B11: sets the lobby's options for the next run (tests and admin; players use the remote SetRunOptions).
-- Paket 15: `capped` keeps the danger cap of the players in the lobby (options from a run place ticket).
function RunDirector.setOptions(options: Types.RunOptions, capped: boolean?)
	capOverride = not capped -- tests and admins may pick any danger level
	flow:setOptions(DangerRules.clean(options))
	enforceDangerCap()
	process()
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

-- Ends the active run, e.g. "Victory" when the bosses die (BossService, WP10).
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

-- Admin/test switch: the fighting clock stands still during waves while on (stays across runs).
function RunDirector.setHoldWaves(hold: boolean)
	flow:setHoldWaves(hold, now())
	process()
end

function RunDirector.isHoldingWaves(): boolean
	return flow.holdWaves
end

-- B11 part 2: registers what a service keeps from the start of each wave. `save` runs when a wave starts (after
-- WaveStarting) and returns a copy of the state; `restore` gets that copy back when the wave is retried. Restores run
-- in the order the services registered; work that needs every service restored belongs on WaveRetried.
function RunDirector.addCheckpoint(name: string, save: () -> any, restore: (any) -> ())
	table.insert(checkpoints, { name = name, save = save, restore = restore })
end

-- B11 part 2: starts the lost wave again (tests and admin; players use the remote RetryWave).
function RunDirector.retryWave(player: Player): (boolean, string?)
	local ok, reason = flow:retryWave(player.UserId, now())
	process()
	return ok, reason
end

function RunDirector.notifyRejection(player: Player, reason: string?)
	reject(player, reason)
end

-- Picks the player's character for the next run (remote SelectClass; RunPlaceService applies hub picks). Checks
-- that it exists, is playable and unlocked for the player.
function RunDirector.selectClass(player: Player, classId: string): (boolean, string?)
	local class = Config.Classes[classId]
	if not (class and class.available and PlayerDataService.ownsClass(player, classId)) then
		return false, "Locked"
	end
	local ok, reason = flow:setClass(player.UserId, classId)
	enforceDangerCap()
	process()
	if ok then
		RunDirector.ClassSelected:Fire(player, classId)
	end
	return ok, reason
end

-- Paket 15: starts a run for exactly these players after the short countdown: a hub group in Studio (PartyService)
-- or the group that arrived on a run place (RunPlaceService). `options` replace the lobby's; with `capped` the
-- danger cap of the players here still applies (tickets), without it they are used as they are (PartyService
-- already capped them for the group).
function RunDirector.launch(players: { Player }, options: Types.RunOptions?, capped: boolean?): (boolean, string?)
	if flow.phase ~= "Lobby" and flow.phase ~= "Countdown" then
		return false, "Busy"
	end
	if options then
		capOverride = not capped
		flow:setOptions(DangerRules.clean(options))
		enforceDangerCap()
	end
	local userIds = {}
	for _, player in players do
		table.insert(userIds, player.UserId)
	end
	local ok, reason = flow:launch(userIds, now())
	process()
	return ok, reason
end

-- Ready for the next run, like the READY button (RunPlaceService queues players who arrive during a run).
function RunDirector.setReady(player: Player, ready: boolean): (boolean, string?)
	local ok, reason = flow:setReady(player.UserId, ready, now())
	process()
	return ok, reason
end

-- B10: current lobby choice, separate from the frozen participant class of an active run.
function RunDirector.getSelectedClassId(player: Player): string?
	for _, info in flow:snapshot().players do
		if info.userId == player.UserId and Config.Classes[info.classId] then
			return info.classId
		end
	end
	return nil
end

return RunDirector
