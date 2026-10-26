--!strict
-- Keeps the team level and XP (TeamProgress remote from ExperienceService) and every player's passives (Passives
-- remote from UpgradeService). Read by HUDController (XP bar, passive list).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local ProgressController = {}

-- (progress: Types.TeamProgress, previous: Types.TeamProgress?)
ProgressController.TeamChanged = Signal.new()
-- (userId: number, passives: { Types.PassiveInfo })
ProgressController.PassivesChanged = Signal.new()

local team: Types.TeamProgress? = nil
local passives: { [number]: { Types.PassiveInfo } } = {}

function ProgressController.init()
	Net.onClient("TeamProgress", function(progress: Types.TeamProgress)
		local previous = team
		team = progress
		ProgressController.TeamChanged:Fire(progress, previous)
	end)
	Net.onClient("Passives", function(loadout: Types.PassiveLoadout)
		passives[loadout.userId] = loadout.passives
		ProgressController.PassivesChanged:Fire(loadout.userId, loadout.passives)
	end)
	Players.PlayerRemoving:Connect(function(player)
		passives[player.UserId] = nil
	end)
end

function ProgressController.getTeam(): Types.TeamProgress?
	return team
end

function ProgressController.getPassives(userId: number): { Types.PassiveInfo }
	return passives[userId] or {}
end

function ProgressController.getLocalPassives(): { Types.PassiveInfo }
	return ProgressController.getPassives(Players.LocalPlayer.UserId)
end

return ProgressController
