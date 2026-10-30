--!strict
-- Runs the enemy World (EnemySim/World) at Config.Simulation.tickRate while a run is active and sends a
-- snapshot of every tick to the run's participants (Net/Snapshot). SpawnDirector spawns, WeaponService and
-- AdminService query, damage and push. Spitter shots (WP9) fly in EnemySim/Volleys and go to the participants as
-- EnemyShots. Splitters fall apart into smaller enemies when killed and Summoning elites call enemies around
-- themselves (both keep the parent's minute and difficulty multipliers). Signals: EnemyKilled for XP and loot (WP6,
-- WP9), Contact and ShotHit for player damage (WP4, WP9), Stepped for the weapons (WP5). Enemies and shots are
-- cleared when a run starts and ends and when a wave ends (Shop phase). Since B5 weapons also slow enemies and mark
-- them as burning (slow, setBurning); both travel in the snapshot's status byte. Since B6 SpawnDirector removes
-- escaping Looters without a kill (remove).

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
local RandomService = require(script.Parent.RandomService)
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
local KILL_ALL_PASSES = 4 -- killAll repeats for what killed enemies fall apart into

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

-- Spawns `count` enemies of `enemyId` evenly around (x, z) at `spread` studs with the given multipliers (World step
-- 4 pushes them out of obstacles). They may go above the alive cap, up to the hard cap.
local function spawnAround(
	enemyId: string,
	x: number,
	z: number,
	count: number,
	spread: number,
	hpMultiplier: number,
	damageMultiplier: number,
	speedMultiplier: number
)
	local turn = RandomService.number("Spawns") * 2 * math.pi
	for k = 1, count do
		local angle = turn + (k - 1) / count * 2 * math.pi
		EnemySim.spawn(
			enemyId,
			x + math.cos(angle) * spread,
			z + math.sin(angle) * spread,
			hpMultiplier,
			damageMultiplier,
			nil,
			nil,
			speedMultiplier
		)
	end
end

-- Summoners the last step reported call their enemies around themselves.
local function callSummons()
	local summons = world.summons
	for s = 1, world.summonCount do
		local id = summons[s]
		local kind = world:getKind(id)
		local summon = kind and kind.summon
		local x, z = world:getPosition(id)
		if kind and summon and x and z then
			local hpMultiplier, damageMultiplier, speedMultiplier = world:getMultipliers(id)
			spawnAround(
				summon.enemy,
				x,
				z,
				summon.count,
				kind.radius + 2,
				hpMultiplier,
				damageMultiplier,
				speedMultiplier
			)
		end
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
	callSummons()
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
	local kinds, modes, rushXs, rushZs = world.kinds, world.modes, world.rushXs, world.rushZs
	local slowFactors, burning = world.slowFactors, world.burning
	for i = 1, world.count do
		if hp[i] > 0 then
			count += 1
			columns.ids[count] = ids[i]
			columns.xs[count] = xs[i]
			columns.zs[count] = zs[i]
			columns.typeIds[count] = typeIds[i]
			columns.hpFractions[count] = hp[i] / maxHp[i]
			local charging = modes[i] ~= 0 -- the rush direction is fixed from the wind-up on
			columns.flags[count] = Snapshot.packFlags(
				modes[i],
				kinds[i].affix or 0,
				if charging then rushXs[i] else nil,
				if charging then rushZs[i] else nil
			)
			columns.statuses[count] = (if burning[i] then Snapshot.STATUS_BURNING else 0)
				+ (if slowFactors[i] < 1 then Snapshot.STATUS_SLOWED else 0)
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
	local function clearAll()
		world:clear()
		volleys:clear()
		currentTick += 1
		sendSnapshot() -- one empty tick so clients drop their enemies right away
		firedShots, endedShots = {}, {}
		sendShots(true)
	end
	RunDirector.RunEnded:Connect(clearAll)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Shop" then
			clearAll() -- a wave ends: the enemies left fade away (Brotato direction, B1)
		end
	end)
	RunService.Heartbeat:Connect(onHeartbeat)
end

-- Commands --------------------------------------------------------------------------

-- Spawns an enemy of Config.Enemies.types[enemyId] (its Gloom Elite variant if `elite`, with `affix` an index into
-- Config.Enemies.elite.affixes; Util/EnemyKinds) at world x/z. HP, contact and projectile damage are the kind's
-- values times the multipliers (wave and difficulty, see SpawnDirector), its speed times `speedMultiplier` (the
-- team's Enemy Speed stat, B9; default 1). Returns the new id, or nil when the hard cap (Config.Run.spawn.cap.max)
-- is reached.
function EnemySim.spawn(
	enemyId: string,
	x: number,
	z: number,
	hpMultiplier: number,
	damageMultiplier: number,
	elite: boolean?,
	affix: number?,
	speedMultiplier: number?
): number?
	local kind = EnemyKinds.get(enemyId, elite, affix)
	assert(kind, `Unknown enemy {enemyId}`)
	local shotDamage = if kind.ranged then kind.ranged.projectileDamage * damageMultiplier else nil
	return world:spawn(
		kind,
		x,
		z,
		kind.hp * hpMultiplier,
		kind.contactDamage * damageMultiplier,
		shotDamage,
		speedMultiplier
	)
end

-- Deals damage to one enemy. Returns true if this hit killed it (and fires EnemyKilled), the HP it took and the
-- damage after the enemy's own damageTaken multiplier (for damage numbers). A killed Splitter falls apart.
function EnemySim.damage(id: number, amount: number, source: Player?): (boolean, number, number)
	local killed, dealt, applied = world:damage(id, amount)
	if not killed then
		return false, dealt, applied
	end
	local kind = world:getKind(id)
	local x, z = world:getPosition(id)
	if kind and x and z then
		local split = kind.split
		if split then
			local hpMultiplier, damageMultiplier, speedMultiplier = world:getMultipliers(id)
			spawnAround(split.enemy, x, z, split.count, split.spread, hpMultiplier, damageMultiplier, speedMultiplier)
		end
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
	return true, dealt, applied
end

-- Pushes a living enemy along the floor by `offset` (x/z), less the more it resists knockback (World.push).
function EnemySim.push(id: number, offset: Vector3)
	world:push(id, offset.X, offset.Z)
end

-- Slows a living enemy to `factor` of its speed for `seconds`; the stronger slow wins (B5, World.slow).
function EnemySim.slow(id: number, factor: number, seconds: number)
	world:slow(id, factor, seconds)
end

-- Shows a living enemy as burning (or not) in the snapshots; WeaponService runs the burn itself (B5).
function EnemySim.setBurning(id: number, on: boolean)
	world:setBurning(id, on)
end

-- Removes a living enemy without a kill: no EnemyKilled, no loot (a Looter escaping, B6). Returns true if it was alive.
function EnemySim.remove(id: number): boolean
	return world:remove(id)
end

-- Moves a living enemy to `position` (x/z) at once, without crossing the space in between.
function EnemySim.teleport(id: number, position: Vector3)
	world:teleport(id, position.X, position.Z)
end

-- Kills every enemy (fires EnemyKilled for each), also what Splitters fall apart into. Returns how many died.
function EnemySim.killAll(source: Player?): number
	local killed = 0
	local ids: { number } = {}
	for _ = 1, KILL_ALL_PASSES do
		local count = EnemySim.collectIds(ids)
		if count == 0 then
			break
		end
		for i = 1, count do
			if EnemySim.damage(ids[i], math.huge, source) then
				killed += 1
			end
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

-- Mode of a living enemy (EnemySim/World.MODE_*: walk, wind-up, rush, recover) and its rush direction x/z.
function EnemySim.getMode(id: number): (number, number, number)
	return world:getMode(id)
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

-- Current HP of an enemy, 0 for dead or unknown ids (item effects since B8: damage by a share of the enemy's HP).
function EnemySim.getHealth(id: number): number
	return (world:getHealth(id))
end

-- Number of living enemies.
function EnemySim.getCount(): number
	return world:getAliveCount()
end

function EnemySim.getStats(): Stats
	return stats
end

return EnemySim
