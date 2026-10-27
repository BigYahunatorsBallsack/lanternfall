--!strict
-- Runs the enemy World (EnemySim/World) at Config.Simulation.tickRate while a run is active and sends a
-- snapshot of every tick to the run's participants (Net/Snapshot). SpawnDirector spawns, WeaponService and
-- AdminService query, damage and push. Spitter shots (WP9) fly in EnemySim/Volleys and go to the participants as
-- EnemyShots. Signals: EnemyKilled for XP and loot (WP6, WP9), Contact and ShotHit for player damage (WP4, WP9),
-- Stepped for the weapons (WP5). Enemies and shots are cleared when a run starts and ends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local EnemyKinds = require(Shared.Util.EnemyKinds)
local Snapshot = require(Shared.Net.Snapshot)
local Types = require(Shared.Net.Types)

local MapService = require(script.Parent.MapService)
local RunDirector = require(script.Parent.RunDirector)
local Volleys = require(script.Volleys)
local World = require(script.World)

export type KillInfo = {
	id: number,
	enemyId: string, -- key in Config.Enemies.types
	typeId: number,
	position: Vector3, -- on the arena floor
	xp: number,
	elite: boolean, -- a Gloom Elite: drops a chest (LootService)
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
-- (player: Player, damage: number): an enemy projectile hit the player. Hit protection is up to the listener.
EnemySim.ShotHit = Signal.new()
-- (dt: number, now: number): right after every step and still inside its measured time. WeaponService steps the
-- weapons here, so hits see this step's positions and the snapshot that follows already shows them.
EnemySim.Stepped = Signal.new()

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
local volleys = (function()
	local bounds = MapService.getArenaBounds()
	local center, half = bounds.center, bounds.halfSize
	return Volleys.new({
		playerRadius = Sim.playerRadius,
		minX = center.X - half,
		maxX = center.X + half,
		minZ = center.Z - half,
		maxZ = center.Z + half,
		obstacles = MapService.getObstacles(),
	})
end)()
local floorY = Config.Map.arena.center.Y
local currentTick = 0
local accumulator = 0

-- Living participants with a character, refreshed every step (reused arrays).
local targetPlayers: { Player } = {}
local targetIndexOf: { [Player]: number } = {}
local targetXs: { number } = {}
local targetZs: { number } = {}
local targetCount = 0
-- Where contacts are checked: the target moved ahead along its velocity (see Config.Simulation).
local contactXs: { number } = {}
local contactZs: { number } = {}
-- Floor velocity of each target, for aiming shots ahead of them.
local targetVxs: { number } = {}
local targetVzs: { number } = {}

-- Shot events since the last send (EnemyShots).
local firedShots: { Types.EnemyShot } = {}
local endedShots: { number } = {}

local columns = Snapshot.newColumns()

local stats: Stats = { stepMilliseconds = 0, stepMaxMilliseconds = 0, stepsPerSecond = 0, sentKilobytesPerSecond = 0 }
local window = { startedAt = os.clock(), steps = 0, seconds = 0, maxSeconds = 0, bytes = 0 }

local function pingOf(player: Player): number
	local ok, ping = pcall(player.GetNetworkPing, player)
	return if ok and typeof(ping) == "number" then math.clamp(ping, 0, Sim.contactLeadMaxPing) else 0
end

local function collectTargets()
	targetCount = 0
	table.clear(targetIndexOf)
	for _, player in RunDirector.getParticipants() do
		if RunDirector.getParticipantState(player) == "Alive" then
			local position = MapService.getRootPosition(player)
			if position then
				targetCount += 1
				targetPlayers[targetCount] = player
				targetIndexOf[player] = targetCount
				targetXs[targetCount] = position.X
				targetZs[targetCount] = position.Z
				local velocity = MapService.getRootVelocity(player)
				targetVxs[targetCount] = velocity.X
				targetVzs[targetCount] = velocity.Z
				local lead = velocity * (Sim.contactLeadSeconds + pingOf(player))
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

-- Turns the shots World reported this step into projectiles aimed ahead of their target: at the point a target
-- walking straight on would reach while the shot flies there, times the kind's aimLead.
local function fireShots(stepNow: number)
	local shots = world.shots
	for s = 0, world.shotCount - 1 do
		local k = s * 5
		local kind = world:getKind(shots[k + 1])
		local ranged = kind and kind.ranged
		if not (kind and ranged) then
			continue
		end
		local x, z, t, damage = shots[k + 2], shots[k + 3], shots[k + 4], shots[k + 5]
		local aimX, aimZ = contactXs[t], contactZs[t]
		local flightSeconds = math.sqrt((aimX - x) ^ 2 + (aimZ - z) ^ 2) / ranged.projectileSpeed
		aimX += targetVxs[t] * flightSeconds * ranged.aimLead
		aimZ += targetVzs[t] * flightSeconds * ranged.aimLead
		local dx, dz = aimX - x, aimZ - z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance < 1e-3 then
			continue
		end
		dx, dz = dx / distance, dz / distance
		local startX, startZ = x + dx * kind.radius, z + dz * kind.radius
		local id = volleys:fire(
			startX,
			startZ,
			dx,
			dz,
			ranged.projectileSpeed,
			ranged.projectileRange,
			ranged.projectileRadius,
			damage
		)
		table.insert(firedShots, {
			id = id,
			x = startX,
			z = startZ,
			dx = dx,
			dz = dz,
			speed = ranged.projectileSpeed,
			range = ranged.projectileRange,
			at = stepNow,
		})
	end
end

local function stepOnce()
	local startedAt = os.clock()
	collectTargets()
	local contacts = world:step(STEP_SECONDS, targetXs, targetZs, targetCount, contactXs, contactZs)
	currentTick += 1
	local stepNow = workspace:GetServerTimeNow()
	volleys:step(STEP_SECONDS, contactXs, contactZs, targetCount)
	local ended = volleys.ended
	for k = 1, volleys.endedCount * 2 do
		table.insert(endedShots, ended[k])
	end
	fireShots(stepNow)
	EnemySim.Stepped:Fire(STEP_SECONDS, stepNow)
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
	local hits = volleys.hits
	for k = 1, volleys.hitCount * 2, 2 do
		local player = targetPlayers[hits[k]]
		if player then
			EnemySim.ShotHit:Fire(player, hits[k + 1])
		end
	end
end

-- Sends the shot events since the last send to every participant (nothing when there are none).
local function sendShots(reset: boolean?)
	if not reset and #firedShots == 0 and #endedShots == 0 then
		return
	end
	local payload: Types.EnemyShotEvents = { reset = reset, fired = firedShots, ended = endedShots }
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("EnemyShots", player, payload)
	end
	firedShots = {}
	endedShots = {}
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
		sendShots()
	end
end

-- Lifecycle -------------------------------------------------------------------------

function EnemySim.init()
	RunDirector.RunStarted:Connect(function()
		world:clear()
		volleys:clear()
		accumulator = 0
		firedShots, endedShots = {}, {}
		sendShots(true)
	end)
	RunDirector.RunEnded:Connect(function()
		world:clear()
		volleys:clear()
		currentTick += 1
		sendSnapshot() -- one empty tick so clients drop their enemies right away
		firedShots, endedShots = {}, {}
		sendShots(true)
	end)
	RunService.Heartbeat:Connect(onHeartbeat)
end

-- Commands --------------------------------------------------------------------------

-- Spawns an enemy of Config.Enemies.types[enemyId] (its Gloom Elite variant if `elite`, Util/EnemyKinds) at world
-- x/z. HP, contact and projectile damage are the kind's values times the multipliers (minute and difficulty, see
-- SpawnDirector). Returns the new id, or nil when the hard cap (Config.Run.spawn.cap.max) is reached.
function EnemySim.spawn(
	enemyId: string,
	x: number,
	z: number,
	hpMultiplier: number,
	damageMultiplier: number,
	elite: boolean?
): number?
	local kind = EnemyKinds.get(enemyId, elite)
	assert(kind, `Unknown enemy {enemyId}`)
	local shotDamage = if kind.ranged then kind.ranged.projectileDamage * damageMultiplier else nil
	return world:spawn(kind, x, z, kind.hp * hpMultiplier, kind.contactDamage * damageMultiplier, shotDamage)
end

-- Deals damage to one enemy. Returns true if this hit killed it (and fires EnemyKilled), and the HP it took.
function EnemySim.damage(id: number, amount: number, source: Player?): (boolean, number)
	local killed, dealt = world:damage(id, amount)
	if not killed then
		return false, dealt
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
			elite = kind.elite == true,
			killer = source,
		} :: KillInfo)
	end
	return true, dealt
end

-- Pushes a living enemy along the floor by `offset` (x/z), less the heavier it is (knockback).
function EnemySim.push(id: number, offset: Vector3)
	world:push(id, offset.X, offset.Z)
end

-- Moves a living enemy to `position` (x/z) at once, without crossing the space in between.
function EnemySim.teleport(id: number, position: Vector3)
	world:teleport(id, position.X, position.Z)
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
-- out[1 .. n]; returns n. For area weapons.
function EnemySim.queryRadius(center: Vector3, radius: number, out: { number }): number
	return world:queryRadius(center.X, center.Z, radius, out)
end

-- Ids of living enemies whose body comes within `radius` of the line from `from` to `to` (x/z only), written
-- to out[1 .. n]; returns n. For projectiles and blades.
function EnemySim.querySegment(from: Vector3, to: Vector3, radius: number, out: { number }): number
	return world:querySegment(from.X, from.Z, to.X, to.Z, radius, out)
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

-- Where the last step saw a living participant: moved ahead along their velocity like for contacts (see
-- Config.Simulation), so about where they see themselves. nil for players who are not a living participant.
function EnemySim.getPlayerPosition(player: Player): Vector3?
	local index = targetIndexOf[player]
	if not index then
		return nil
	end
	return Vector3.new(contactXs[index], floorY, contactZs[index])
end

-- Enemy id (key in Config.Enemies.types) and whether it is an elite, nil for unknown ids.
function EnemySim.getKind(id: number): (string?, boolean)
	local kind = world:getKind(id)
	if not kind then
		return nil, false
	end
	return kind.id, kind.elite == true
end

function EnemySim.isAlive(id: number): boolean
	return world:isAlive(id)
end

-- Ids of every living enemy, written to out[1 .. n]; returns n.
function EnemySim.collectIds(out: { number }): number
	local count = 0
	local ids, hp = world.ids, world.hp
	for i = 1, world.count do
		if hp[i] > 0 then
			count += 1
			out[count] = ids[i]
		end
	end
	return count
end

-- Number of enemy projectiles in flight.
function EnemySim.getShotCount(): number
	return volleys:getCount()
end

-- Number of living enemies.
function EnemySim.getCount(): number
	return world:getAliveCount()
end

function EnemySim.getStats(): Stats
	return stats
end

return EnemySim
