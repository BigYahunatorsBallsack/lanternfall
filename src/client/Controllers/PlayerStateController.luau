--!strict
-- Keeps the latest HP and dash state of every player (PlayerState remote from CombatService).
-- Read by HUDController and InputController; also tracks the local dash cooldown the client predicts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local PlayerStateController = {}

-- (userId: number, vitals: Types.PlayerVitals, previous: Types.PlayerVitals?)
PlayerStateController.Changed = Signal.new()

local states: { [number]: Types.PlayerVitals } = {}
local predictedDashReadyAt = 0

function PlayerStateController.init()
	Net.onClient("PlayerState", function(vitals: Types.PlayerVitals)
		local previous = states[vitals.userId]
		states[vitals.userId] = vitals
		PlayerStateController.Changed:Fire(vitals.userId, vitals, previous)
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player.UserId] = nil
	end)
end

function PlayerStateController.get(userId: number): Types.PlayerVitals?
	return states[userId]
end

function PlayerStateController.getLocal(): Types.PlayerVitals?
	return states[Players.LocalPlayer.UserId]
end

-- Server time of the next allowed dash: the server's value, or the client's own if that is later
-- (the client starts the cooldown the moment it dashes, before the server has answered).
function PlayerStateController.getDashReadyAt(): number
	local vitals = PlayerStateController.getLocal()
	return math.max(predictedDashReadyAt, if vitals then vitals.dashReadyAt else 0)
end

function PlayerStateController.predictDash(readyAt: number)
	predictedDashReadyAt = readyAt
end

-- Clears the prediction, e.g. when a new run starts and the server resets the cooldown.
function PlayerStateController.clearPrediction()
	predictedDashReadyAt = 0
end

return PlayerStateController
