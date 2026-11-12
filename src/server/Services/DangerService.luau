--!strict
-- The current run's danger rules (B11, Config.Difficulty, formulas in Util/DangerRules): which waves are elite or
-- horde waves (planned per block of waves once the run's seed is set, Spawns stream), the multipliers on new enemies'
-- HP, damage and speed (danger level, enemy sliders, endless factor) and which kinds spawn. Announces horde waves.
-- Since Paket 14 it sends the planned waves to the participants (remote WavePlan) for the HUD's preview.
-- Used by SpawnDirector, BossService, ExperienceService and LootService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DangerRules = require(Shared.Util.DangerRules)
local NightmareRules = require(Shared.Util.NightmareRules)
local Nightmare = require(Shared.Config.Nightmare)
local HordeOverrides = require(Shared.Config.CharacterMechanics).hordeChanceOverrides
local Net = require(Shared.Net)
local Types = require(Shared.Net.Types)

local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)

local DangerService = {}

local plan: { [number]: DangerRules.Challenge } = {}
local nightmarePlan = NightmareRules.new()
local plannedBlocks: { [number]: boolean } = {}
local pool: { string } = {}
local announcedWave = 0
local sentCount = -1 -- planned waves last sent with WavePlan

-- The plan as a list by wave (Net/Types.WaveChallenge).
local function planList(): { Types.WaveChallenge }
	local list = {}
	for wave, challenge in plan do
		table.insert(list, { wave = wave, kind = challenge.kind })
	end
	table.sort(list, function(a, b)
		return a.wave < b.wave
	end)
	return list
end

local function sendPlan(players: { Player })
	local list = planList()
	for _, player in players do
		Net.fireClient("WavePlan", player, list)
	end
end

local function planUpTo(wave: number)
	local block = DangerRules.block(wave)
	for k = 0, block do
		if not plannedBlocks[k] then
			plannedBlocks[k] = true
			local hordeChance: number? = nil
			for _, player in RunDirector.getParticipants() do
				local id = RunDirector.getParticipantClassId(player)
				if id and HordeOverrides[id] ~= nil then
					hordeChance = HordeOverrides[id]
				end
			end
			local random = RandomService.stream("Spawns")
			local blockPlan = DangerRules.planBlock(RunDirector.getRunOptions().danger, k, function(n: number): number
				return random:NextInteger(1, n)
			end, function(): number
				return random:NextNumber()
			end, pool, hordeChance)
			for number, challenge in blockPlan do
				plan[number] = challenge
			end
		end
	end
end

local function clear()
	nightmarePlan = NightmareRules.new()
	table.clear(plan)
	table.clear(plannedBlocks)
	table.clear(pool)
	announcedWave = 0
	sentCount = -1
end

function DangerService.init()
	RunDirector.RunStarted:Connect(clear)
	RunDirector.SyncRequested:Connect(function(player)
		if RunDirector.isOngoing() and sentCount >= 0 then
			sendPlan({ player })
		end
	end)
	RunService.Heartbeat:Connect(function()
		if RunDirector.getPhase() ~= "Running" then
			return
		end
		local wave = RunDirector.getWave()
		planUpTo(wave)
		local count = #planList()
		if count ~= sentCount then
			sentCount = count
			sendPlan(RunDirector.getParticipants())
		end
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

-- Multiplier on the spawn groups' enemies right now: base tuning and the Enemy count slider. Horde waves add
-- Brotato's horde groups instead of multiplying (SpawnRules.groupsFor).
function DangerService.spawnMultiplier(): number
	return DangerRules.countMultiplier(RunDirector.getRunOptions())
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

-- Original default Nightmare events, planned once against the real frozen elite/horde occupancy.
-- PlayerDataService and the lobby/party caps enforce the saved-progress prerequisite for difficulty6.
function DangerService.getNightmareEvent(wave: number): string?
	local danger = RunDirector.getRunOptions().danger
	if danger < Nightmare.level or not RunDirector.isOngoing() then
		return nil
	end
	planUpTo(wave)
	local base = if wave <= Nightmare.events.firstBlock * 2
		then Nightmare.events.firstBlock
		else math.floor((wave - 1) / Nightmare.events.firstBlock) * Nightmare.events.firstBlock
	local occupied = {}
	for number in plan do
		occupied[number] = true
	end
	local random = RandomService.stream("Spawns")
	NightmareRules.generate(
		nightmarePlan,
		danger,
		base,
		occupied,
		Nightmare.events.defaultConstantProjectiles,
		function(minimum, maximum)
			return random:NextInteger(minimum, maximum)
		end
	)
	for _, number in nightmarePlan.fog do
		if number == wave then
			return "fog_of_war"
		end
	end
	for _, number in nightmarePlan.bullets do
		if number == wave then
			return "bullet_hell"
		end
	end
	return nil
end

return DangerService
