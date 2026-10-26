--!strict
-- Spawns enemies while a run is in its Running phase (DESIGN.md section 7, base version from WP3): the rate
-- grows per minute and player, spawning pauses at the alive cap, enemies appear on a ring around a random
-- living player, the mix follows the minute and HP grows per minute and difficulty (rules in SpawnRules).
-- Since WP9: part of the spawns of a walking player land in front of them, a Gloom Elite appears every 2 minutes from
-- 2:00 (above the cap), and Swarm Rush (5:00 and 9:00) doubles the rate with Shadelings only and starts with a ring
-- around every player. Enemies left far behind every player come back on the spawn ring, so running in circles with
-- a trailing crowd does not stop the pressure. Uses EnemySim; AdminService pauses it and spawns test waves and elites.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local EnemyKinds = require(ReplicatedStorage.Shared.Util.EnemyKinds)
local Net = require(ReplicatedStorage.Shared.Net)

local EnemySim = require(script.Parent.EnemySim)
local MapService = require(script.Parent.MapService)
local RunDirector = require(script.Parent.RunDirector)
local SpawnRules = require(script.SpawnRules)

local SPAWN_TRIES = 12 -- random ring points tried per enemy before giving up until the next one

local SpawnDirector = {}

local paused = false
local pending = 0 -- fractional enemies owed by the spawn rate
local lastMinutes = 0 -- run time of the last update, to notice elite and Swarm Rush times passing
local recycleTimer = 0
local recycleIds: { number } = {}
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

type Anchor = { position: Vector3, velocity: Vector3 }

local function aliveAnchors(): { Anchor }
	local anchors = {}
	for _, player in RunDirector.getParticipants() do
		if RunDirector.getParticipantState(player) == "Alive" then
			local position = MapService.getRootPosition(player)
			if position then
				table.insert(anchors, { position = position, velocity = MapService.getRootVelocity(player) })
			end
		end
	end
	return anchors
end

local function notifyParticipants(text: string)
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("Notify", player, text)
	end
end

local function spawnAt(enemyId: string, x: number, z: number, atMinutes: number, elite: boolean?): boolean
	local tiers = Config.Difficulty.tiers
	local tier = tiers[RunDirector.getDifficulty()] or tiers[Config.Difficulty.default]
	local hpMultiplier = SpawnRules.hpFactor(atMinutes) * tier.enemyHp
	return EnemySim.spawn(enemyId, x, z, hpMultiplier, tier.enemyDamage, elite) ~= nil
end

-- Spawns one enemy of `enemyId` on the ring around `anchor`, in front of a walking player for part of the spawns
-- (SpawnRules.aheadHeading). Returns false if no free spot was found or the hard cap is reached.
local function spawnOne(anchor: Anchor, enemyId: string, atMinutes: number, elite: boolean?): boolean
	local kind = EnemyKinds.get(enemyId, elite)
	if not kind then
		return false
	end
	local around, velocity = anchor.position, anchor.velocity
	local heading = SpawnRules.aheadHeading(velocity.X, velocity.Z, roll())
	local x, z =
		SpawnRules.findSpawnPoint(roll, around.X, around.Z, kind.radius, bounds, obstacles, SPAWN_TRIES, heading)
	if not (x and z) and heading then
		x, z = SpawnRules.findSpawnPoint(roll, around.X, around.Z, kind.radius, bounds, obstacles, SPAWN_TRIES)
	end
	if not (x and z) then
		return false
	end
	return spawnAt(enemyId, x, z, atMinutes, elite)
end

-- One Gloom Elite of the current mix around a random living player. Returns its name, or nil without a spot.
local function spawnElite(anchor: Anchor, atMinutes: number): string?
	local enemyId = SpawnRules.pickEnemy(SpawnRules.mixAt(atMinutes), roll())
	if not spawnOne(anchor, enemyId, atMinutes, true) then
		return nil
	end
	local kind = EnemyKinds.get(enemyId, true)
	return if kind then kind.displayName else enemyId
end

-- The closed ring of Shadelings around every living player when a Swarm Rush starts (up to the alive cap).
local function spawnRushRing(anchors: { Anchor }, atMinutes: number, cap: number)
	local rush = Config.Run.spawn.swarmRush
	local kind = EnemyKinds.get(rush.enemy)
	if not kind then
		return
	end
	for _, anchor in anchors do
		local around = anchor.position
		for index = 1, rush.ringCount do
			if EnemySim.getCount() >= cap then
				return
			end
			local x, z = SpawnRules.ringPoint(index, rush.ringCount, around.X, around.Z, Config.Run.spawn.ringMin)
			if SpawnRules.isFree(x, z, kind.radius, bounds, obstacles) then
				spawnAt(rush.enemy, x, z, atMinutes)
			end
		end
	end
end

-- Elites and Swarm Rush starts whose time passed since the last update.
local function updateEvents(atMinutes: number, anchors: { Anchor }, cap: number)
	local from = lastMinutes
	lastMinutes = atMinutes
	if #anchors == 0 then
		return
	end
	if SpawnRules.eliteDue(from, atMinutes) then
		local name = spawnElite(anchors[rng:NextInteger(1, #anchors)], atMinutes)
		if name then
			notifyParticipants(`A {name} appeared! Kill it for a chest.`)
		end
	end
	if SpawnRules.swarmRushStarted(from, atMinutes) then
		notifyParticipants("Swarm Rush! They are everywhere...")
		spawnRushRing(anchors, atMinutes, cap)
	end
end

-- Squared distance from (x, z) to the closest living player.
local function closestSquared(anchors: { Anchor }, x: number, z: number): number
	local best = math.huge
	for _, anchor in anchors do
		local dx, dz = anchor.position.X - x, anchor.position.Z - z
		best = math.min(best, dx * dx + dz * dz)
	end
	return best
end

-- Puts an enemy on a new spawn point around a random living player (in front of them for part of the moves).
local function respawn(id: number, anchors: { Anchor })
	local enemyId, elite = EnemySim.getKind(id)
	local kind = enemyId and EnemyKinds.get(enemyId, elite)
	if not kind then
		return
	end
	local anchor = anchors[rng:NextInteger(1, #anchors)]
	local around, velocity = anchor.position, anchor.velocity
	local heading = SpawnRules.aheadHeading(velocity.X, velocity.Z, roll())
	local x, z =
		SpawnRules.findSpawnPoint(roll, around.X, around.Z, kind.radius, bounds, obstacles, SPAWN_TRIES, heading)
	if x and z then
		EnemySim.teleport(id, Vector3.new(x, around.Y, z))
	end
end

-- Moves enemies left far behind every living player back onto the spawn ring (Config.Run.spawn.recycle); at the cap
-- also the farthest few beyond atCapDistance.
local function recycle(anchors: { Anchor }, cap: number)
	local settings = Config.Run.spawn.recycle
	local farSquared = settings.distance * settings.distance
	local atCapSquared = settings.atCapDistance * settings.atCapDistance
	local count = EnemySim.collectIds(recycleIds)
	local candidates: { { id: number, squared: number } } = {}
	for i = 1, count do
		local id = recycleIds[i]
		local position = EnemySim.getPosition(id)
		if position then
			local squared = closestSquared(anchors, position.X, position.Z)
			if squared > farSquared then
				respawn(id, anchors)
			elseif squared > atCapSquared then
				table.insert(candidates, { id = id, squared = squared })
			end
		end
	end
	if count >= cap and #candidates > 0 then
		table.sort(candidates, function(a, b)
			return a.squared > b.squared
		end)
		for i = 1, math.min(settings.atCapCount, #candidates) do
			respawn(candidates[i].id, anchors)
		end
	end
end

local function update(dt: number)
	local count = playerCount()
	local atMinutes = minutes()
	local cap = SpawnRules.cap(count)
	local anchors = aliveAnchors()
	updateEvents(atMinutes, anchors, cap)
	recycleTimer += dt
	if recycleTimer >= Config.Run.spawn.recycle.intervalSeconds and #anchors > 0 then
		recycleTimer = 0
		recycle(anchors, cap)
	end
	pending += SpawnRules.currentRate(atMinutes, count) * dt
	if pending < 1 then
		return
	end
	if #anchors == 0 then
		pending = 0 -- nobody to spawn around (everyone down): do not save up enemies for later
		return
	end
	local mix = SpawnRules.currentMix(atMinutes)
	while pending >= 1 do
		if EnemySim.getCount() >= cap then
			pending = 1 -- spawning pauses at the cap; the next free slot fills right away
			return
		end
		pending -= 1
		spawnOne(anchors[rng:NextInteger(1, #anchors)], SpawnRules.pickEnemy(mix, roll()), atMinutes)
	end
end

-- Lifecycle -------------------------------------------------------------------------

function SpawnDirector.init()
	RunDirector.RunStarted:Connect(function()
		pending = 0
		paused = false
		lastMinutes = 0
		recycleTimer = 0
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		if not paused and RunDirector.getPhase() == "Running" then
			update(dt)
		end
	end)
end

-- Commands --------------------------------------------------------------------------

-- While paused nothing spawns, also no elites or Swarm Rush (their times passing meanwhile are skipped).
function SpawnDirector.setPaused(value: boolean)
	paused = value
	pending = 0
	lastMinutes = minutes()
end

function SpawnDirector.isPaused(): boolean
	return paused
end

-- Spawns up to `count` enemies of the current mix around `around`, stopping at the alive cap
-- (AdminService "SpawnWave"). Returns how many spawned.
function SpawnDirector.spawnWave(around: Vector3, count: number): number
	local cap = SpawnRules.cap(playerCount())
	local atMinutes = minutes()
	local mix = SpawnRules.currentMix(atMinutes)
	local anchor = { position = around, velocity = Vector3.zero }
	local spawned = 0
	for _ = 1, count do
		if EnemySim.getCount() >= cap then
			break
		end
		if spawnOne(anchor, SpawnRules.pickEnemy(mix, roll()), atMinutes) then
			spawned += 1
		end
	end
	return spawned
end

-- Spawns a Gloom Elite of the current mix on the spawn ring around `around` (AdminService "SpawnElite"). Returns
-- its name, or nil if no free spot was found.
function SpawnDirector.spawnElite(around: Vector3): string?
	return spawnElite({ position = around, velocity = Vector3.zero }, minutes())
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
	return SpawnRules.currentRate(minutes(), playerCount())
end

-- True while a Swarm Rush is running.
function SpawnDirector.isSwarmRush(): boolean
	return RunDirector.getPhase() == "Running" and SpawnRules.isSwarmRush(minutes())
end

return SpawnDirector
