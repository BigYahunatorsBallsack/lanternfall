--!strict
-- Rules of the run flow as a pure state machine: lobby, countdown, waves with a shop after each, results. The last
-- wave is the boss wave (BossService); surviving it wins, and so does killing its bosses (endRun, WP10). The old
-- Boss phase is no longer entered. Since B11 the lobby picks run options (danger level, endless mode, enemy sliders;
-- Util/DangerRules); in endless mode the run goes on after the last wave until nobody is alive, and reaching the end
-- of the last wave counts as a win. B11 part 2: after a defeat in a wave, "Retry wave" starts that wave again from its
-- beginning (retryWave, at most maxRetries per run). Paket 15: launch starts a run for a given group right away.
-- Paket 19: a First Night run (runOptions.firstNight) is won after settings.firstNightWaves waves.
-- Playtest after Paket 24: endless mode is no longer picked in the lobby. Winning the boss wave (surviving it or
-- killing its bosses) opens the shop with a vote instead (settings.endlessChoiceSeconds): "Continue" by more than
-- half of the votes turns the run endless and the shop goes on as usual; otherwise (a tie, or time up) it is won.
-- Owned by RunDirector, which feeds it player events and the clock (`now` in seconds). No Roblox APIs
-- here, so the rules are unit-tested outside Studio (tests/RunFlow.spec.luau).
--
-- Every change bumps `version`; transitions are queued as events and collected with drainEvents().

local Shared = game:GetService("ReplicatedStorage").Shared
local DangerRules = require(Shared.Util.DangerRules)
local Types = require(Shared.Net.Types)

type Phase = Types.Phase
type ParticipantState = Types.ParticipantState
type Outcome = Types.Outcome

export type Settings = {
	countdownSeconds: number,
	allReadyCountdownSeconds: number,
	resultsSeconds: number,
	waveEnds: { number }, -- fighting seconds at which each wave ends, rising; the end of the last one wins
	shopSeconds: number, -- shop timer between two waves
	maxPlayers: number,
	defaultClassId: string,
	-- B11: fighting seconds at which wave n ends for any n (endless waves after the last); default: the last end
	-- plus endlessWaveSeconds per wave
	waveEndAt: ((number) -> number)?,
	endlessWaveSeconds: number?,
	maxRetries: number?, -- B11 part 2: "Retry wave" this often per run after a defeat (default 0: never)
	firstNightWaves: number?, -- Paket 19: a First Night run (options.firstNight) wins after this many waves
	-- playtest after Paket 24: seconds of the "continue endless?" vote after winning the boss wave (nil: no vote, the
	-- run is won at once)
	endlessChoiceSeconds: number?,
}

export type Event =
	{ kind: "PhaseChanged", phase: Phase, previous: Phase }
	| { kind: "RunStarted", userIds: { number } }
	| { kind: "RunEnded", results: Types.Results }
	| { kind: "ParticipantStateChanged", userId: number, state: ParticipantState }
	| { kind: "WaveRetried", wave: number }
	| { kind: "EndlessChosen" }

type Entry = {
	userId: number,
	name: string,
	classId: string,
	ready: boolean,
	readyOrder: number,
	joinOrder: number,
}

type Participant = {
	userId: number,
	name: string,
	classId: string, -- locked at run start
	state: ParticipantState,
	shopReady: boolean, -- pressed Ready in the current shop
}

local RunFlow = {}
RunFlow.__index = RunFlow

export type RunFlow = typeof(setmetatable(
	{} :: {
		settings: Settings,
		phase: Phase,
		phaseEndsAt: number?,
		runStartedAt: number?,
		runEndedAt: number?,
		wave: number, -- current wave, or the one that just ended while the shop is open
		pausedSeconds: number, -- shop time so far, not counted as fighting time
		pausedAt: number?, -- while the shop is open: the time the clock stopped
		holdWaves: boolean, -- admin/test switch: the fighting clock stands still while Running (stays across runs)
		heldAt: number?, -- while held: the time the clock stopped
		options: Types.RunOptions, -- B11: the lobby's choice for the next run
		runOptions: Types.RunOptions, -- B11: locked at run start
		players: { [number]: Entry },
		participants: { [number]: Participant },
		results: Types.Results?,
		retries: number, -- B11 part 2: waves retried in this run
		endlessVotes: { [number]: boolean }?, -- while the endless vote after the boss wave is open: userId -> continue
		version: number,
		counter: number,
		events: { Event },
	},
	RunFlow
))

function RunFlow.new(settings: Settings): RunFlow
	return setmetatable({
		settings = settings,
		phase = "Lobby" :: Phase,
		phaseEndsAt = nil,
		runStartedAt = nil,
		runEndedAt = nil,
		wave = 0,
		pausedSeconds = 0,
		pausedAt = nil,
		holdWaves = false,
		heldAt = nil,
		options = DangerRules.defaultOptions(),
		runOptions = DangerRules.defaultOptions(),
		players = {},
		participants = {},
		results = nil,
		retries = 0,
		endlessVotes = nil,
		version = 0,
		counter = 0,
		events = {},
	}, RunFlow)
end

-- Internal transitions ----------------------------------------------------------

local function changed(self: RunFlow)
	self.version += 1
end

local function push(self: RunFlow, event: Event)
	table.insert(self.events, event)
end

local function setPhase(self: RunFlow, phase: Phase, endsAt: number?)
	local previous = self.phase
	self.phase = phase
	self.phaseEndsAt = endsAt
	changed(self)
	push(self, { kind = "PhaseChanged", phase = phase, previous = previous })
end

-- Fighting seconds at which wave n ends; past the last wave the endless ones (B11).
local function waveEnd(self: RunFlow, n: number): number
	local ends = self.settings.waveEnds
	if n <= #ends then
		return ends[n]
	end
	local custom = self.settings.waveEndAt
	if custom then
		return custom(n)
	end
	return ends[#ends] + (n - #ends) * (self.settings.endlessWaveSeconds or 60)
end

-- Paket 19: the run's last wave (the First Night is shorter).
local function lastWave(self: RunFlow): number
	local count = #self.settings.waveEnds
	if self.runOptions.firstNight then
		return math.min(count, self.settings.firstNightWaves or count)
	end
	return count
end

-- In endless mode the end of the last wave was reached (counts as a win, Brotato).
local function pastLastWave(self: RunFlow): boolean
	local count = lastWave(self)
	return self.wave > count or (self.wave == count and self.phase == "Shop")
end

local function countReady(self: RunFlow): number
	local count = 0
	for _, entry in self.players do
		if entry.ready then
			count += 1
		end
	end
	return count
end

local function anyAlive(self: RunFlow): boolean
	for _, participant in self.participants do
		if participant.state == "Alive" then
			return true
		end
	end
	return false
end

-- Cuts the countdown once every player in the server is ready.
local function shortenIfAllReady(self: RunFlow, now: number)
	for _, entry in self.players do
		if not entry.ready then
			return
		end
	end
	local endsAt = now + self.settings.allReadyCountdownSeconds
	if self.phaseEndsAt == nil or endsAt < self.phaseEndsAt then
		self.phaseEndsAt = endsAt
		changed(self)
	end
end

-- Every participant who is still in the game pressed Ready in the shop.
local function allShopReady(self: RunFlow): boolean
	for _, participant in self.participants do
		if participant.state ~= "Out" and not participant.shopReady then
			return false
		end
	end
	return true
end

-- Stops the clock exactly at the end of the current wave and opens the shop.
local function openShop(self: RunFlow, now: number)
	self.pausedAt = (self.runStartedAt :: number) + self.pausedSeconds + waveEnd(self, self.wave)
	for _, participant in self.participants do
		participant.shopReady = false
	end
	setPhase(self, "Shop", now + self.settings.shopSeconds)
end

-- Starts the clock again with the next wave.
local function closeShop(self: RunFlow, now: number)
	self.pausedSeconds += now - (self.pausedAt :: number)
	self.pausedAt = nil
	self.heldAt = if self.holdWaves then now else nil
	self.wave += 1
	setPhase(self, "Running", nil)
end

local evaluate: (self: RunFlow, now: number) -> ()

local function toLobby(self: RunFlow, now: number)
	table.clear(self.participants)
	self.runStartedAt = nil
	self.runEndedAt = nil
	self.wave = 0
	self.pausedSeconds = 0
	self.pausedAt = nil
	self.heldAt = nil
	self.results = nil
	self.endlessVotes = nil
	setPhase(self, "Lobby", nil)
	-- players who pressed "Play again" start the next countdown right away
	evaluate(self, now)
end

local function startRun(self: RunFlow, now: number)
	local ready: { Entry } = {}
	for _, entry in self.players do
		if entry.ready then
			table.insert(ready, entry)
		end
	end
	if #ready == 0 then
		setPhase(self, "Lobby", nil)
		return
	end
	table.sort(ready, function(a, b)
		return a.readyOrder < b.readyOrder
	end)

	table.clear(self.participants)
	local userIds = {}
	for i = 1, math.min(#ready, self.settings.maxPlayers) do
		local entry = ready[i]
		entry.ready = false
		self.participants[entry.userId] = {
			userId = entry.userId,
			name = entry.name,
			classId = entry.classId,
			state = "Alive",
			shopReady = false,
		}
		table.insert(userIds, entry.userId)
	end
	self.runOptions = table.clone(self.options)
	self.runStartedAt = now
	self.runEndedAt = nil
	self.wave = 1
	self.pausedSeconds = 0
	self.pausedAt = nil
	self.heldAt = if self.holdWaves then now else nil
	self.results = nil
	self.retries = 0
	self.endlessVotes = nil
	push(self, { kind = "RunStarted", userIds = userIds })
	setPhase(self, "Running", nil)
end

local function finishRun(self: RunFlow, outcome: Outcome, now: number)
	local entries: { Types.ResultEntry } = {}
	for _, participant in self.participants do
		table.insert(entries, {
			userId = participant.userId,
			name = participant.name,
			classId = participant.classId,
			state = participant.state,
		})
	end
	table.sort(entries, function(a, b)
		return a.name < b.name
	end)

	if outcome == "Defeat" and self.runOptions.endless and pastLastWave(self) then
		outcome = "Victory" -- endless mode: reaching the end of the last wave wins (Brotato)
	end
	local results: Types.Results = {
		outcome = outcome,
		survivedSeconds = self:getElapsed(now), -- fighting time, without the shops
		difficulty = DangerRules.label(self.runOptions),
		players = entries,
		wave = self.wave,
		endless = self.runOptions.endless,
		retriesLeft = if outcome == "Defeat" then math.max(0, (self.settings.maxRetries or 0) - self.retries) else 0,
	}
	self.runEndedAt = now
	self.results = results
	self.endlessVotes = nil
	push(self, { kind = "RunEnded", results = results })

	if next(self.participants) == nil then
		toLobby(self, now) -- nobody left to show results to
	else
		setPhase(self, "Ended", now + self.settings.resultsSeconds)
	end
end

-- Playtest after Paket 24: whether winning the current wave asks the participants about endless mode.
local function offersEndless(self: RunFlow): boolean
	return self.settings.endlessChoiceSeconds ~= nil
		and not self.runOptions.endless
		and not self.runOptions.firstNight
		and self.wave >= lastWave(self)
end

-- The boss wave is won: open its shop with the endless vote (the shop timer waits for the vote).
local function offerEndless(self: RunFlow, now: number)
	openShop(self, now)
	self.endlessVotes = {}
	self.phaseEndsAt = now + (self.settings.endlessChoiceSeconds :: number)
end

-- Counts the votes: more "continue" than "stop" makes the run endless and lets the shop go on; otherwise it is won.
local function closeEndlessVote(self: RunFlow, now: number)
	local continue, stop = 0, 0
	for userId, vote in self.endlessVotes or {} do
		if self.participants[userId] then
			if vote then
				continue += 1
			else
				stop += 1
			end
		end
	end
	self.endlessVotes = nil
	if continue > stop then
		local options = table.clone(self.runOptions)
		options.endless = true
		self.runOptions = options
		self.phaseEndsAt = now + self.settings.shopSeconds
		for _, participant in self.participants do
			participant.shopReady = false
		end
		changed(self)
		push(self, { kind = "EndlessChosen" })
	else
		finishRun(self, "Victory", now)
	end
end

-- Everyone in the run voted.
local function allVoted(self: RunFlow): boolean
	local votes = self.endlessVotes
	if not votes then
		return false
	end
	for userId in self.participants do
		if votes[userId] == nil then
			return false
		end
	end
	return true
end

-- Checks the transitions that depend on player state rather than on time.
function evaluate(self: RunFlow, now: number)
	local phase = self.phase
	if phase == "Lobby" then
		if countReady(self) > 0 then
			setPhase(self, "Countdown", now + self.settings.countdownSeconds)
			shortenIfAllReady(self, now)
		end
	elseif phase == "Countdown" then
		if countReady(self) == 0 then
			setPhase(self, "Lobby", nil)
		else
			shortenIfAllReady(self, now)
		end
	elseif phase == "Running" or phase == "Boss" or phase == "Shop" then
		if next(self.participants) == nil then
			finishRun(self, "Abandoned", now)
		elseif self.endlessVotes then
			if allVoted(self) then
				closeEndlessVote(self, now)
			end
		elseif not anyAlive(self) then
			finishRun(self, "Defeat", now)
		elseif phase == "Shop" and allShopReady(self) then
			closeShop(self, now)
		end
	elseif phase == "Ended" then
		-- everyone who played pressed "Play again" (or left): skip the rest of the results
		for userId in self.participants do
			local entry = self.players[userId]
			if entry and not entry.ready then
				return
			end
		end
		toLobby(self, now)
	end
end

-- Queries -----------------------------------------------------------------------

-- Running or Boss: enemies, weapons and damage are on.
function RunFlow.isActive(self: RunFlow): boolean
	return self.phase == "Running" or self.phase == "Boss"
end

-- Running, Shop or Boss: a run is going (the shop is the pause between two waves).
function RunFlow.isOngoing(self: RunFlow): boolean
	return self:isActive() or self.phase == "Shop"
end

-- Part of a run that is still going.
function RunFlow.isInRun(self: RunFlow, userId: number): boolean
	return self:isOngoing() and self.participants[userId] ~= nil
end

function RunFlow.isParticipant(self: RunFlow, userId: number): boolean
	return self.participants[userId] ~= nil
end

function RunFlow.getParticipantIds(self: RunFlow): { number }
	local userIds = {}
	for userId in self.participants do
		table.insert(userIds, userId)
	end
	table.sort(userIds)
	return userIds
end

function RunFlow.getParticipantState(self: RunFlow, userId: number): ParticipantState?
	local participant = self.participants[userId]
	return if participant then participant.state else nil
end

-- Class locked in at run start, nil for non-participants.
function RunFlow.getParticipantClassId(self: RunFlow, userId: number): string?
	local participant = self.participants[userId]
	return if participant then participant.classId else nil
end

-- Fighting seconds since the run started: stops while the shop is open and once the run ended, 0 outside a run.
function RunFlow.getElapsed(self: RunFlow, now: number): number
	local startedAt = self.runStartedAt
	if not startedAt then
		return 0
	end
	return (self.pausedAt or self.heldAt or self.runEndedAt or now) - startedAt - self.pausedSeconds
end

-- Player events -------------------------------------------------------------------

function RunFlow.addPlayer(self: RunFlow, userId: number, name: string)
	if self.players[userId] then
		return
	end
	self.counter += 1
	self.players[userId] = {
		userId = userId,
		name = name,
		classId = self.settings.defaultClassId,
		ready = false,
		readyOrder = 0,
		joinOrder = self.counter,
	}
	changed(self)
end

function RunFlow.removePlayer(self: RunFlow, userId: number, now: number)
	if not self.players[userId] and not self.participants[userId] then
		return
	end
	self.players[userId] = nil
	self.participants[userId] = nil
	changed(self)
	evaluate(self, now)
end

-- classId must already be validated (exists, available, owned).
function RunFlow.setClass(self: RunFlow, userId: number, classId: string): (boolean, string?)
	local entry = self.players[userId]
	if not entry then
		return false, "UnknownPlayer"
	end
	if self:isInRun(userId) then
		return false, "InRun"
	end
	if entry.classId ~= classId then
		entry.classId = classId
		changed(self)
	end
	return true, nil
end

-- Paket 15: starts a run for exactly these players (a group from the hub in Studio, or the group that arrived on a
-- run place): they become ready and the short countdown starts. Only from the lobby (or an open countdown).
function RunFlow.launch(self: RunFlow, userIds: { number }, now: number): (boolean, string?)
	if self.phase ~= "Lobby" and self.phase ~= "Countdown" then
		return false, "Busy"
	end
	local any = false
	for _, userId in userIds do
		local entry = self.players[userId]
		if entry then
			any = true
			if not entry.ready then
				entry.ready = true
				self.counter += 1
				entry.readyOrder = self.counter
				changed(self)
			end
		end
	end
	if not any then
		return false, "UnknownPlayer"
	end
	local endsAt = now + self.settings.allReadyCountdownSeconds
	if self.phase == "Lobby" then
		setPhase(self, "Countdown", endsAt)
	elseif self.phaseEndsAt == nil or endsAt < self.phaseEndsAt then
		self.phaseEndsAt = endsAt
		changed(self)
	end
	return true, nil
end

-- Ready = join the next run. On the results screen this is the "Play again" button.
function RunFlow.setReady(self: RunFlow, userId: number, ready: boolean, now: number): (boolean, string?)
	local entry = self.players[userId]
	if not entry then
		return false, "UnknownPlayer"
	end
	if self:isInRun(userId) then
		return false, "InRun"
	end
	if entry.ready ~= ready then
		entry.ready = ready
		if ready then
			self.counter += 1
			entry.readyOrder = self.counter
		end
		changed(self)
		evaluate(self, now)
	end
	return true, nil
end

function RunFlow.setParticipantState(
	self: RunFlow,
	userId: number,
	state: ParticipantState,
	now: number
): (boolean, string?)
	if not self:isOngoing() then
		return false, "NotRunning"
	end
	local participant = self.participants[userId]
	if not participant then
		return false, "NotParticipant"
	end
	if participant.state ~= state then
		participant.state = state
		changed(self)
		push(self, { kind = "ParticipantStateChanged", userId = userId, state = state })
		evaluate(self, now)
	end
	return true, nil
end

-- Moves the run timer forward to `elapsed` fighting seconds (never backwards, never past the end), into the wave
-- that contains it; a wave's exact end opens its shop. Admin only.
function RunFlow.skipTo(self: RunFlow, elapsed: number, now: number): (boolean, string?)
	if self.phase ~= "Running" then
		return false, "NotRunning"
	end
	local ends = self.settings.waveEnds
	local target = if self.runOptions.endless then elapsed else math.min(elapsed, ends[lastWave(self)])
	if target <= self:getElapsed(now) then
		return false, "AlreadyPast"
	end
	local wave = 1
	while target > waveEnd(self, wave) do
		wave += 1
	end
	self.wave = wave
	self.runStartedAt = (self.heldAt or now) - target - self.pausedSeconds
	changed(self)
	self:update(now)
	return true, nil
end

-- Ends a running run, e.g. "Victory" when the boss dies.
-- Admin/test switch: while on, the fighting clock stands still during waves (no wave ends unless skipped to).
-- Stays until changed, also across runs.
function RunFlow.setHoldWaves(self: RunFlow, hold: boolean, now: number)
	if self.holdWaves == hold then
		return
	end
	self.holdWaves = hold
	if self.phase == "Running" then
		if hold then
			self.heldAt = now
		elseif self.heldAt then
			self.pausedSeconds += now - self.heldAt
			self.heldAt = nil
		end
	end
	changed(self)
end

-- Ready in the shop: once every participant still in the game is ready, the next wave starts.
function RunFlow.setShopReady(self: RunFlow, userId: number, ready: boolean, now: number): (boolean, string?)
	if self.phase ~= "Shop" then
		return false, "NotShopping"
	end
	if self.endlessVotes then
		return false, "ChoosingEndless"
	end
	local participant = self.participants[userId]
	if not participant then
		return false, "NotParticipant"
	end
	if participant.shopReady ~= ready then
		participant.shopReady = ready
		changed(self)
		evaluate(self, now)
	end
	return true, nil
end

-- B11 part 2: after a defeat, starts the lost wave again from its beginning with every participant still in the game
-- standing (Brotato's "Retry wave"). Any participant may ask while the results show. WaveRetried comes first, so the
-- services restore their wave-start state (RunDirector checkpoints) before the participants stand up and the wave
-- starts again (PhaseChanged Ended -> Running).
function RunFlow.retryWave(self: RunFlow, userId: number, now: number): (boolean, string?)
	local results = self.results
	if self.phase ~= "Ended" or not results or results.outcome ~= "Defeat" then
		return false, "NotDefeated"
	end
	if not self.participants[userId] then
		return false, "NotParticipant"
	end
	if (results.retriesLeft or 0) <= 0 then
		return false, "NoRetriesLeft"
	end
	self.retries += 1
	push(self, { kind = "WaveRetried", wave = self.wave })
	self.results = nil
	self.runEndedAt = nil
	self.pausedAt = nil
	self.heldAt = if self.holdWaves then now else nil
	-- the clock goes back to the start of the wave
	local startsAt = if self.wave > 1 then waveEnd(self, self.wave - 1) else 0
	self.runStartedAt = now - startsAt - self.pausedSeconds
	for id, participant in self.participants do
		participant.shopReady = false
		local entry = self.players[id]
		if entry then
			entry.ready = false -- a "Play again" pressed on the results no longer counts
		end
		if participant.state ~= "Alive" then
			participant.state = "Alive"
			push(self, { kind = "ParticipantStateChanged", userId = id, state = "Alive" })
		end
	end
	setPhase(self, "Running", nil)
	return true, nil
end

function RunFlow.endRun(self: RunFlow, outcome: Outcome, now: number): (boolean, string?)
	if not self:isOngoing() then
		return false, "NotRunning"
	end
	if outcome == "Victory" and self.phase == "Running" and offersEndless(self) then
		offerEndless(self, now) -- the bosses died: ask about endless mode first
		return true, nil
	end
	finishRun(self, outcome, now)
	return true, nil
end

-- Playtest after Paket 24: a participant's vote after the boss wave (true: continue in endless mode). A changed vote
-- counts; the vote closes once everyone voted or its time is up.
function RunFlow.chooseEndless(self: RunFlow, userId: number, continue: boolean, now: number): (boolean, string?)
	local votes = self.endlessVotes
	if self.phase ~= "Shop" or not votes then
		return false, "NoEndlessChoice"
	end
	if not self.participants[userId] then
		return false, "NotParticipant"
	end
	if votes[userId] ~= continue then
		votes[userId] = continue
		changed(self)
		evaluate(self, now)
	end
	return true, nil
end

-- Clock -------------------------------------------------------------------------------

-- Applies the time-based transitions. Called every frame by RunDirector.
function RunFlow.update(self: RunFlow, now: number)
	local phase = self.phase
	if phase == "Countdown" then
		if now >= (self.phaseEndsAt :: number) then
			startRun(self, now)
		end
	elseif phase == "Running" then
		if self:getElapsed(now) >= waveEnd(self, self.wave) then
			if offersEndless(self) then
				offerEndless(self, now) -- surviving the boss wave wins; first the endless vote
			elseif self.wave >= lastWave(self) and not self.runOptions.endless then
				finishRun(self, "Victory", now) -- surviving the boss wave wins, like Brotato (WP10)
			else
				openShop(self, now)
			end
		end
	elseif phase == "Shop" then
		if now >= (self.phaseEndsAt :: number) then
			if self.endlessVotes then
				closeEndlessVote(self, now)
			else
				closeShop(self, now)
			end
		end
	elseif phase == "Ended" then
		if now >= (self.phaseEndsAt :: number) then
			toLobby(self, now)
		end
	end
end

-- Output -------------------------------------------------------------------------------

function RunFlow.hasEvents(self: RunFlow): boolean
	return #self.events > 0
end

function RunFlow.drainEvents(self: RunFlow): { Event }
	local events = self.events
	self.events = {}
	return events
end

-- Full state for clients (Net/Types.RunState).
function RunFlow.snapshot(self: RunFlow): Types.RunState
	local entries: { Entry } = {}
	for _, entry in self.players do
		table.insert(entries, entry)
	end
	table.sort(entries, function(a, b)
		return a.joinOrder < b.joinOrder
	end)

	local players: { Types.PlayerInfo } = {}
	for _, entry in entries do
		local participant = self.participants[entry.userId]
		table.insert(players, {
			userId = entry.userId,
			name = entry.name,
			classId = entry.classId,
			ready = entry.ready,
			participant = participant ~= nil,
			state = if participant then participant.state else nil,
			shopReady = if participant then participant.shopReady else nil,
		})
	end

	return {
		version = self.version,
		phase = self.phase,
		difficulty = DangerRules.label(
			if self:isOngoing() or self.phase == "Ended" then self.runOptions else self.options
		),
		phaseEndsAt = self.phaseEndsAt,
		runStartedAt = self.runStartedAt,
		runEndedAt = self.runEndedAt,
		wave = self.wave,
		pausedSeconds = self.pausedSeconds,
		pausedAt = self.pausedAt or self.heldAt,
		players = players,
		results = self.results,
		options = table.clone(self.options),
		runOptions = if self.runStartedAt then table.clone(self.runOptions) else nil,
		endlessVote = (function(): { Types.EndlessVote }?
			local votes = self.endlessVotes
			if not votes then
				return nil
			end
			local list: { Types.EndlessVote } = {}
			for userId, continue in votes do
				table.insert(list, { userId = userId, continue = continue })
			end
			table.sort(list, function(a, b)
				return a.userId < b.userId
			end)
			return list
		end)(),
	}
end

-- B11: the lobby's choice for the next run (`options` already cleaned by DangerRules.clean). Any player in the
-- server may change it; a running run keeps the options it started with.
function RunFlow.setOptions(self: RunFlow, options: Types.RunOptions)
	local old = self.options
	if
		old.danger == options.danger
		and old.endless == options.endless
		and old.enemyHp == options.enemyHp
		and old.enemyDamage == options.enemyDamage
		and old.enemySpeed == options.enemySpeed
		and old.enemyCount == options.enemyCount
		and old.firstNight == options.firstNight
	then
		return
	end
	self.options = table.clone(options)
	changed(self)
end

-- B11: the options the current (or last) run started with.
function RunFlow.getRunOptions(self: RunFlow): Types.RunOptions
	return self.runOptions
end

return RunFlow
