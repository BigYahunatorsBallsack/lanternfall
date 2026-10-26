--!strict
-- Spawn formulas from DESIGN.md section 7, as pure functions of Config.Run: rate, alive cap, HP factor,
-- enemy mix by minute, Swarm Rush, elite times and the spawn ring around a player (optionally in front of them). Used by SpawnDirector; tested in
-- tests/SpawnRules.spec.luau. `minutes` is the run time in minutes (fractions allowed).

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Circle = { x: number, z: number, radius: number }

local Spawn = Config.Run.spawn

local SpawnRules = {}

local RUSH_WEIGHTS = table.freeze({ [Spawn.swarmRush.enemy] = 1 })

-- fPlayers = 1 + perExtraPlayer * (n - 1)
function SpawnRules.playerFactor(playerCount: number): number
	return 1 + Config.Run.playerFactor.perExtraPlayer * (math.max(playerCount, 1) - 1)
end

-- Enemies per second.
function SpawnRules.rate(minutes: number, playerCount: number): number
	return (Spawn.baseRate + Spawn.ratePerMinute * minutes) * SpawnRules.playerFactor(playerCount)
end

-- Enemies alive at the same time; spawning pauses at this number.
function SpawnRules.cap(playerCount: number): number
	local cap = Spawn.cap
	return math.min(cap.base + cap.perExtraPlayer * (math.max(playerCount, 1) - 1), cap.max)
end

-- Multiplier on enemy HP at spawn time.
function SpawnRules.hpFactor(minutes: number): number
	return 1 + Spawn.hpPerMinute * minutes
end

-- Weights of the mix entry that applies at this minute (the last one with fromMinute <= minutes).
function SpawnRules.mixAt(minutes: number): { [string]: number }
	local weights = Spawn.mix[1].weights
	for _, entry in Spawn.mix do
		if entry.fromMinute <= minutes then
			weights = entry.weights
		end
	end
	return weights
end

-- Swarm Rush running at this minute: only `swarmRush.enemy`, rate times `rateMultiplier`.
function SpawnRules.isSwarmRush(minutes: number): boolean
	local rush = Spawn.swarmRush
	for _, start in rush.atMinutes do
		if minutes >= start and minutes < start + rush.durationSeconds / 60 then
			return true
		end
	end
	return false
end

-- Enemies per second including Swarm Rush.
function SpawnRules.currentRate(minutes: number, playerCount: number): number
	local rate = SpawnRules.rate(minutes, playerCount)
	return if SpawnRules.isSwarmRush(minutes) then rate * Spawn.swarmRush.rateMultiplier else rate
end

-- Mix weights including Swarm Rush.
function SpawnRules.currentMix(minutes: number): { [string]: number }
	if SpawnRules.isSwarmRush(minutes) then
		return RUSH_WEIGHTS
	end
	-- Heading (radians, for findSpawnPoint) to spawn in front of a player walking with floor velocity (vx, vz), or nil
	-- for a spawn anywhere on the ring: a walking player gets `ahead.share` of their spawns in front of them.
	function SpawnRules.aheadHeading(vx: number, vz: number, roll: number): number?
		local ahead = Spawn.ahead
		if roll >= ahead.share or vx * vx + vz * vz < ahead.minSpeed * ahead.minSpeed then
			return nil
		end
		return math.atan2(vz, vx)
	end

	-- Point `index` of `count` evenly spread on a circle of `distance` around (centerX, centerZ) (Swarm Rush ring).
	function SpawnRules.ringPoint(
		index: number,
		count: number,
		centerX: number,
		centerZ: number,
		distance: number
	): (number, number)
		local angle = (index - 1) / count * 2 * math.pi
		return centerX + math.cos(angle) * distance, centerZ + math.sin(angle) * distance
	end

	return SpawnRules.mixAt(minutes)
end

-- True if the run time passed a Swarm Rush start in (from, to].
function SpawnRules.swarmRushStarted(from: number, to: number): boolean
	for _, start in Spawn.swarmRush.atMinutes do
		if from < start and start <= to then
			return true
		end
	end
	return false
end

-- True if the run time passed an elite time (firstAtMinute, then every everyMinutes) in (from, to].
function SpawnRules.eliteDue(from: number, to: number): boolean
	local elite = Spawn.elite
	if to < elite.firstAtMinute then
		return false
	end
	local last = elite.firstAtMinute + math.floor((to - elite.firstAtMinute) / elite.everyMinutes) * elite.everyMinutes
	return from < last
end

local sortedKeys: { [any]: { string } } = {}

-- Picks an enemy id from weights with roll in [0, 1). Keys are walked in sorted order, so the same roll
-- always gives the same enemy.
function SpawnRules.pickEnemy(weights: { [string]: number }, roll: number): string
	local keys = sortedKeys[weights]
	if not keys then
		keys = {}
		for key in weights do
			table.insert(keys, key)
		end
		table.sort(keys)
		sortedKeys[weights] = keys
	end
	local total = 0
	for _, key in keys do
		total += weights[key]
	end
	local threshold = roll * total
	local sum = 0
	for _, key in keys do
		sum += weights[key]
		if threshold < sum then
			return key
		end
	end
	return keys[#keys]
end

-- True if a body of `radius` at (x, z) lies inside the rectangle and outside every obstacle.
function SpawnRules.isFree(x: number, z: number, radius: number, bounds: Rect, obstacles: { Circle }): boolean
	if x - radius < bounds.minX or x + radius > bounds.maxX or z - radius < bounds.minZ or z + radius > bounds.maxZ then
		return false
	end
	for _, obstacle in obstacles do
		local reach = obstacle.radius + radius
		if (x - obstacle.x) ^ 2 + (z - obstacle.z) ^ 2 < reach * reach then
			return false
		end
	end
	return true
end

-- A free spot on the ring ringMin..ringMax around (centerX, centerZ), trying up to `tries` random points.
-- `random` returns numbers in [0, 1). With `heading` (radians, the walking direction) the points lie within
-- ahead.halfAngleDegrees of it. Returns nil when every try hit a wall or an obstacle.
function SpawnRules.findSpawnPoint(
	random: () -> number,
	centerX: number,
	centerZ: number,
	radius: number,
	bounds: Rect,
	obstacles: { Circle },
	tries: number,
	heading: number?
): (number?, number?)
	local halfAngle = math.rad(Spawn.ahead.halfAngleDegrees)
	for _ = 1, tries do
		local angle = if heading then heading + (random() * 2 - 1) * halfAngle else random() * 2 * math.pi
		local distance = Spawn.ringMin + random() * (Spawn.ringMax - Spawn.ringMin)
		local x, z = centerX + math.cos(angle) * distance, centerZ + math.sin(angle) * distance
		if SpawnRules.isFree(x, z, radius, bounds, obstacles) then
			return x, z
		end
	end
	return nil, nil
end

-- Heading (radians, for findSpawnPoint) to spawn in front of a player walking with floor velocity (vx, vz), or nil
-- for a spawn anywhere on the ring: a walking player gets `ahead.share` of their spawns in front of them.
function SpawnRules.aheadHeading(vx: number, vz: number, roll: number): number?
	local ahead = Spawn.ahead
	if roll >= ahead.share or vx * vx + vz * vz < ahead.minSpeed * ahead.minSpeed then
		return nil
	end
	return math.atan2(vz, vx)
end

-- Point `index` of `count` evenly spread on a circle of `distance` around (centerX, centerZ) (Swarm Rush ring).
function SpawnRules.ringPoint(
	index: number,
	count: number,
	centerX: number,
	centerZ: number,
	distance: number
): (number, number)
	local angle = (index - 1) / count * 2 * math.pi
	return centerX + math.cos(angle) * distance, centerZ + math.sin(angle) * distance
end

return SpawnRules
