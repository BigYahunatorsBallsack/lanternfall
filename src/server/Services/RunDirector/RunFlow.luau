--!strict
-- Rules of the run flow as a pure state machine: lobby, countdown, run, boss phase, results.
-- Owned by RunDirector, which feeds it player events and the clock (`now` in seconds). No Roblox APIs
-- here, so the rules are unit-tested outside Studio (tests/RunFlow.spec.luau).
--
-- Every change bumps `version`; transitions are queued as events and collected with drainEvents().

local Types = require(game:GetService("ReplicatedStorage").Shared.Net.Types)

type Phase = Types.Phase
type ParticipantState = Types.ParticipantState
type Outcome = Types.Outcome

export type Settings = {
	countdownSeconds: number,
	allReadyCountdownSeconds: number,
	resultsSeconds: number,
	durationSeconds: number,
	maxPlayers: number,
	defaultClassId: string,
	difficulty: string,
}

export type Event =
	{ kind: "PhaseChanged", phase: Phase, previous: Phase }
	| { kind: "RunStarted", userIds: { number } }
	| { kind: "RunEnded", results: Types.Results }
	| { kind: "ParticipantStateChanged", userId: number, state: ParticipantState }

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
		difficulty: string,
		players: { [number]: Entry },
		participants: { [number]: Participant },
		results: Types.Results?,
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
		difficulty = settings.difficulty,
		players = {},
		participants = {},
		results = nil,
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

local evaluate: (self: RunFlow, now: number) -> ()

local function toLobby(self: RunFlow, now: number)
	table.clear(self.participants)
	self.runStartedAt = nil
	self.runEndedAt = nil
	self.results = nil
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
		}
		table.insert(userIds, entry.userId)
	end
	self.runStartedAt = now
	self.runEndedAt = nil
	self.results = nil
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

	local results: Types.Results = {
		outcome = outcome,
		survivedSeconds = now - (self.runStartedAt :: number),
		difficulty = self.difficulty,
		players = entries,
	}
	self.runEndedAt = now
	self.results = results
	push(self, { kind = "RunEnded", results = results })

	if next(self.participants) == nil then
		toLobby(self, now) -- nobody left to show results to
	else
		setPhase(self, "Ended", now + self.settings.resultsSeconds)
	end
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
	elseif phase == "Running" or phase == "Boss" then
		if next(self.participants) == nil then
			finishRun(self, "Abandoned", now)
		elseif not anyAlive(self) then
			finishRun(self, "Defeat", now)
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

-- Running or Boss.
function RunFlow.isActive(self: RunFlow): boolean
	return self.phase == "Running" or self.phase == "Boss"
end

-- Part of a run that is still going.
function RunFlow.isInRun(self: RunFlow, userId: number): boolean
	return self:isActive() and self.participants[userId] ~= nil
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

-- Seconds since the run started (frozen once it ended), 0 outside a run.
function RunFlow.getElapsed(self: RunFlow, now: number): number
	local startedAt = self.runStartedAt
	if not startedAt then
		return 0
	end
	return (self.runEndedAt or now) - startedAt
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
	if not self:isActive() then
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

-- Moves the run timer forward to `elapsed` seconds (never backwards, never past the boss). Admin only.
function RunFlow.skipTo(self: RunFlow, elapsed: number, now: number): (boolean, string?)
	if self.phase ~= "Running" then
		return false, "NotRunning"
	end
	local target = math.min(elapsed, self.settings.durationSeconds)
	if target <= self:getElapsed(now) then
		return false, "AlreadyPast"
	end
	self.runStartedAt = now - target
	changed(self)
	self:update(now)
	return true, nil
end

-- Ends a running run, e.g. "Victory" when the boss dies.
function RunFlow.endRun(self: RunFlow, outcome: Outcome, now: number): (boolean, string?)
	if not self:isActive() then
		return false, "NotRunning"
	end
	finishRun(self, outcome, now)
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
		if self:getElapsed(now) >= self.settings.durationSeconds then
			setPhase(self, "Boss", nil)
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
		})
	end

	return {
		version = self.version,
		phase = self.phase,
		difficulty = self.difficulty,
		phaseEndsAt = self.phaseEndsAt,
		runStartedAt = self.runStartedAt,
		runEndedAt = self.runEndedAt,
		players = players,
		results = self.results,
	}
end

return RunFlow
