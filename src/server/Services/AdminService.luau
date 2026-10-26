--!strict
-- Debug commands for testing (skip time, knock yourself down, win). Admins only: everyone in Studio,
-- the owner of a user-owned experience and Config.Admin.userIds. Handles the DebugCommand remote and
-- uses RunDirector. Sets the player attribute "LanternfallAdmin" so the client shows the debug panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DebugCommands = require(Shared.Net.DebugCommands)
local Net = require(Shared.Net)

local RunDirector = require(script.Parent.RunDirector)

local ADMIN_ATTRIBUTE = "LanternfallAdmin"

local AdminService = {}

local handlers: { [string]: (player: Player) -> (boolean, string?) } = {
	SkipMinute = function()
		return RunDirector.skipTo(RunDirector.getElapsed() + Config.Admin.skipMinuteSeconds)
	end,
	SkipToBoss = function()
		return RunDirector.skipTo(Config.Run.durationSeconds - Config.Admin.skipToBossLeadSeconds)
	end,
	DownSelf = function(player)
		return RunDirector.setParticipantState(player, "Down")
	end,
	ReviveSelf = function(player)
		return RunDirector.setParticipantState(player, "Alive")
	end,
	WinRun = function()
		return RunDirector.endRun("Victory")
	end,
}

function AdminService.isAdmin(player: Player): boolean
	if Config.Admin.allowInStudio and RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(Config.Admin.userIds, player.UserId) ~= nil
end

function AdminService.init()
	for _, command in DebugCommands do
		assert(handlers[command], `Debug command {command} has no handler`)
	end

	local function onPlayerAdded(player: Player)
		player:SetAttribute(ADMIN_ATTRIBUTE, AdminService.isAdmin(player))
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Net.onServer("DebugCommand", function(player, command: string)
		if not AdminService.isAdmin(player) then
			return
		end
		local ok, reason = handlers[command](player)
		print(`[Lanternfall] Debug command {command} by {player.Name}: {if ok then "done" else reason}`)
		if not ok then
			RunDirector.notifyRejection(player, reason)
		end
	end)
end

return AdminService
