--!strict
-- Spawns enemies while a run is in its Running phase (DESIGN.md section 7, base version from WP3): the rate follows
-- its curve, the minute's wave (ramp, breather, final wave) and the player count, spawning pauses at the alive cap,
-- enemies appear on a ring around a random living player, the mix follows the minute and HP and damage grow along
-- their curves and with the difficulty (rules in SpawnRules and Util/RunSchedule).
-- Since WP9: part of the spawns of a walking player land in front of them, Gloom Elites appear at the minutes in
-- Run.spawn.elites (above the cap; later ones with a random affix), and Swarm Rush (5:00 and 9:00) doubles the rate
-- with Shadelings only and starts with a ring around every player. Enemies left far behind every player come back
-- on the spawn ring, so running in circles with a trailing crowd does not stop the pressure. Since B4 the team's enemy
-- stats from items (Enemies, Enemy HP, Enemy Damage; StatService.getTeamStat) scale the spawn rate and the HP and
-- damage of new enemies, and every roll comes from RandomService's Spawns stream. Since B6 (Config.Loot) every wave
-- brings a few Trees (more with the team's Trees stat) and from wave 3 now and then a Looter, which escapes (is
-- removed without a kill) after a while; neither is ever moved back onto the spawn ring. Since B9 every wave is a set
-- of spawn groups like Brotato's (Config.Run.spawn.groups): each fires every few seconds and brings several enemies
-- of one kind at one spot, which red crosses on the floor (remote SpawnMarkers) show markerSeconds before they come;
-- HP and damage grow per wave and kind (SpawnRules.growth), and the team's Enemy Speed stat makes new enemies faster.
-- Since B11 the danger level (DangerService) decides which kinds spawn, multiplies HP, damage and speed (with the
-- enemy sliders and, in endless mode, Brotato's endless factor), doubles the groups in horde waves and switches the
-- Gloom Elites; past wave 20 (endless) the groups of the last wave go on and growth keeps rising.
-- Uses EnemySim; BossService spawns what champions summon (spawnAt); AdminService pauses it and spawns test waves,
-- elites, Looters and Trees.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local EnemyKinds = require(ReplicatedStorage.Shared.Util.EnemyKinds)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Net.Types)
local LootRules = require(ReplicatedStorage.Shared.Util.LootRules)
local RunSchedule = require(ReplicatedStorage.Shared.Util.RunSchedule)
local StatMath = require(ReplicatedStorage.Shared.Util.StatMath)

local DangerRules = require(ReplicatedStorage.Shared.Util.DangerRules)
local DangerService = require(script.Parent.DangerService)
local EnemySim = require(script.Parent.EnemySim)
local MapService = require(script.Parent.MapService)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local StatService = require(script.Parent.StatService)
local SpawnRules = require(script.SpawnRules)

local SPAWN_TRIES = 12 -- random ring points tried per enemy before giving up until the next one

local SpawnDirector = {}

local paused = false
-- B9: the spawn groups running now (SpawnRules.groupsAt), seconds until each fires and fractional enemies it owes
local activeGroups: { SpawnRules.Group }? = nil
local groupTimers: { number } = {}
local groupOwed: { number } = {}
type Queued = { enemyId: string, x: number, z: number, at: number }
local queued: { Queued } = {} -- enemies whose markers are showing, in order of spawn time
local lastMinutes = 0 -- run time of the last update, to notice elite and Swarm Rush times passing
local recycleTimer = 0
local recycleIds: { number } = {}
-- B6: Looters and Trees of the current wave
local plannedWave = 0 -- the wave whose trees are planned
local lootSeconds = 0 -- seconds into the wave at the last update (Looter rolls)
local treeTimes: { number } = {} -- seconds into the wave at which the next trees appear
local looters: { [number]: number } = {} -- enemy id -> server time at which it escapes
local trees: { [number]: boolean } = {} -- enemy ids
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
	return RandomService.number("Spawns")
end

local function pickIndex(count: number): number
	return RandomService.stream("Spawns"):NextInteger(1, count)
end

local function minutes(): number
	return RunSchedule.minutesAt(RunDirector.getElapsed())
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

local function spawnAt(
	enemyId: string,
	x: number,
	z: number,
	atMinutes: number,
	elite: boolean?,
	affix: number?
): number?
	local wave = SpawnRules.runWave(atMinutes)
	local dangerHp, dangerDamage, dangerSpeed = DangerService.multipliers(wave)
	local hpGrowth, damageGrowth = SpawnRules.growth(enemyId, wave)
	local hpMultiplier = hpGrowth * dangerHp * StatMath.enemyFactor(StatService.getTeamStat("enemyHp"))
	local damageMultiplier = damageGrowth * dangerDamage * StatMath.enemyFactor(StatService.getTeamStat("enemyDamage"))
	local speedMultiplier = dangerSpeed * StatMath.enemyFactor(StatService.getTeamStat("enemySpeed"))
	return EnemySim.spawn(enemyId, x, z, hpMultiplier, damageMultiplier, elite, affix, speedMultiplier)
end

-- Spawns one enemy of `enemyId` on the ring around `anchor`, in front of a walking player for part of the spawns
-- (SpawnRules.aheadHeading). Returns false if no free spot was found or the hard cap is reached.
local function spawnOne(anchor: Anchor, enemyId: string, atMinutes: number, elite: boolean?, affix: number?): boolean
	local kind = EnemyKinds.get(enemyId, elite, affix)
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
	return spawnAt(enemyId, x, z, atMinutes, elite, affix) ~= nil
end

-- One Gloom Elite of the current mix around a random living player, from Run.spawn.elites.affixFromMinute with a
-- random affix. Returns its name, or nil without a spot.
local function spawnElite(anchor: Anchor, atMinutes: number): string?
	local enemyId = SpawnRules.pickEnemy(SpawnRules.mixAt(atMinutes, DangerService.getDanger()), roll())
	local affix = if SpawnRules.affixesAt(atMinutes) then pickIndex(#Config.Enemies.elite.affixes) else nil
	if not spawnOne(anchor, enemyId, atMinutes, true, affix) then
		return nil
	end
	local kind = EnemyKinds.get(enemyId, true, affix)
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
			local x, z = SpawnRules.ringPoint(index, rush.ringCount, around.X, around.Z, rush.ringDistance)
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
	local gloom = DangerRules.level(DangerService.getDanger()).gloomElites -- B11: off on every level by default
	for _ = 1, if gloom then SpawnRules.elitesDue(from, atMinutes) else 0 do
		local name = spawnElite(anchors[pickIndex(#anchors)], atMinutes)
		if name then
			notifyParticipants(`A {name} appeared! Kill it for a chest.`)
		end
	end
	if SpawnRules.swarmRushStarted(from, atMinutes) then
		spawnRushRing(anchors, atMinutes, cap) -- the HUD's wave banner announces it
	end
end

-- Loot enemies (B6) ------------------------------------------------------------------

local function prune(ids: { [number]: any }): number
	local count = 0
	for id in ids do
		if EnemySim.isAlive(id) then
			count += 1
		else
			ids[id] = nil
		end
	end
	return count
end

-- A Looter at Config.Loot.looter.spawnDistance from `anchor`. Returns its id, or nil without a free spot.
local function spawnLooter(anchor: Anchor, atMinutes: number): number?
	local rule = Config.Loot.looter
	local kind = EnemyKinds.get(rule.enemy)
	if not kind then
		return nil
	end
	local around = anchor.position
	for _ = 1, SPAWN_TRIES do
		local angle = roll() * 2 * math.pi
		local x = around.X + math.cos(angle) * rule.spawnDistance
		local z = around.Z + math.sin(angle) * rule.spawnDistance
		if SpawnRules.isFree(x, z, kind.radius, bounds, obstacles) then
			local id = spawnAt(rule.enemy, x, z, atMinutes)
			if id then
				looters[id] = workspace:GetServerTimeNow() + rule.lifetimeSeconds
			end
			return id
		end
	end
	return nil
end

-- A Tree at a random free spot of the arena at least Config.Loot.trees.minPlayerDistance from every living player
-- (`near`: close to that point instead, debug). Returns its id, or nil without a spot or at maxAlive trees.
local function spawnTree(anchors: { Anchor }, atMinutes: number, near: Vector3?): number?
	local rule = Config.Loot.trees
	local kind = EnemyKinds.get(rule.enemy)
	if not kind or prune(trees) >= rule.maxAlive then
		return nil
	end
	local minSquared = rule.minPlayerDistance * rule.minPlayerDistance
	for _ = 1, SPAWN_TRIES do
		local x, z
		if near then
			local angle = roll() * 2 * math.pi
			x, z = near.X + math.cos(angle) * 12, near.Z + math.sin(angle) * 12
		else
			x = bounds.minX + kind.radius + roll() * (bounds.maxX - bounds.minX - 2 * kind.radius)
			z = bounds.minZ + kind.radius + roll() * (bounds.maxZ - bounds.minZ - 2 * kind.radius)
		end
		local clear = near ~= nil
		if not clear then
			clear = true
			for _, anchor in anchors do
				local dx, dz = anchor.position.X - x, anchor.position.Z - z
				if dx * dx + dz * dz < minSquared then
					clear = false
					break
				end
			end
		end
		if clear and SpawnRules.isFree(x, z, kind.radius, bounds, obstacles) then
			local id = spawnAt(rule.enemy, x, z, atMinutes)
			if id then
				trees[id] = true
			end
			return id
		end
	end
	return nil
end

-- Trees due in this wave, Looter rolls and Looters that escape (B6).
local function updateLoot(atMinutes: number, anchors: { Anchor })
	local wave = RunDirector.getWave()
	local schedule = RunSchedule.wave(wave)
	local seconds = RunDirector.getElapsed() - schedule.startsAt
	if plannedWave ~= wave then
		plannedWave = wave
		lootSeconds = 0
		table.clear(looters)
		table.clear(trees)
		local count = LootRules.treesForWave(StatService.getTeamStat("trees"), roll())
		treeTimes = LootRules.treeTimes(count, schedule.endsAt - schedule.startsAt)
	end
	if #anchors > 0 then
		while treeTimes[1] and seconds >= treeTimes[1] do
			table.remove(treeTimes, 1)
			spawnTree(anchors, atMinutes)
		end
		local rule = Config.Loot.looter
		for _ = 1, LootRules.looterRollsDue(wave, lootSeconds, seconds) do
			if roll() < rule.chance then
				for _ = 1, rule.count do
					spawnLooter(anchors[pickIndex(#anchors)], atMinutes)
				end
			end
		end
	end
	lootSeconds = seconds
end

-- Looters whose time is up escape (also while spawning is paused).
local function escapeLooters()
	local now = workspace:GetServerTimeNow()
	for id, escapeAt in looters do
		if not EnemySim.isAlive(id) then
			looters[id] = nil
		elseif now >= escapeAt then
			looters[id] = nil
			EnemySim.remove(id)
		end
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
	local kind = enemyId and EnemyKinds.get(enemyId, elite) -- the affix does not change the radius
	if not kind then
		return
	end
	local anchor = anchors[pickIndex(#anchors)]
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
		local enemyId = EnemySim.getKind(id)
		local kind = enemyId and EnemyKinds.get(enemyId)
		-- B9: eggs stay where they were laid; WP10: bosses keep their own way
		local fixed = looters[id] or trees[id] or (kind and (kind.anchored or kind.boss))
		local position = if fixed then nil else EnemySim.getPosition(id)
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

-- Spawn groups (B9) -----------------------------------------------------------------

-- Puts `count` enemies of `enemyId` around one spot on the ring around `anchor` (in front of a walking player for
-- part of the groups) into the queue and shows their markers. Returns how many were placed.
local function queueGroup(anchor: Anchor, enemyId: string, count: number): number
	local kind = EnemyKinds.get(enemyId)
	if not kind then
		return 0
	end
	local around, velocity = anchor.position, anchor.velocity
	local heading = SpawnRules.aheadHeading(velocity.X, velocity.Z, roll())
	local x, z =
		SpawnRules.findSpawnPoint(roll, around.X, around.Z, kind.radius, bounds, obstacles, SPAWN_TRIES, heading)
	if not (x and z) and heading then
		x, z = SpawnRules.findSpawnPoint(roll, around.X, around.Z, kind.radius, bounds, obstacles, SPAWN_TRIES)
	end
	if not (x and z) then
		return 0
	end
	local at = workspace:GetServerTimeNow() + Config.Run.spawn.markerSeconds
	local points = {}
	for _ = 1, count do
		local px, pz = x, z
		for _ = 1, 3 do
			local dx, dz = SpawnRules.groupOffset(roll, count)
			if SpawnRules.isFree(x + dx, z + dz, kind.radius, bounds, obstacles) then
				px, pz = x + dx, z + dz
				break
			end
		end
		table.insert(queued, { enemyId = enemyId, x = px, z = pz, at = at })
		table.insert(points, px)
		table.insert(points, pz)
	end
	local markers: Types.SpawnMarkers = { points = points, spawnsAt = at }
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("SpawnMarkers", player, markers)
	end
	return count
end

-- Spawns the queued enemies whose markers ran out.
local function spawnQueued(atMinutes: number)
	local now = workspace:GetServerTimeNow()
	while queued[1] and queued[1].at <= now do
		local entry = table.remove(queued, 1) :: Queued
		spawnAt(entry.enemyId, entry.x, entry.z, atMinutes)
	end
end

-- Counts down the running spawn groups; a group that fires adds its enemies to what it owes, and owed enemies are
-- placed as soon as the alive cap leaves room (enemies whose markers show count too), so a full cap delays a group
-- instead of dropping it (at most a few firings are saved up). Nobody alive: nothing is owed.
local function updateGroups(dt: number, atMinutes: number, anchors: { Anchor }, cap: number)
	local groups = SpawnRules.groupsAt(atMinutes, DangerService.getDanger())
	if groups ~= activeGroups then
		activeGroups = groups
		table.clear(groupTimers)
		table.clear(groupOwed)
		for index, entry in groups do
			groupTimers[index] = SpawnRules.firstFiring(entry)
			groupOwed[index] = 0
		end
	end
	local count = playerCount()
	local factor = StatMath.enemyFactor(StatService.getTeamStat("enemyCount")) * DangerService.spawnMultiplier()
	for index, entry in groups do
		local size = SpawnRules.groupSize(entry, atMinutes, count) * factor
		groupTimers[index] -= dt
		if groupTimers[index] <= 0 then
			groupTimers[index] += entry.every
			groupOwed[index] = math.min(groupOwed[index] + size, size * Config.Run.spawn.maxOwedFirings)
		end
		if #anchors == 0 then
			groupOwed[index] = 0
			continue
		end
		local place = math.min(math.floor(groupOwed[index]), cap - EnemySim.getCount() - #queued)
		if place > 0 then
			groupOwed[index] -= queueGroup(anchors[pickIndex(#anchors)], entry.enemy, place)
		end
	end
end

local function update(dt: number)
	local atMinutes = minutes()
	local cap = SpawnRules.cap(playerCount())
	local anchors = aliveAnchors()
	updateEvents(atMinutes, anchors, cap)
	updateLoot(atMinutes, anchors)
	recycleTimer += dt
	if recycleTimer >= Config.Run.spawn.recycle.intervalSeconds and #anchors > 0 then
		recycleTimer = 0
		recycle(anchors, cap)
	end
	updateGroups(dt, atMinutes, anchors, cap)
	spawnQueued(atMinutes)
end

-- Lifecycle -------------------------------------------------------------------------

function SpawnDirector.init()
	RunDirector.RunStarted:Connect(function()
		activeGroups = nil
		table.clear(queued)
		paused = false
		lastMinutes = 0
		recycleTimer = 0
		plannedWave = 0
		table.clear(looters)
		table.clear(trees)
	end)
	RunDirector.WaveRetried:Connect(function()
		-- B11 part 2: the clock went back to the start of the wave; its trees and Looters are planned again
		activeGroups = nil
		table.clear(queued)
		lastMinutes = minutes()
		recycleTimer = 0
		plannedWave = 0
		table.clear(looters)
		table.clear(trees)
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		if RunDirector.getPhase() == "Running" then
			if not paused then
				update(dt)
			end
			escapeLooters()
		else
			activeGroups = nil -- the next wave starts its groups afresh
			table.clear(queued)
		end
	end)
end

-- Commands --------------------------------------------------------------------------

-- While paused nothing spawns, also no elites or Swarm Rush (their times passing meanwhile are skipped).
function SpawnDirector.setPaused(value: boolean)
	paused = value
	activeGroups = nil
	table.clear(queued)
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
	local mix = SpawnRules.mixAt(atMinutes, DangerService.getDanger())
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

-- Spawns a Looter near `around` (AdminService "SpawnLooter", B6). Returns true if one appeared.
function SpawnDirector.spawnLooter(around: Vector3): boolean
	return spawnLooter({ position = around, velocity = Vector3.zero }, minutes()) ~= nil
end

-- Spawns one `enemyId` with this wave's growth on the spawn ring around `around` (AdminService "SpawnNewEnemy",
-- B9). Returns true if it appeared.
function SpawnDirector.spawnEnemy(enemyId: string, around: Vector3): boolean
	return spawnOne({ position = around, velocity = Vector3.zero }, enemyId, minutes())
end

-- Spawns one `enemyId` at x/z with this wave's growth, the difficulty and the team's enemy stats (BossService: what
-- champions summon, WP10 part 2). Returns its id, or nil at the hard cap.
function SpawnDirector.spawnAt(enemyId: string, x: number, z: number): number?
	return spawnAt(enemyId, x, z, minutes())
end

-- Spawns a Tree close to `around` (AdminService "SpawnTree", B6). Returns true if one appeared.
function SpawnDirector.spawnTree(around: Vector3): boolean
	return spawnTree({}, minutes(), around) ~= nil
end

-- Queries ---------------------------------------------------------------------------

-- Alive cap for the current player count.
function SpawnDirector.getCap(): number
	return SpawnRules.cap(playerCount())
end

-- Enemies per second right now from the spawn groups (0 while paused or outside the Running phase).
function SpawnDirector.getRate(): number
	if paused or RunDirector.getPhase() ~= "Running" then
		return 0
	end
	return SpawnRules.currentRate(minutes(), playerCount(), DangerService.getDanger())
		* StatMath.enemyFactor(StatService.getTeamStat("enemyCount"))
		* DangerService.spawnMultiplier()
end

-- True while a Swarm Rush is running.
function SpawnDirector.isSwarmRush(): boolean
	return RunDirector.getPhase() == "Running" and SpawnRules.isSwarmRush(minutes())
end

return SpawnDirector
