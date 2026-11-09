--!strict
-- Spawns enemies while a run is in its Running phase (DESIGN.md section 7). Since 2026-11-09 it runs Brotato
-- 1.2.0.1's own spawn data (Config.EnemyWaves) with the rules of its wave manager and entity spawner
-- (SpawnRules): each wave starts its groups (its own, the every-wave Tree/Looter/Gobbler groups and, in horde waves,
-- the horde groups) and checks them once per whole second; a firing group first removes random regular enemies
-- above the enemy maximum (no loot; counted for Pacifist), picks its spot away from the players and puts every
-- enemy of its units, placed anywhere, in its area or at an arena edge, into a spawn queue. The queue lets one enemy
-- out every few frames; each shows a red cross (remote SpawnMarkers) for markerSeconds and then appears. Trees wait
-- in their own queue. HP and damage grow per wave and kind, the danger level, sliders, endless factor, co-op and
-- the team's enemy stats multiply them. Swarm Rush, the walking-direction spawn cone and teleporting stragglers
-- were own inventions and are gone (owner, 2026-11-09). Gloom Elites (Run.spawn.elites) stay off.
-- Uses EnemySim; BossService spawns what champions summon (spawnAt) and its bosses itself; AdminService pauses it
-- and spawns test waves, elites, Looters and Trees; CharacterService reads the enemies removed at the maximum.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local EnemyKinds = require(ReplicatedStorage.Shared.Util.EnemyKinds)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Net.Types)
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

local SPAWN_TRIES = 12 -- random ring points tried per debug enemy before giving up

local SpawnDirector = {}

-- One enemy waiting in a spawn queue, and later behind its red cross.
type Request = { enemyId: string, x: number, z: number, at: number, looter: boolean }

local paused = false
local timers: { SpawnRules.Timer } = {} -- the groups of the running wave
local timedWave = 0 -- the wave `timers` belong to (0 = none)
local nextSecond = 0 -- the next whole second of the wave its groups are checked at
local waveSeconds = 0 -- the groups' clock: the wave timer, but it keeps running while the debug button holds waves
local enemyQueue: { Request } = {} -- Brotato's queue_to_spawn (taken from the end)
local treeQueue: { Request } = {}
local queueClock = 0
local births: { Request } = {} -- enemies whose red cross is showing, in order of spawn time
local removedForPerformance = 0 -- regular enemies removed at the maximum this wave (Pacifist counts them)
local lastMinutes = 0 -- run time of the last update, to notice elite times passing
local looters: { [number]: number } = {} -- enemy id -> server time at which it escapes
local trees: { [number]: boolean } = {} -- enemy ids
local luresSeen: { [number]: number } = {} -- acquired copies already paid for with a special encounter
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

local function positions(anchors: { Anchor }): { Vector3 }
	local list = {}
	for _, anchor in anchors do
		table.insert(list, anchor.position)
	end
	return list
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
	local players = playerCount()
	local hpMultiplier = dangerHp
		* StatMath.enemyFactor(StatService.getTeamStat("enemyHp"))
		* SpawnRules.coopHealth(players)
	local damageMultiplier = dangerDamage
		* StatMath.enemyFactor(StatService.getTeamStat("enemyDamage"))
		* SpawnRules.coopDamage(players)
	local speedMultiplier = dangerSpeed * StatMath.enemyFactor(StatService.getTeamStat("enemySpeed"))
	return EnemySim.spawn(enemyId, x, z, hpMultiplier, damageMultiplier, elite, affix, speedMultiplier, wave)
end

-- Spawns one `enemyId` on the ring around `anchor` (debug spawns, item encounters). Returns false if no free spot
-- was found or the hard cap is reached.
local function spawnOne(anchor: Anchor, enemyId: string, atMinutes: number, elite: boolean?, affix: number?): boolean
	local kind = EnemyKinds.get(enemyId, elite, affix)
	if not kind then
		return false
	end
	local around = anchor.position
	local x, z = SpawnRules.findSpawnPoint(roll, around.X, around.Z, kind.radius, bounds, obstacles, SPAWN_TRIES)
	if not (x and z) then
		return false
	end
	return spawnAt(enemyId, x, z, atMinutes, elite, affix) ~= nil
end

-- One Gloom Elite of the current mix around a random living player, from Run.spawn.elites.affixFromMinute with a
-- random affix. Returns its name, or nil without a spot.
local function spawnElite(anchor: Anchor, atMinutes: number): string?
	local mix = SpawnRules.mixAt(atMinutes, DangerService.getDanger())
	if next(mix) == nil then
		return nil
	end
	local enemyId = SpawnRules.pickEnemy(mix, roll())
	local affix = if SpawnRules.affixesAt(atMinutes) then pickIndex(#Config.Enemies.elite.affixes) else nil
	if not spawnOne(anchor, enemyId, atMinutes, true, affix) then
		return nil
	end
	local kind = EnemyKinds.get(enemyId, true, affix)
	return if kind then kind.displayName else enemyId
end

-- Gloom Elites whose time passed since the last update (off on every danger level since B11).
local function updateEvents(atMinutes: number, anchors: { Anchor })
	local from = lastMinutes
	lastMinutes = atMinutes
	if #anchors == 0 then
		return
	end
	local gloom = DangerRules.level(DangerService.getDanger()).gloomElites
	for _ = 1, if gloom then SpawnRules.elitesDue(from, atMinutes) else 0 do
		local name = spawnElite(anchors[pickIndex(#anchors)], atMinutes)
		if name then
			notifyParticipants(`A {name} appeared! Kill it for a chest.`)
		end
	end
end

-- Looters and trees -------------------------------------------------------------------

-- A Looter at x/z that escapes after Config.Loot.looter.lifetimeSeconds. Returns its id.
local function spawnLooterAt(x: number, z: number, atMinutes: number): number?
	local id = spawnAt(Config.Loot.looter.enemy, x, z, atMinutes)
	if id then
		looters[id] = workspace:GetServerTimeNow() + Config.Loot.looter.lifetimeSeconds
	end
	return id
end

-- A Looter at Config.Loot.looter.spawnDistance from `anchor` (debug). Returns its id, or nil without a free spot.
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
			return spawnLooterAt(x, z, atMinutes)
		end
	end
	return nil
end

-- A Tree at x/z. Returns its id.
local function spawnTreeAt(x: number, z: number, atMinutes: number): number?
	local id = spawnAt(Config.Loot.trees.enemy, x, z, atMinutes)
	if id then
		trees[id] = true
	end
	return id
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

-- Brotato's spawn groups ---------------------------------------------------------------

local function isRegular(id: number): boolean
	local enemyId = EnemySim.getKind(id)
	local kind = enemyId and EnemyKinds.get(enemyId)
	return kind ~= nil and not kind.boss and not trees[id] and enemyId ~= Config.Loot.trees.enemy
end

-- Brotato removes random regular enemies (not bosses, champions or trees) without loot while more than the
-- maximum are alive when a group fires.
local function enforceMaximum(wave: number)
	local ids: { number } = {}
	local count = EnemySim.collectIds(ids)
	local regular: { number } = {}
	for i = 1, count do
		if isRegular(ids[i]) then
			table.insert(regular, ids[i])
		end
	end
	local excess = #regular - SpawnRules.cap(playerCount(), wave)
	for _ = 1, excess do
		local index = pickIndex(#regular)
		local id = regular[index]
		regular[index] = regular[#regular]
		regular[#regular] = nil
		looters[id] = nil
		if EnemySim.remove(id) then
			removedForPerformance += 1
		end
	end
end

-- A firing group: the maximum, the group's spot, then every enemy of its units into the queues.
local function fireGroup(group: SpawnRules.Group, wave: number, anchors: { Anchor })
	enforceMaximum(wave)
	local players = positions(anchors)
	local gx, gz = SpawnRules.groupPoint(roll, bounds, group, players)
	local count = playerCount()
	local enemiesStat = StatService.getTeamStat("enemyCount")
	local treesStat = StatService.getTeamStat("trees")
	local countShare = DangerService.spawnMultiplier()
	for _, unit in group.units do
		local enemyId = unit.enemy
		if not enemyId then
			continue
		end
		local kind = EnemyKinds.get(enemyId)
		if not kind then
			continue
		end
		local number = SpawnRules.unitCount(unit, group, count, enemiesStat, treesStat, countShare, roll(), roll())
		for _ = 1, number do
			local x, z = SpawnRules.enemyPoint(roll, bounds, group, unit, gx, gz, players)
			x, z = SpawnRules.settle(x, z, kind.radius, bounds, obstacles)
			local request = { enemyId = enemyId, x = x, z = z, at = 0, looter = group.loot }
			table.insert(if unit.neutral then treeQueue else enemyQueue, request)
		end
	end
end

-- The bait encounter of a lure item (Brotato's group_bait: 7-8 Lampreys 2 s into the next wave, anywhere).
local function lureGroup(count: number): SpawnRules.Group
	local lure = Config.Effects.lure
	return table.freeze({
		timing = lure.timing,
		repeating = -1,
		interval = 3,
		reduceInterval = 0,
		minInterval = 1,
		area = -1,
		edgeMargin = 0,
		edge = false,
		chance = 1,
		loot = false,
		neutral = false,
		boss = false,
		preventIfElite = false,
		preventIfHorde = false,
		minDanger = 0,
		maxDanger = math.huge,
		minWave = 0,
		maxWave = math.huge,
		units = table.freeze({
			table.freeze({
				enemy = lure.enemy,
				min = count,
				max = count,
				chance = 1,
				neutral = false,
				extraDistance = 0,
			}),
		}),
	}) :: any
end

-- The groups of `wave`: Brotato's data for its danger, horde and elite flags, plus one bait group per newly bought
-- lure copy.
local function startWave(wave: number)
	timedWave = wave
	nextSecond = 0
	waveSeconds = 0
	removedForPerformance = 0
	table.clear(looters)
	table.clear(trees)
	local challenge = DangerService.getChallenge(wave)
	local horde = challenge ~= nil and challenge.kind == "Horde"
	local elite = challenge ~= nil and challenge.kind == "Elite"
	local groups = SpawnRules.groupsFor(wave, DangerService.getDanger(), horde, elite)
	local lure = Config.Effects.lure
	for _, player in RunDirector.getParticipants() do
		local copies = 0
		for _, entry in StatService.getItems(player) do
			if entry.id == lure.item then
				copies = entry.count
			end
		end
		for _ = 1, math.max(0, copies - (luresSeen[player.UserId] or 0)) do
			local count = lure.minCount + math.floor(roll() * (lure.maxCount - lure.minCount + 1))
			table.insert(groups, lureGroup(count))
		end
		luresSeen[player.UserId] = copies
	end
	timers = SpawnRules.newTimers(groups)
end

-- Checks the wave's groups at every whole second passed (Brotato's wave manager).
local function updateGroups(anchors: { Anchor }, dt: number)
	local wave = RunDirector.getWave()
	if wave ~= timedWave then
		startWave(wave)
	end
	local schedule = RunSchedule.wave(wave)
	waveSeconds = math.max(waveSeconds + dt, RunDirector.getElapsed() - schedule.startsAt) -- skips jump ahead
	local seconds = waveSeconds
	while nextSecond <= seconds do
		local firing = SpawnRules.due(timers, nextSecond, roll)
		nextSecond += 1
		if #anchors == 0 then
			continue
		end
		for _, group in firing do
			fireGroup(group, wave, anchors)
		end
	end
end

-- Lets queued enemies out (Brotato: one every few frames, more while the queue is long; trees one per step too) and
-- shows their red crosses in one message per update.
local function updateQueues(dt: number)
	local settings = Config.Run.spawn
	queueClock += dt
	local points: { number } = {}
	local at = workspace:GetServerTimeNow() + settings.markerSeconds
	while queueClock >= settings.queue.secondsPerSpawn do
		queueClock -= settings.queue.secondsPerSpawn
		local tree = table.remove(treeQueue)
		if tree then
			tree.at = at
			table.insert(births, tree)
		end
		for _ = 1, SpawnRules.queueBurst(#enemyQueue) do
			local request = table.remove(enemyQueue)
			if not request then
				break
			end
			request.at = at
			table.insert(births, request)
			table.insert(points, request.x)
			table.insert(points, request.z)
		end
	end
	if #points > 0 then
		local markers: Types.SpawnMarkers = { points = points, spawnsAt = at }
		for _, player in RunDirector.getParticipants() do
			Net.fireClient("SpawnMarkers", player, markers)
		end
	end
end

-- Spawns the enemies whose red crosses ran out.
local function updateBirths(atMinutes: number)
	local now = workspace:GetServerTimeNow()
	while births[1] and births[1].at <= now do
		local request = table.remove(births, 1) :: Request
		if request.enemyId == Config.Loot.trees.enemy then
			spawnTreeAt(request.x, request.z, atMinutes)
		elseif request.looter then
			spawnLooterAt(request.x, request.z, atMinutes)
		else
			spawnAt(request.enemyId, request.x, request.z, atMinutes)
		end
	end
end

local function clearQueues()
	table.clear(enemyQueue)
	table.clear(treeQueue)
	table.clear(births)
	queueClock = 0
end

local function update(dt: number)
	local atMinutes = minutes()
	local anchors = aliveAnchors()
	updateEvents(atMinutes, anchors)
	updateGroups(anchors, dt)
	updateQueues(dt)
	updateBirths(atMinutes)
end

-- Lifecycle -------------------------------------------------------------------------

function SpawnDirector.init()
	RunDirector.addCheckpoint("EnemyEncounters", function()
		return table.clone(luresSeen)
	end, function(saved: { [number]: number })
		luresSeen = table.clone(saved)
	end)
	RunDirector.RunStarted:Connect(function()
		table.clear(luresSeen)
		timedWave = 0
		clearQueues()
		paused = false
		lastMinutes = 0
		table.clear(looters)
		table.clear(trees)
	end)
	RunDirector.WaveRetried:Connect(function()
		-- B11 part 2: the clock went back to the start of the wave; its groups start again
		timedWave = 0
		clearQueues()
		lastMinutes = minutes()
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
			timedWave = 0 -- the next wave starts its groups afresh
			clearQueues()
		end
	end)
end

-- Commands --------------------------------------------------------------------------

-- While paused nothing spawns, also no elites (their times passing meanwhile are skipped); unpausing restarts the
-- wave's groups from the current second.
function SpawnDirector.setPaused(value: boolean)
	paused = value
	clearQueues()
	lastMinutes = minutes()
	if not value and RunDirector.getPhase() == "Running" then
		local wave = RunDirector.getWave()
		if wave ~= timedWave then
			startWave(wave) -- a wave that began while paused (a running one keeps its timers and paid lures)
		end
		waveSeconds = math.max(0, RunDirector.getElapsed() - RunSchedule.wave(wave).startsAt)
		nextSecond = math.ceil(waveSeconds)
		SpawnRules.due(timers, nextSecond - 1, function()
			return 1 -- groups whose first time passed while paused stay quiet; their repeats go on
		end)
	end
end

function SpawnDirector.isPaused(): boolean
	return paused
end

-- Spawns up to `count` enemies of the current mix around `around`, stopping at the enemy maximum
-- (AdminService "SpawnWave"). Returns how many spawned.
function SpawnDirector.spawnWave(around: Vector3, count: number): number
	local atMinutes = minutes()
	local cap = SpawnRules.cap(playerCount(), SpawnRules.runWave(atMinutes))
	local mix = SpawnRules.mixAt(atMinutes, DangerService.getDanger())
	if next(mix) == nil then
		return 0
	end
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

-- Spawns one `enemyId` at x/z with this wave's growth, the difficulty, co-op and the team's enemy stats
-- (BossService: what champions summon, WP10 part 2). Returns its id, or nil at the hard cap.
function SpawnDirector.spawnAt(enemyId: string, x: number, z: number): number?
	return spawnAt(enemyId, x, z, minutes())
end

-- Spawns a Tree close to `around` (AdminService "SpawnTree", B6). Returns true if one appeared.
function SpawnDirector.spawnTree(around: Vector3): boolean
	local kind = EnemyKinds.get(Config.Loot.trees.enemy)
	if not kind then
		return false
	end
	for _ = 1, SPAWN_TRIES do
		local angle = roll() * 2 * math.pi
		local x, z = around.X + math.cos(angle) * 12, around.Z + math.sin(angle) * 12
		if SpawnRules.isFree(x, z, kind.radius, bounds, obstacles) then
			return spawnTreeAt(x, z, minutes()) ~= nil
		end
	end
	return false
end

-- Queries ---------------------------------------------------------------------------

-- Enemy maximum for the current player count and wave.
function SpawnDirector.getCap(): number
	return SpawnRules.cap(playerCount(), RunDirector.getWave())
end

-- Regular enemies removed at the enemy maximum in the current wave (Brotato's enemies_removed_for_perf).
function SpawnDirector.getRemovedForPerformance(): number
	return removedForPerformance
end

-- Enemies waiting in the spawn queues or behind their red crosses.
function SpawnDirector.getQueued(): number
	return #enemyQueue + #treeQueue + #births
end

return SpawnDirector
