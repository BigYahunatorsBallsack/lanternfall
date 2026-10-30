--!strict
-- Down and revive during a wave (DESIGN.md section 8, WP11; rules in Util/ReviveRules, values in Config.Run.coop).
-- A participant at 0 HP is down (CombatService -> RunDirector). A living teammate standing within reviveRadius for
-- reviveSeconds stands them up with reviveHpFraction of their HP (CombatService) and a short protection; after
-- downTimerSeconds without that they are out for the rest of the wave and stand up when it ends (like Brotato's
-- co-op). Nobody alive ends the run (RunFlow). Sends ReviveState to every client on change (ReviveController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local ReviveRules = require(Shared.Util.ReviveRules)
local Types = require(Shared.Net.Types)

local CombatService = require(script.Parent.CombatService)
local MapService = require(script.Parent.MapService)
local RunDirector = require(script.Parent.RunDirector)

local Coop = Config.Run.coop
local SETTINGS: ReviveRules.Settings = {
	downTimerSeconds = Coop.downTimerSeconds,
	reviveSeconds = Coop.reviveSeconds,
	reviveDecaySeconds = Coop.reviveDecaySeconds,
	downTimerPausesWhileReviving = Coop.downTimerPausesWhileReviving,
}

local ReviveService = {}

local downed: { [Player]: ReviveRules.Entry } = {}
local reviverOf: { [Player]: Player } = {}
local out: { [Player]: boolean } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function payload(): Types.ReviveState
	local list: { Types.ReviveInfo } = {}
	local time = now()
	for player, entry in downed do
		local reviver = reviverOf[player]
		table.insert(list, {
			userId = player.UserId,
			state = "Down",
			timeLeft = entry.timeLeft,
			progress = entry.progress,
			reviverUserId = if reviver then reviver.UserId else nil,
			sentAt = time,
		})
	end
	for player in out do
		table.insert(list, { userId = player.UserId, state = "Out", timeLeft = 0, progress = 0, sentAt = time })
	end
	return { players = list }
end

local function send()
	Net.fireAllClients("ReviveState", payload())
end

local function clear()
	local any = next(downed) ~= nil or next(out) ~= nil
	table.clear(downed)
	table.clear(reviverOf)
	table.clear(out)
	if any then
		send()
	end
end

-- The closest living participant within reviveRadius of `player` (ground distance), or nil.
local function findReviver(player: Player): Player?
	local position = MapService.getRootPosition(player)
	if not position then
		return nil
	end
	local best: Player? = nil
	local bestDistance = Coop.reviveRadius
	for _, other in RunDirector.getParticipants() do
		if other ~= player and RunDirector.getParticipantState(other) == "Alive" then
			local otherPosition = MapService.getRootPosition(other)
			if otherPosition then
				local offset = otherPosition - position
				local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if distance <= bestDistance then
					best, bestDistance = other, distance
				end
			end
		end
	end
	return best
end

local function onParticipantState(player: Player, state: Types.ParticipantState)
	if state == "Down" and RunDirector.getPhase() == "Running" then
		downed[player] = ReviveRules.new(SETTINGS)
		reviverOf[player] = nil
		out[player] = nil
	elseif state == "Out" then
		downed[player] = nil
		reviverOf[player] = nil
		out[player] = true
	else
		local wasRevived = downed[player] ~= nil and reviverOf[player] ~= nil
		if downed[player] == nil and not out[player] then
			return
		end
		downed[player] = nil
		reviverOf[player] = nil
		out[player] = nil
		if wasRevived then
			CombatService.protect(player, Coop.reviveProtectionSeconds)
		end
	end
	send()
end

local function step(dt: number)
	if RunDirector.getPhase() ~= "Running" or next(downed) == nil then
		return
	end
	local changed = false
	local outcomes: { [Player]: ReviveRules.Outcome } = {}
	for player, entry in downed do
		local reviver = findReviver(player)
		if reviver ~= reviverOf[player] then
			reviverOf[player] = reviver
			changed = true
		end
		local outcome = ReviveRules.step(entry, dt, reviver ~= nil, SETTINGS)
		if outcome then
			outcomes[player] = outcome
		end
	end
	-- applied after the loop: changing a participant's state fires onParticipantState, which edits `downed`
	for player, outcome in outcomes do
		RunDirector.setParticipantState(player, if outcome == "Revived" then "Alive" else "Out")
	end
	if changed and next(outcomes) == nil then
		send()
	end
end

-- Seconds left and revive progress (0-1) of a downed player, nil if they are not down (tests, admin).
function ReviveService.get(player: Player): (number?, number?)
	local entry = downed[player]
	if not entry then
		return nil, nil
	end
	return entry.timeLeft, entry.progress
end

function ReviveService.init()
	RunDirector.ParticipantStateChanged:Connect(onParticipantState)
	RunDirector.RunStarted:Connect(clear)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Shop" then
			-- end of the wave: players who are down stand up in CombatService, those who are out here
			if Coop.outReturnsAtWaveEnd then
				for player in out do
					RunDirector.setParticipantState(player, "Alive")
				end
			end
			clear()
		elseif phase ~= "Running" then
			clear()
		end
	end)
	RunDirector.SyncRequested:Connect(function(requester)
		Net.fireClient("ReviveState", requester, payload())
	end)
	Players.PlayerRemoving:Connect(function(player)
		if downed[player] or out[player] then
			downed[player] = nil
			reviverOf[player] = nil
			out[player] = nil
			send()
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return ReviveService
