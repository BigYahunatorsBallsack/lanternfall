--!strict
-- Spawn formulas from DESIGN.md section 7, as pure functions of Config.Run: rate, alive cap, HP factor,
-- enemy mix by minute and the spawn ring around a player. Used by SpawnDirector; tested in
-- tests/SpawnRules.spec.luau. `minutes` is the run time in minutes (fractions allowed).

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Circle = { x: number, z: number, radius: number }

local Spawn = Config.Run.spawn

local SpawnRules = {}

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
-- `random` returns numbers in [0, 1). Returns nil when every try hit a wall or an obstacle.
function SpawnRules.findSpawnPoint(
	random: () -> number,
	centerX: number,
	centerZ: number,
	radius: number,
	bounds: Rect,
	obstacles: { Circle },
	tries: number
): (number?, number?)
	for _ = 1, tries do
		local angle = random() * 2 * math.pi
		local distance = Spawn.ringMin + random() * (Spawn.ringMax - Spawn.ringMin)
		local x, z = centerX + math.cos(angle) * distance, centerZ + math.sin(angle) * distance
		if SpawnRules.isFree(x, z, radius, bounds, obstacles) then
			return x, z
		end
	end
	return nil, nil
end

return SpawnRules
