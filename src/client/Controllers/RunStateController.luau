--!strict
-- Keeps the latest RunState from the server and answers phase and timer questions for the UI.
-- Used by every UI controller; listens to the RunState remote and asks for a full sync on start.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

-- What the local player sees: the lobby, the run HUD or the results of the run they just played.
export type View = "Lobby" | "Run" | "Results"

local RunStateController = {}

-- (state: Types.RunState)
RunStateController.Changed = Signal.new()

local state: Types.RunState? = nil

function RunStateController.init()
	Net.onClient("RunState", function(newState: Types.RunState)
		if state and newState.version < state.version then
			return -- an older sync reply overtaken by a newer broadcast
		end
		state = newState
		RunStateController.Changed:Fire(newState)
	end)
end

function RunStateController.start()
	Net.fireServer("RequestSync")
end

function RunStateController.get(): Types.RunState?
	return state
end

function RunStateController.getPlayer(userId: number): Types.PlayerInfo?
	if not state then
		return nil
	end
	for _, info in state.players do
		if info.userId == userId then
			return info
		end
	end
	return nil
end

function RunStateController.getLocalPlayer(): Types.PlayerInfo?
	return RunStateController.getPlayer(Players.LocalPlayer.UserId)
end

function RunStateController.getView(): View
	local info = RunStateController.getLocalPlayer()
	if not (state and info and info.participant) then
		return "Lobby"
	end
	if state.phase == "Ended" then
		return "Results"
	elseif state.phase == "Running" or state.phase == "Shop" or state.phase == "Boss" then
		return "Run"
	end
	return "Lobby"
end

function RunStateController.now(): number
	return workspace:GetServerTimeNow()
end

-- Fighting seconds since the run started (stopped in the shop and after the run ended), 0 outside a run.
function RunStateController.getElapsed(): number
	if not (state and state.runStartedAt) then
		return 0
	end
	local stop = state.pausedAt or state.runEndedAt or RunStateController.now()
	return stop - state.runStartedAt - state.pausedSeconds
end

-- Seconds left in the countdown, the shop or on the results screen.
function RunStateController.getPhaseRemaining(): number
	if not (state and state.phaseEndsAt) then
		return 0
	end
	return math.max(0, state.phaseEndsAt - RunStateController.now())
end

return RunStateController
