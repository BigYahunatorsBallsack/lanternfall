--!strict
-- Applies source enemy credited-player death stat rewards after ordinary death listeners; EnemySim supplies trusted original gains.
local Players = game:GetService("Players")
local Enemy = require(script.Parent.EnemySim)
local Stats = require(script.Parent.StatService)
local Run = require(script.Parent.RunDirector)
local Service = {}
function Service.init()
	Enemy.PlayerKillStats:Connect(function(player: Player, gains: { [string]: number })
		if player.Parent == Players and Run.isOngoing() and Run.getParticipantState(player) ~= nil then
			Stats.addStats(player, gains)
		end
	end)
end
return Service
