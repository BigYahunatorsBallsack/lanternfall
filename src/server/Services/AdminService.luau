--!strict
-- Debug commands for testing (skip time, knock yourself down, win, spawn/hit/kill enemies, pause spawning)
-- and the stats panel feed (DebugStats once per second). Admins only: everyone in Studio, the owner of a
-- user-owned experience and Config.Admin.userIds. Handles the DebugCommand remote and uses RunDirector,
-- EnemySim, SpawnDirector and MapService. Sets the player attribute "LanternfallAdmin" so the client shows
-- the debug panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DebugCommands = require(Shared.Net.DebugCommands)
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)

local EnemySim = require(script.Parent.EnemySim)
local MapService = require(script.Parent.MapService)
local RunDirector = require(script.Parent.RunDirector)
local SpawnDirector = require(script.Parent.SpawnDirector)

local ADMIN_ATTRIBUTE = "LanternfallAdmin"

local AdminService = {}

local hitList: { number } = {}

local function enemies(count: number): string
	return if count == 1 then "1 enemy" else `{count} enemies`
end

-- The admin's position during a run, or nil plus a RunDirector rejection reason.
local function runPosition(player: Player): (Vector3?, string?)
	if not RunDirector.isActive() then
		return nil, "NotRunning"
	end
	local position = MapService.getRootPosition(player)
	if not position then
		return nil, "NoCharacter"
	end
	return position, nil
end

-- Each handler returns ok plus, on failure, a RunDirector rejection reason or, on success, an optional
-- message for the admin.
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
	SpawnWave = function(player)
		local position, reason = runPosition(player)
		if not position then
			return false, reason
		end
		local spawned = SpawnDirector.spawnWave(position, Config.Admin.spawnWaveCount)
		if spawned == 0 then
			return false, "EnemyCap"
		end
		return true, `Spawned {enemies(spawned)}`
	end,
	HitNearby = function(player)
		local position, reason = runPosition(player)
		if not position then
			return false, reason
		end
		local found = EnemySim.queryRadius(position, Config.Admin.hitNearbyRadius, hitList)
		local killed = 0
		for i = 1, found do
			if EnemySim.damage(hitList[i], Config.Admin.hitNearbyDamage, player) then
				killed += 1
			end
		end
		return true, `Hit {enemies(found)}, {killed} died`
	end,
	KillEnemies = function(player)
		return true, `Killed {enemies(EnemySim.killAll(player))}`
	end,
	ToggleSpawning = function()
		local paused = not SpawnDirector.isPaused()
		SpawnDirector.setPaused(paused)
		return true, if paused then "Enemy spawning paused" else "Enemy spawning resumed"
	end,
}

local function collectStats(): Types.DebugStats
	local sim = EnemySim.getStats()
	local rate = SpawnDirector.getRate()
	return {
		enemies = EnemySim.getCount(),
		cap = SpawnDirector.getCap(),
		spawnRate = rate,
		spawning = rate > 0,
		paused = SpawnDirector.isPaused(),
		stepMilliseconds = sim.stepMilliseconds,
		stepMaxMilliseconds = sim.stepMaxMilliseconds,
		stepsPerSecond = sim.stepsPerSecond,
		sentKilobytesPerSecond = sim.sentKilobytesPerSecond,
	}
end

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
		local ok, detail = handlers[command](player)
		print(`[Lanternfall] Debug command {command} by {player.Name}: {if ok then detail or "done" else detail}`)
		if not ok then
			RunDirector.notifyRejection(player, detail)
		elseif detail then
			Net.fireClient("Notify", player, detail)
		end
	end)
end

-- Sends the stats panel numbers to every admin once per Config.Admin.statsInterval.
function AdminService.start()
	while true do
		task.wait(Config.Admin.statsInterval)
		local stats: Types.DebugStats? = nil
		for _, player in Players:GetPlayers() do
			if player:GetAttribute(ADMIN_ATTRIBUTE) == true then
				stats = stats or collectStats()
				Net.fireClient("DebugStats", player, stats)
			end
		end
	end
end

return AdminService
