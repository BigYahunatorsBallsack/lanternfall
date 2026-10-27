--!strict
-- Run statistics for the results screen and playtests (rules in RunStatsService/Tally): counts kills, team level
-- over time, damage taken and downs while a run is active. When the run ends it sends RunSummary to the participants
-- and prints a summary block to the server Output (Developer Console F9 -> Server in a live game).
-- Listens to RunDirector, EnemySim, ExperienceService and CombatService; reads loadouts from WeaponService and
-- StatService (items).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)

local CombatService = require(script.Parent.CombatService)
local EnemySim = require(script.Parent.EnemySim)
local ExperienceService = require(script.Parent.ExperienceService)
local RunDirector = require(script.Parent.RunDirector)
local StatService = require(script.Parent.StatService)
local WeaponService = require(script.Parent.WeaponService)
local Tally = require(script.Tally)

local LOG_PREFIX = "[Lanternfall] "

local RunStatsService = {}

local tally = Tally.new()
local lastSummary: Types.RunSummary? = nil

local function loadoutsOf(participants: { Player }): { [number]: Tally.Loadout }
	local loadouts = {}
	for _, player in participants do
		local damageStats = WeaponService.getDamageStats(player)
		local weapons = {}
		for _, weapon in WeaponService.getWeapons(player) do
			local stats = damageStats[weapon.id]
			table.insert(weapons, {
				id = weapon.id,
				level = weapon.level,
				damage = if stats then stats.damage else 0,
				kills = if stats then stats.kills else 0,
			})
		end
		loadouts[player.UserId] = { weapons = weapons, items = StatService.getItems(player) }
	end
	return loadouts
end

local function onRunStarted(participants: { Player })
	tally = Tally.new()
	lastSummary = nil
	for _, player in participants do
		tally:addPlayer(player.UserId, player.DisplayName, RunDirector.getParticipantClassId(player) or "")
	end
end

local function onRunEnded(results: Types.Results)
	-- Participants still in the server; their weapons stay until the next run starts.
	local participants = {}
	for _, entry in results.players do
		local player = Players:GetPlayerByUserId(entry.userId)
		if player then
			table.insert(participants, player)
		end
	end
	local loadouts = loadoutsOf(participants)
	local summary = tally:summary(loadouts)
	lastSummary = summary

	print(`{LOG_PREFIX}===== Run summary (copy this block for your playtest notes) =====`)
	for _, line in tally:logLines(results, loadouts) do
		print(LOG_PREFIX .. line)
	end
	print(`{LOG_PREFIX}=====`)

	for _, player in participants do
		Net.fireClient("RunSummary", player, summary)
	end
end

-- Lifecycle -------------------------------------------------------------------------

function RunStatsService.init()
	RunDirector.RunStarted:Connect(onRunStarted)
	RunDirector.RunEnded:Connect(onRunEnded)
	RunDirector.SyncRequested:Connect(function(player)
		if lastSummary and RunDirector.getPhase() == "Ended" then
			Net.fireClient("RunSummary", player, lastSummary)
		end
	end)
	RunDirector.ParticipantStateChanged:Connect(function(player, state)
		if state == "Down" then
			tally:recordDown(player.UserId, RunDirector.getElapsed())
		end
	end)
	EnemySim.EnemyKilled:Connect(function(info)
		if RunDirector.isActive() then
			tally:recordKill(info.enemyId)
		end
	end)
	ExperienceService.LevelGained:Connect(function(level)
		if RunDirector.isActive() then
			tally:recordLevel(level, RunDirector.getElapsed())
		end
	end)
	CombatService.PlayerDamaged:Connect(function(player, taken)
		tally:recordDamageTaken(player.UserId, taken)
	end)
end

-- Statistics of the current (or last) run, e.g. for the balance sim.
function RunStatsService.getTally(): Tally.Tally
	return tally
end

return RunStatsService
