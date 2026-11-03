--!strict
-- Keeps the latest HP state of every player (PlayerState remote from CombatService).
-- Read by HUDController, FeedbackController and AudioController.

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

return PlayerStateController
