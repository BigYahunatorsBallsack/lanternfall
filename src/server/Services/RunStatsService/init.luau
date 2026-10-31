--!strict
-- Run statistics for the results screen and playtests (rules in RunStatsService/Tally): counts kills, team level
-- over time, damage taken and downs while a run is active. When the run ends it sends RunSummary to the participants
-- and prints a summary block to the server Output (Developer Console F9 -> Server in a live game).
-- Listens to RunDirector, EnemySim, ExperienceService and CombatService; reads loadouts from WeaponService and
-- StatService (items). Since Paket 12 it also adds each finished run to the participants' saved record
-- (PlayerDataService); since Paket 13 with champion kills and revives (ReviveService) for the achievements.
-- B11 part 2: a RunDirector checkpoint keeps the statistics from the start of each wave for "Retry wave", and a defeat
-- that can still be retried is only saved once the results are over (lobby or "Play again") or the player leaves, so
-- a retried wave never counts twice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)
local Copy = require(Shared.Util.Copy)

local CombatService = require(script.Parent.CombatService)
local EnemySim = require(script.Parent.EnemySim)
local ExperienceService = require(script.Parent.ExperienceService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ReviveService = require(script.Parent.ReviveService)
local RunDirector = require(script.Parent.RunDirector)
local StatService = require(script.Parent.StatService)
local WeaponService = require(script.Parent.WeaponService)
local Tally = require(script.Tally)

local LOG_PREFIX = "[Lanternfall] "

local RunStatsService = {}

local tally = Tally.new()
local lastSummary: Types.RunSummary? = nil
local bossKills = 0 -- bosses only, for the saved record
local championKills = 0 -- Paket 13
local revives: { [Player]: number } = {} -- Paket 13: teammates each player revived this run
local heldRecords: { [Player]: any } = {} -- B11 part 2: defeats that may still be retried, saved later

local function loadoutsOf(participants: { Player }): { [number]: Tally.Loadout }
	local loadouts = {}
	for _, player in participants do
		local damageStats = WeaponService.getDamageStats(player)
		local weapons = {}
		local byId = {}
		for _, weapon in WeaponService.getWeapons(player) do
			local entry = byId[weapon.id]
			if entry then -- copies of one weapon share a line (damage stats add them up), at the highest tier
				entry.tier = math.max(entry.tier, weapon.tier)
				continue
			end
			local stats = damageStats[weapon.id]
			entry = {
				id = weapon.id,
				tier = weapon.tier,
				evolution = weapon.evolution,
				damage = if stats then stats.damage else 0,
				kills = if stats then stats.kills else 0,
			}
			byId[weapon.id] = entry
			table.insert(weapons, entry)
		end
		loadouts[player.UserId] = { weapons = weapons, items = StatService.getItems(player) }
	end
	return loadouts
end

local function onRunStarted(participants: { Player })
	tally = Tally.new()
	lastSummary = nil
	bossKills = 0
	championKills = 0
	table.clear(revives)
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

	if results.outcome ~= "Abandoned" then
		local danger = RunDirector.getRunOptions().danger
		local hold = results.outcome == "Defeat" and (results.retriesLeft or 0) > 0
		for _, player in participants do
			local record = {
				won = results.outcome == "Victory",
				wave = results.wave or RunDirector.getWave(),
				danger = danger,
				classId = RunDirector.getParticipantClassId(player) or "",
				kills = tally.kills,
				bossKills = bossKills,
				seconds = results.survivedSeconds,
				champions = championKills,
				revives = revives[player] or 0,
				players = #results.players,
			}
			if hold then
				heldRecords[player] = record
			else
				PlayerDataService.recordRun(player, record)
			end
		end
	end
end

-- Saves a defeat that was held back for "Retry wave" (the results are over or the player leaves).
local function saveHeld(player: Player)
	local record = heldRecords[player]
	heldRecords[player] = nil
	if record then
		local ok, rewards = PlayerDataService.recordRun(player, record)
		if ok and rewards then
			Net.fireClient("Notify", player, `Run saved: +{rewards.embers} Embers`)
		end
	end
end

local function saveAllHeld()
	for player in heldRecords do
		saveHeld(player)
	end
end

type Saved = { tally: Tally.Tally, bossKills: number, championKills: number, revives: { [Player]: number } }

-- Lifecycle -------------------------------------------------------------------------

function RunStatsService.init()
	RunDirector.RunStarted:Connect(onRunStarted)
	RunDirector.RunEnded:Connect(onRunEnded)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Lobby" or phase == "Countdown" then
			saveAllHeld()
		end
	end)
	PlayerDataService.onRelease(saveHeld)
	RunDirector.addCheckpoint("RunStats", function(): Saved
		return {
			tally = Copy.deep(tally),
			bossKills = bossKills,
			championKills = championKills,
			revives = table.clone(revives),
		}
	end, function(saved: Saved)
		table.clear(heldRecords) -- the run goes on
		tally = Copy.deep(saved.tally)
		bossKills = saved.bossKills
		championKills = saved.championKills
		revives = table.clone(saved.revives)
		lastSummary = nil
	end)
	RunDirector.SyncRequested:Connect(function(player)
		if lastSummary and RunDirector.getPhase() == "Ended" then
			Net.fireClient("RunSummary", player, lastSummary)
		end
		PlayerDataService.sync(player)
	end)
	RunDirector.ParticipantStateChanged:Connect(function(player, state)
		if state == "Down" then
			tally:recordDown(player.UserId, RunDirector.getElapsed())
		end
	end)
	EnemySim.EnemyKilled:Connect(function(info)
		if RunDirector.isActive() then
			tally:recordKill(info.enemyId)
			if Config.Enemies.bosses[info.enemyId] then
				bossKills += 1
			elseif Config.Enemies.champions[info.enemyId] then
				championKills += 1
			end
		end
	end)
	ExperienceService.LevelGained:Connect(function(level)
		if RunDirector.isActive() then
			tally:recordLevel(level, RunDirector.getElapsed())
		end
	end)
	ReviveService.Revived:Connect(function(reviver: Player)
		if RunDirector.isActive() then
			revives[reviver] = (revives[reviver] or 0) + 1
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
