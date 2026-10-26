--!strict
-- Spawns enemies while a run is in its Running phase (DESIGN.md section 7, base version from WP3): the rate
-- grows per minute and player, spawning pauses at the alive cap, enemies appear on a ring around a random
-- living player, the mix follows the minute and HP grows per minute and difficulty (rules in SpawnRules).
-- Swarm Rush and elites follow in WP9. Uses EnemySim; AdminService pauses it and spawns test waves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local EnemySim = require(script.Parent.EnemySim)
local MapService = require(script.Parent.MapService)
local RunDirector = require(script.Parent.RunDirector)
local SpawnRules = require(script.SpawnRules)

local SPAWN_TRIES = 12 -- random ring points tried per enemy before giving up until the next one

local SpawnDirector = {}

local paused = false
local pending = 0 -- fractional enemies owed by the spawn rate
local rng = Random.new()
local obstacles: { SpawnRules.Circle } = MapService.getObstacles()
local bounds: SpawnRules.Rect = (function()
	local arena = MapService.getArenaBounds()
	return {
		minX = arena.center.X - arena.halfSize,
		maxX = arena.center.X + arena.halfSize,
		minZ = arena.center.Z - arena.halfSize,
		maxZ = arena.center.Z + arena.halfSize,
	}
end)()

local function roll(): number
	return rng:NextNumber()
end

local function minutes(): number
	return RunDirector.getElapsed() / 60
end

local function playerCount(): number
	return #RunDirector.getParticipants()
end

local function alivePositions(): { Vector3 }
	local positions = {}
	for _, player in RunDirector.getParticipants() do
		if RunDirector.getParticipantState(player) == "Alive" then
			local position = MapService.getRootPosition(player)
			if position then
				table.insert(positions, position)
			end
		end
	end
	return positions
end

-- Spawns one enemy of the current mix on the ring around `around`. Returns false if no free spot was found
-- or the hard cap is reached.
local function spawnOne(around: Vector3, atMinutes: number): boolean
	local enemyId = SpawnRules.pickEnemy(SpawnRules.mixAt(atMinutes), roll())
	local kind = Config.Enemies.types[enemyId]
	local x, z = SpawnRules.findSpawnPoint(roll, around.X, around.Z, kind.radius, bounds, obstacles, SPAWN_TRIES)
	if not (x and z) then
		return false
	end
	local tiers = Config.Difficulty.tiers
	local tier = tiers[RunDirector.getDifficulty()] or tiers[Config.Difficulty.default]
	local hpMultiplier = SpawnRules.hpFactor(atMinutes) * tier.enemyHp
	return EnemySim.spawn(enemyId, x, z, hpMultiplier, tier.enemyDamage) ~= nil
end

local function update(dt: number)
	local count = playerCount()
	local atMinutes = minutes()
	pending += SpawnRules.rate(atMinutes, count) * dt
	if pending < 1 then
		return
	end
	local positions = alivePositions()
	if #positions == 0 then
		pending = 0 -- nobody to spawn around (everyone down): do not save up enemies for later
		return
	end
	local cap = SpawnRules.cap(count)
	while pending >= 1 do
		if EnemySim.getCount() >= cap then
			pending = 1 -- spawning pauses at the cap; the next free slot fills right away
			return
		end
		pending -= 1
		spawnOne(positions[rng:NextInteger(1, #positions)], atMinutes)
	end
end

-- Lifecycle -------------------------------------------------------------------------

function SpawnDirector.init()
	RunDirector.RunStarted:Connect(function()
		pending = 0
		paused = false
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		if not paused and RunDirector.getPhase() == "Running" then
			update(dt)
		end
	end)
end

-- Commands --------------------------------------------------------------------------

function SpawnDirector.setPaused(value: boolean)
	paused = value
	pending = 0
end

function SpawnDirector.isPaused(): boolean
	return paused
end

-- Spawns up to `count` enemies of the current mix around `around`, stopping at the alive cap
-- (AdminService "SpawnWave"). Returns how many spawned.
function SpawnDirector.spawnWave(around: Vector3, count: number): number
	local cap = SpawnRules.cap(playerCount())
	local atMinutes = minutes()
	local spawned = 0
	for _ = 1, count do
		if EnemySim.getCount() >= cap then
			break
		end
		if spawnOne(around, atMinutes) then
			spawned += 1
		end
	end
	return spawned
end

-- Queries ---------------------------------------------------------------------------

-- Alive cap for the current player count.
function SpawnDirector.getCap(): number
	return SpawnRules.cap(playerCount())
end

-- Enemies per second right now (0 while paused or outside the Running phase).
function SpawnDirector.getRate(): number
	if paused or RunDirector.getPhase() ~= "Running" then
		return 0
	end
	return SpawnRules.rate(minutes(), playerCount())
end

return SpawnDirector
