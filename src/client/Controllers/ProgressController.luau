--!strict
-- Keeps the team level and XP (TeamProgress remote from ExperienceService) and every player's items (Items remote
-- from StatService). Read by HUDController (XP bar, item list).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local ProgressController = {}

-- (progress: Types.TeamProgress, previous: Types.TeamProgress?)
ProgressController.TeamChanged = Signal.new()
-- (userId: number, items: { Types.ItemInfo })
ProgressController.ItemsChanged = Signal.new()

local team: Types.TeamProgress? = nil
local items: { [number]: { Types.ItemInfo } } = {}

function ProgressController.init()
	Net.onClient("TeamProgress", function(progress: Types.TeamProgress)
		local previous = team
		team = progress
		ProgressController.TeamChanged:Fire(progress, previous)
	end)
	Net.onClient("Items", function(loadout: Types.ItemLoadout)
		items[loadout.userId] = loadout.items
		ProgressController.ItemsChanged:Fire(loadout.userId, loadout.items)
	end)
	Players.PlayerRemoving:Connect(function(player)
		items[player.UserId] = nil
	end)
end

function ProgressController.getTeam(): Types.TeamProgress?
	return team
end

function ProgressController.getItems(userId: number): { Types.ItemInfo }
	return items[userId] or {}
end

function ProgressController.getLocalItems(): { Types.ItemInfo }
	return ProgressController.getItems(Players.LocalPlayer.UserId)
end

return ProgressController
