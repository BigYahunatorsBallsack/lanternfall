--!strict
-- Spawn formulas from DESIGN.md section 7, as pure functions of Config.Run: the spawn groups of each wave (since B9,
-- with Swarm Rush), alive cap, HP and damage growth per wave (Config.Enemies), elite times and the spawn ring around
-- a player (optionally in front of them). Waves come from the shared Util/RunSchedule, which the HUD uses too. Used by
-- SpawnDirector; tested in tests/SpawnRules.spec.luau. `minutes` is schedule time (RunSchedule.minutesAt): one
-- minute per wave, fractions allowed.

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local RunSchedule = require(Shared.Util.RunSchedule)

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Circle = { x: number, z: number, radius: number }

local Spawn = Config.Run.spawn

local SpawnRules = {}

-- fPlayers = 1 + perExtraPlayer * (n - 1)
function SpawnRules.playerFactor(playerCount: number): number
	return 1 + Config.Run.playerFactor.perExtraPlayer * (math.max(playerCount, 1) - 1)
end

-- Enemies alive at the same time; spawning pauses at this number.
function SpawnRules.cap(playerCount: number): number
	local cap = Spawn.cap
	return math.min(cap.base + cap.perExtraPlayer * (math.max(playerCount, 1) - 1), cap.max)
end

-- The wave (1 for the first) running at schedule minute `minutes`.
function SpawnRules.waveAt(minutes: number): number
	return math.clamp(math.floor(minutes) + 1, 1, #Spawn.groups)
end

-- Multipliers on an enemy's HP and damage when it spawns in `wave` (before difficulty): its kind's values plus
-- hpPerWave and damagePerWave for every wave after the first, like Brotato (B9).
function SpawnRules.growth(enemyId: string, wave: number): (number, number)
	local kind = Config.Enemies.types[enemyId]
	if not kind then
		return 1, 1
	end
	local waves = math.max(0, wave - 1)
	local hp = if kind.hp > 0 then 1 + kind.hpPerWave * waves / kind.hp else 1
	local damage = kind.contactDamage
	if damage <= 0 and kind.ranged then
		damage = kind.ranged.projectileDamage
	end
	return hp, if damage > 0 then 1 + kind.damagePerWave * waves / damage else 1
end

-- Swarm Rush running at this minute: the wave's groups pause, Shadeling groups come at rateMultiplier their rate.
function SpawnRules.isSwarmRush(minutes: number): boolean
	local rush = Spawn.swarmRush
	for _, start in rush.atMinutes do
		if minutes >= start and minutes < start + rush.durationShare then
			return true
		end
	end
	return false
end

export type Group = { enemy: string, size: number, every: number }

-- Enemies per second of a wave's groups (before the wave intensity and player count).
local function groupRate(groups: { Group }): number
	local rate = 0
	for _, entry in groups do
		rate += entry.size / entry.every
	end
	return rate
end

local rushGroups: { [number]: { Group } } = {}

-- The spawn groups running at this minute: the wave's own, or during a Swarm Rush one Shadeling group with
-- rateMultiplier times their enemies per second.
function SpawnRules.groupsAt(minutes: number): { Group }
	local wave = SpawnRules.waveAt(minutes)
	local groups = Spawn.groups[wave].groups :: { Group }
	if not SpawnRules.isSwarmRush(minutes) then
		return groups
	end
	local rush = rushGroups[wave]
	if not rush then
		local settings = Spawn.swarmRush
		rush = {
			{
				enemy = settings.enemy,
				size = groupRate(groups) * settings.rateMultiplier * settings.every,
				every = settings.every,
			},
		}
		rushGroups[wave] = rush
	end
	return rush
end

-- Enemies per second at this minute including the wave intensity (ramp, final wave), Swarm Rush and players.
function SpawnRules.currentRate(minutes: number, playerCount: number): number
	return groupRate(SpawnRules.groupsAt(minutes))
		* RunSchedule.intensity(minutes)
		* SpawnRules.playerFactor(playerCount)
end

-- Enemies one firing of `group` brings at this minute (fractions carry over to its next firing).
function SpawnRules.groupSize(group: Group, minutes: number, playerCount: number): number
	return group.size * RunSchedule.intensity(minutes) * SpawnRules.playerFactor(playerCount)
end

-- Seconds into its wave at which a group fires the first time.
function SpawnRules.firstFiring(group: Group): number
	return group.every * Spawn.firstShare
end

local mixes: { [any]: { [string]: number } } = {}

-- The kinds of the groups running at this minute, weighted by enemies per second (elites, debug waves).
function SpawnRules.mixAt(minutes: number): { [string]: number }
	local groups = SpawnRules.groupsAt(minutes)
	local weights = mixes[groups]
	if not weights then
		weights = {}
		for _, entry in groups do
			weights[entry.enemy] = (weights[entry.enemy] or 0) + entry.size / entry.every
		end
		mixes[groups] = weights
	end
	return weights
end

-- Offset of one enemy of a group of `count` from the group's spot: random in a disc of groupSpread * sqrt(count).
function SpawnRules.groupOffset(random: () -> number, count: number): (number, number)
	local radius = Spawn.groupSpread * math.sqrt(math.max(count, 1)) * math.sqrt(random())
	local angle = random() * 2 * math.pi
	return math.cos(angle) * radius, math.sin(angle) * radius
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

-- Elites called in (from, to] (Run.spawn.elites).
function SpawnRules.elitesDue(from: number, to: number): number
	return RunSchedule.elitesDue(from, to)
end

-- True if elites spawning at this minute get a random affix.
function SpawnRules.affixesAt(minutes: number): boolean
	return minutes >= Spawn.elites.affixFromMinute
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
