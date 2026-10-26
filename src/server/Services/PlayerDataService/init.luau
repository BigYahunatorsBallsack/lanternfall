--!strict
-- Player data for the session (schema in ProfileTemplate). Until WP12 it lives in memory only and is
-- NOT saved. Called by RunDirector for class checks; WP12 swaps in ProfileStore with session locking.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileTemplate = require(script.ProfileTemplate)

local PlayerDataService = {}

local sessions: { [Player]: ProfileTemplate.Data } = {}

local function load(player: Player)
	if not sessions[player] then
		sessions[player] = ProfileTemplate.new()
	end
end

function PlayerDataService.init()
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		load(player)
	end
end

-- nil until the data is loaded.
function PlayerDataService.get(player: Player): ProfileTemplate.Data?
	return sessions[player]
end

-- Free classes are always owned; others must be unlocked in the profile.
function PlayerDataService.ownsClass(player: Player, classId: string): boolean
	local class = Config.Classes[classId]
	if not class then
		return false
	end
	if class.free then
		return true
	end
	local data = sessions[player]
	return data ~= nil and table.find(data.classes, classId) ~= nil
end

return PlayerDataService
