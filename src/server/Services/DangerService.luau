--!strict
-- The current run's danger rules (B11, Config.Difficulty, formulas in Util/DangerRules): which waves are elite or
-- horde waves (planned per block of waves once the run's seed is set, Spawns stream), the multipliers on new enemies'
-- HP, damage and speed (danger level, enemy sliders, endless factor) and which kinds spawn. Announces horde waves.
-- Used by SpawnDirector, BossService, ExperienceService and LootService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DangerRules = require(Shared.Util.DangerRules)
local Net = require(Shared.Net)

local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)

local DangerService = {}

local plan: { [number]: DangerRules.Challenge } = {}
local plannedBlocks: { [number]: boolean } = {}
local pool: { string } = {}
local announcedWave = 0

local function planUpTo(wave: number)
	local block = DangerRules.block(wave)
	for k = 0, block do
		if not plannedBlocks[k] then
			plannedBlocks[k] = true
			local random = RandomService.stream("Spawns")
			local blockPlan = DangerRules.planBlock(RunDirector.getRunOptions().danger, k, function(n: number): number
				return random:NextInteger(1, n)
			end, function(): number
				return random:NextNumber()
			end, pool)
			for number, challenge in blockPlan do
				plan[number] = challenge
			end
		end
	end
end

local function clear()
	table.clear(plan)
	table.clear(plannedBlocks)
	table.clear(pool)
	announcedWave = 0
end

function DangerService.init()
	RunDirector.RunStarted:Connect(clear)
	RunService.Heartbeat:Connect(function()
		if RunDirector.getPhase() ~= "Running" then
			return
		end
		local wave = RunDirector.getWave()
		planUpTo(wave)
		if announcedWave ~= wave then
			announcedWave = wave
			local challenge = plan[wave]
			if challenge and challenge.kind == "Horde" then
				for _, player in RunDirector.getParticipants() do
					Net.fireClient("Notify", player, "A horde wave! Enemies pour in.")
				end
			end
		end
	end)
end

-- The elite or horde wave planned for `wave`, or nil (plans that wave's block first).
function DangerService.getChallenge(wave: number): DangerRules.Challenge?
	if not RunDirector.isOngoing() then
		return nil
	end
	planUpTo(wave)
	return plan[wave]
end

-- True while a horde wave is running.
function DangerService.isHorde(): boolean
	if RunDirector.getPhase() ~= "Running" then
		return false
	end
	local challenge = DangerService.getChallenge(RunDirector.getWave())
	return challenge ~= nil and challenge.kind == "Horde"
end

-- Multiplier on the spawn groups' enemies right now: base tuning, the Enemy count slider and hordes.
function DangerService.spawnMultiplier(): number
	local horde = if DangerService.isHorde() then Config.Difficulty.horde.spawnMultiplier else 1
	return horde * DangerRules.countMultiplier(RunDirector.getRunOptions())
end

-- Multiplier on the chance that a killed enemy drops its orb right now (hordes drop fewer).
function DangerService.orbShare(): number
	return if DangerService.isHorde() then Config.Difficulty.horde.orbShare else 1
end

-- HP, damage and speed multipliers for an enemy spawned in `wave` (danger level, sliders, endless factor).
function DangerService.multipliers(wave: number): (number, number, number)
	return DangerRules.multipliers(RunDirector.getRunOptions(), wave)
end

-- True if spawn groups of `enemyId` take part on this run's danger level.
function DangerService.spawns(enemyId: string): boolean
	return DangerRules.spawns(RunDirector.getRunOptions().danger, enemyId)
end

function DangerService.getDanger(): number
	return RunDirector.getRunOptions().danger
end

function DangerService.isEndless(): boolean
	return RunDirector.getRunOptions().endless
end

-- The planned elite and horde waves so far (tests, debug).
function DangerService.getPlan(): { [number]: DangerRules.Challenge }
	return table.clone(plan)
end

return DangerService
