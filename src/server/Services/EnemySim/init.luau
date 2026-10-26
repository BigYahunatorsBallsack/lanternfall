--!strict
-- Runs the enemy World (EnemySim/World) at Config.Simulation.tickRate while a run is active and sends a
-- snapshot of every tick to the run's participants (Net/Snapshot). SpawnDirector spawns, weapons (WP5) and
-- AdminService query and damage. Signals: EnemyKilled for XP and loot (WP6, WP9), Contact for player
-- damage (WP4). Enemies are cleared when a run starts and ends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Snapshot = require(Shared.Net.Snapshot)

local MapService = require(script.Parent.MapService)
local RunDirector = require(script.Parent.RunDirector)
local World = require(script.World)

export type KillInfo = {
	id: number,
	enemyId: string, -- key in Config.Enemies.types
	typeId: number,
	position: Vector3, -- on the arena floor
	xp: number,
	killer: Player?,
}

export type Stats = {
	stepMilliseconds: number, -- average over the last second
	stepMaxMilliseconds: number,
	stepsPerSecond: number,
	sentKilobytesPerSecond: number, -- per participant
}

local Sim = Config.Simulation
local STEP_SECONDS = 1 / Sim.tickRate
local STATS_WINDOW_SECONDS = 1

local EnemySim = {}

-- (info: KillInfo)
EnemySim.EnemyKilled = Signal.new()
-- (player: Player, damage: number): an enemy touches the player; at most once per step and player,
-- with the highest contact damage among the enemies touching them. Hit protection is up to the listener.
EnemySim.Contact = Signal.new()

local function newWorld(): World.World
	local bounds = MapService.getArenaBounds()
	local center, half = bounds.center, bounds.halfSize
	return World.new({
		cellSize = Sim.spatialHashCellSize,
		maxEnemies = Config.Run.spawn.cap.max,
		playerRadius = Sim.playerRadius,
		contactMargin = Sim.contactMargin,
		separationStiffness = Sim.separationStiffness,
		separationPasses = Sim.separationPasses,
		obstacleSteerMargin = Sim.obstacleSteerMargin,
		keepDistanceTolerance = Sim.keepDistanceTolerance,
		minX = center.X - half,
		maxX = center.X + half,
		minZ = center.Z - half,
		maxZ = center.Z + half,
		obstacles = MapService.getObstacles(),
	})
end

local world = newWorld()
local floorY = Config.Map.arena.center.Y
local currentTick = 0
local accumulator = 0

-- Living participants with a character, refreshed every step (reused arrays).
local targetPlayers: { Player } = {}
local targetXs: { number } = {}
local targetZs: { number } = {}
local targetCount = 0
-- Where contacts are checked: the target moved ahead along its velocity (see Config.Simulation).
local contactXs: { number } = {}
local contactZs: { number } = {}

local columns = Snapshot.newColumns()

local stats: Stats = { stepMilliseconds = 0, stepMaxMilliseconds = 0, stepsPerSecond = 0, sentKilobytesPerSecond = 0 }
local window = { startedAt = os.clock(), steps = 0, seconds = 0, maxSeconds = 0, bytes = 0 }

local function pingOf(player: Player): number
	local ok, ping = pcall(player.GetNetworkPing, player)
	return if ok and typeof(ping) == "number" then math.clamp(ping, 0, Sim.contactLeadMaxPing) else 0
end

local function collectTargets()
	targetCount = 0
	for _, player in RunDirector.getParticipants() do
		if RunDirector.getParticipantState(player) == "Alive" then
			local position = MapService.getRootPosition(player)
			if position then
				targetCount += 1
				targetPlayers[targetCount] = player
				targetXs[targetCount] = position.X
				targetZs[targetCount] = position.Z
				local lead = MapService.getRootVelocity(player) * (Sim.contactLeadSeconds + pingOf(player))
				lead = Vector3.new(lead.X, 0, lead.Z)
				if lead.Magnitude > Sim.contactLeadMaxStuds then
					lead = lead.Unit * Sim.contactLeadMaxStuds
				end
				contactXs[targetCount] = position.X + lead.X
				contactZs[targetCount] = position.Z + lead.Z
			end
		end
	end
	for i = targetCount + 1, #targetPlayers do
		targetPlayers[i] = nil -- do not keep players who left
	end
end

local function stepOnce()
	local startedAt = os.clock()
	collectTargets()
	local contacts = world:step(STEP_SECONDS, targetXs, targetZs, targetCount, contactXs, contactZs)
	currentTick += 1
	local seconds = os.clock() - startedAt
	window.steps += 1
	window.seconds += seconds
	window.maxSeconds = math.max(window.maxSeconds, seconds)

	for t = 1, targetCount do
		local damage = contacts[t]
		if damage > 0 then
			EnemySim.Contact:Fire(targetPlayers[t], damage)
		end
	end
end

-- Sends the current enemies of `currentTick` to every participant still in the server.
local function sendSnapshot()
	local count = 0
	local ids, xs, zs, typeIds, hp, maxHp = world.ids, world.xs, world.zs, world.typeIds, world.hp, world.maxHp
	for i = 1, world.count do
		if hp[i] > 0 then
			count += 1
			columns.ids[count] = ids[i]
			columns.xs[count] = xs[i]
			columns.zs[count] = zs[i]
			columns.typeIds[count] = typeIds[i]
			columns.hpFractions[count] = hp[i] / maxHp[i]
		end
	end
	local packets = Snapshot.encode(currentTick, columns, count)
	for _, packet in packets do
		window.bytes += buffer.len(packet)
	end
	for _, player in RunDirector.getParticipants() do
		for _, packet in packets do
			Net.fireClient("EnemySnapshot", player, packet)
		end
	end
end

local function updateStats()
	local now = os.clock()
	local elapsed = now - window.startedAt
	if elapsed < STATS_WINDOW_SECONDS then
		return
	end
	stats = {
		stepMilliseconds = if window.steps > 0 then window.seconds * 1000 / window.steps else 0,
		stepMaxMilliseconds = window.maxSeconds * 1000,
		stepsPerSecond = window.steps / elapsed,
		sentKilobytesPerSecond = window.bytes / 1024 / elapsed,
	}
	window.startedAt = now
	window.steps = 0
	window.seconds = 0
	window.maxSeconds = 0
	window.bytes = 0
end

local function onHeartbeat(dt: number)
	updateStats()
	if not RunDirector.isActive() then
		accumulator = 0
		return
	end
	accumulator += dt
	local steps = 0
	while accumulator >= STEP_SECONDS and steps < Sim.maxCatchUpSteps do
		accumulator -= STEP_SECONDS
		steps += 1
		stepOnce()
	end
	if accumulator >= STEP_SECONDS then
		accumulator = 0 -- after a long hitch: skip the backlog instead of falling further behind
	end
	if steps > 0 then
		sendSnapshot()
	end
end

-- Lifecycle -------------------------------------------------------------------------

function EnemySim.init()
	RunDirector.RunStarted:Connect(function()
		world:clear()
		accumulator = 0
	end)
	RunDirector.RunEnded:Connect(function()
		world:clear()
		currentTick += 1
		sendSnapshot() -- one empty tick so clients drop their enemies right away
	end)
	RunService.Heartbeat:Connect(onHeartbeat)
end

-- Commands --------------------------------------------------------------------------

-- Spawns an enemy of Config.Enemies.types[enemyId] at world x/z. HP and contact damage are the config
-- values times the multipliers (minute and difficulty, see SpawnDirector). Returns the new id, or nil
-- when the hard cap (Config.Run.spawn.cap.max) is reached.
function EnemySim.spawn(enemyId: string, x: number, z: number, hpMultiplier: number, damageMultiplier: number): number?
	local kind = Config.Enemies.types[enemyId]
	assert(kind, `Unknown enemy {enemyId}`)
	return world:spawn(kind, x, z, kind.hp * hpMultiplier, kind.contactDamage * damageMultiplier)
end

-- Deals damage to one enemy. Returns true if this hit killed it (and fires EnemyKilled).
function EnemySim.damage(id: number, amount: number, source: Player?): boolean
	if not world:damage(id, amount) then
		return false
	end
	local kind = world:getKind(id)
	local x, z = world:getPosition(id)
	if kind and x and z then
		EnemySim.EnemyKilled:Fire({
			id = id,
			enemyId = kind.id,
			typeId = kind.typeId,
			position = Vector3.new(x, floorY, z),
			xp = kind.xp,
			killer = source,
		} :: KillInfo)
	end
	return true
end

-- Kills every enemy (fires EnemyKilled for each). Returns how many died.
function EnemySim.killAll(source: Player?): number
	local ids = table.clone(world.ids)
	local killed = 0
	for _, id in ids do
		if EnemySim.damage(id, math.huge, source) then
			killed += 1
		end
	end
	return killed
end

-- Queries ---------------------------------------------------------------------------

-- Ids of living enemies whose body overlaps the circle around `center` (x/z only), written to
-- out[1 .. n]; returns n. For area weapons (WP5).
function EnemySim.queryRadius(center: Vector3, radius: number, out: { number }): number
	return world:queryRadius(center.X, center.Z, radius, out)
end

-- Id of the living enemy closest to `position` within maxRange studs, and its distance.
function EnemySim.nearest(position: Vector3, maxRange: number?): (number?, number)
	return world:nearest(position.X, position.Z, maxRange)
end

-- Floor position of an enemy (also of one killed since the last step), nil for unknown ids.
function EnemySim.getPosition(id: number): Vector3?
	local x, z = world:getPosition(id)
	if not (x and z) then
		return nil
	end
	return Vector3.new(x, floorY, z)
end

function EnemySim.isAlive(id: number): boolean
	return world:isAlive(id)
end

-- Number of living enemies.
function EnemySim.getCount(): number
	return world:getAliveCount()
end

function EnemySim.getStats(): Stats
	return stats
end

return EnemySim
