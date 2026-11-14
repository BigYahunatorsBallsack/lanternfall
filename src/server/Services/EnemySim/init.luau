--!strict
-- Runs the enemy World (EnemySim/World) at Config.Simulation.tickRate while a run is active and sends a
-- snapshot of every tick to the run's participants (Net/Snapshot). SpawnDirector spawns, WeaponService and
-- AdminService query, damage and push. Spitter shots (WP9) fly in EnemySim/Volleys and go to the participants as
-- EnemyShots. Splitters fall apart into smaller enemies when killed and Summoning elites call enemies around
-- themselves (both keep the parent's minute and difficulty multipliers). Signals: EnemyKilled for XP and loot (WP6,
-- WP9), Contact and ShotHit for player damage (WP4, WP9), Stepped for the weapons (WP5). Enemies and shots are
-- cleared when a run starts and ends and when a wave ends (Shop phase). Since B5 weapons also slow enemies and mark
-- them as burning (slow, setBurning); both travel in the snapshot's status byte. Since B6 SpawnDirector removes
-- escaping Looters without a kill (remove). Since WP10 BossService steers bosses (setGoal, teleport, setSpeedFactor)
-- and fires their projectiles (fireShot); kills report whether a boss died.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local EnemyKinds = require(Shared.Util.EnemyKinds)
local EnemyStats = require(Shared.Util.EnemyStats)
local NativeSummons = require(script.NativeSummons)
local EntryHealing = require(script.NativeEntryHealing)
local MovementInput = require(script.Parent.CharacterService.Movement)
local NativeVolley = require(Shared.Util.NativeEnemyVolley)
local PlayerHurt = require(Shared.Util.PlayerHurtGeometry)
local ShotFeed = require(Shared.Net.ShotFeed)
local Snapshot = require(Shared.Net.Snapshot)
local Types = require(Shared.Net.Types)

local MapService = require(script.Parent.MapService)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local Volleys = require(script.Volleys)
local World = require(script.World)
local CharmedWorld = require(script.CharmedWorld)
local CharmRules = require(script.CharmRules)
local weakness = require(script.Weakness).new()

export type KillInfo = {
	id: number,
	enemyId: string, -- key in Config.Enemies.types
	typeId: number,
	position: Vector3, -- on the arena floor
	xp: number,
	elite: boolean, -- a Gloom Elite: drops a chest (LootService)
	boss: boolean, -- a boss (WP10, BossService)
	killer: Player?,
	aliveSeconds: number?, -- authoritative age of a credited death; native Giant Slayer boundary
	digCrateChance: number?, -- Shovel's killing hitbox; LootService rolls before ordinary consumables
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
-- (player: Player, damage: number, enemyId: number): an enemy touches the player; at most once per step and player,
-- with the highest contact damage among the enemies touching them (enemyId: that enemy, 0 for a rush or slash).
-- Hit protection is up to the listener, which calls EnemySim.contactRecoil(enemyId) when the touch landed.
EnemySim.Contact = Signal.new()
-- (player: Player, damage: number): an enemy projectile hit the player. Hit protection is up to the listener.
EnemySim.ShotHit = Signal.new()
-- (dt: number, now: number): right after every step and still inside its measured time. WeaponService steps the
-- weapons here, so hits see this step's positions and the snapshot that follows already shows them.
EnemySim.Stepped = Signal.new()
-- Server-only cosmetic events for friendly projectiles.
EnemySim.CharmShot = Signal.new()
-- Trusted source slash request: source id, target x/z, damage and optional Charm owner.
EnemySim.NativeSlash = Signal.new()
EnemySim.NativePillar = Signal.new()
-- Trusted native spawning attack: child kind, exact position and captured optional Charm owner; SpawnDirector owns births.
EnemySim.NativeSummon = Signal.new()
EnemySim.CharmSupport = Signal.new()

local world: World.World
local friends: any
local nativeBases: { [number]: any } = {}
local sharedSerial = 0
local function allocateActorId(): number
	repeat
		sharedSerial = sharedSerial % Snapshot.MAX_ID + 1
	until (not world or not world.indexOf[sharedSerial]) and (not friends or not friends.world.indexOf[sharedSerial])
	return sharedSerial
end
-- Living participants with a character, refreshed every step (reused arrays).
local targetPlayers: { Player } = {}
local function referencePlayerSpeed(index: number?, x: number?, z: number?): number?
	if index and targetPlayers[index] then
		return MovementInput.getSpeed(targetPlayers[index])
	end
	local fastest: number? = nil
	local nearest: number? = nil
	local bestSquared = math.huge
	for _, player in RunDirector.getParticipants() do
		if RunDirector.getParticipantState(player) == "Alive" then
			fastest = math.max(fastest or 0, MovementInput.getSpeed(player))
			local at = if x and z then MapService.getRootPosition(player) else nil
			if at and x and z then
				local squared = (at.X - x) ^ 2 + (at.Z - z) ^ 2
				if squared < bestSquared then
					bestSquared, nearest = squared, MovementInput.getSpeed(player)
				end
			end
		end
	end
	return nearest or fastest
end
local function actorObstacles(): { World.Circle }
	local obstacles: { World.Circle } = MapService.getObstacles()
	for _, shape in MapService.getNativeObstacleShapes() do
		table.insert(obstacles, shape)
	end
	return obstacles
end
local function newWorldParams(): World.Params
	local bounds = MapService.getArenaBounds()
	local center, halfX, halfZ = bounds.center, bounds.halfX, bounds.halfZ
	return {
		allocateId = allocateActorId,
		referencePlayerSpeed = referencePlayerSpeed,
		nativeChargeAccessibility = function()
			return RunDirector.getRunOptions().enemySpeed / 100
		end,
		cellSize = Sim.spatialHashCellSize,
		maxEnemies = Config.Run.spawn.cap.max,
		playerRadius = Sim.playerRadius,
		contactMargin = Sim.contactMargin,
		collideTargets = Sim.enemyPlayerBodyCollision,
		separationStiffness = Sim.separationStiffness,
		separationPasses = Sim.separationPasses,
		obstacleSteerMargin = Sim.obstacleSteerMargin,
		keepDistanceTolerance = Sim.keepDistanceTolerance,
		minX = center.X - halfX,
		maxX = center.X + halfX,
		minZ = center.Z - halfZ,
		maxZ = center.Z + halfZ,
		obstacles = actorObstacles(),
		forbiddenCircles = MapService.getForbiddenCircles(),
		seed = math.floor(RandomService.number("Combat") * 2147483646) + 1,
	}
end

world = World.new(newWorldParams())
type SpawnContext = { hp: number, damage: number, speed: number, wave: number }
local spawnContexts: { [number]: SpawnContext } = {}
local chargeTrails: { [number]: { x: number, z: number, distance: number } } = {}
local volleys = (function()
	local bounds = MapService.getArenaBounds()
	local center, halfX, halfZ = bounds.center, bounds.halfX, bounds.halfZ
	return Volleys.new({
		playerRadius = Sim.playerRadius,
		minX = center.X - halfX,
		maxX = center.X + halfX,
		minZ = center.Z - halfZ,
		maxZ = center.Z + halfZ,
		obstacles = MapService.getObstacles(),
	})
end)()
local floorY = Config.Map.arena.center.Y
friends = CharmedWorld.new(world.params, {
	nativeSpawn = function(member, actors, id)
		NativeSummons.emit(actors, id, member.kind.nativeSpawn, member.owner, function()
			return RandomService.number("Spawns")
		end, function(...)
			EnemySim.NativeSummon:Fire(...)
		end)
	end,

	support = function(member, x, z)
		local pulse = member.kind.pulse
		if pulse and pulse.nativeEnemyEntry then
			member.enemiesInside =
				EntryHealing.step(world, member.id, RunDirector.getWave(), x, z, pulse, member.enemiesInside)
			return
		end
		EnemySim.CharmSupport:Fire(member, x, z)
	end,
	damage = function(id, amount)
		EnemySim.damage(id, amount, nil)
	end,
	emitSlash = function(id, tx, tz, damage, owner)
		EnemySim.NativeSlash:Fire(id, tx, tz, damage, owner)
	end,
	emitPillar = function(id, x, z, dx, dz, speed, damage, owner)
		EnemySim.NativePillar:Fire(id, x, z, dx, dz, speed, damage, owner)
	end,
	emitShot = function(owner, event)
		EnemySim.CharmShot:Fire(owner, event)
	end,
	expired = function(member, x, z)
		EnemySim.resolveCharmDeath(member, x, z)
	end,
	spawn = function(member, kind, x, z, count, spread)
		EnemySim.spawnCharmChildren(member, kind, x, z, count, spread)
	end,
	random = function(owner)
		return RandomService.number("Combat", game:GetService("Players"):GetPlayerByUserId(owner))
	end,
}, MapService.getObstacles())

local currentTick = 0
local accumulator = 0

local targetIndexOf: { [Player]: number } = {}
local targetXs: { number } = {}
local targetZs: { number } = {}
local targetCount = 0
-- Compensated actor roots, also used by aiming. Damage circles are translated separately.
local contactXs: { number } = {}
local contactZs: { number } = {}
local hurtXs: { number } = {}
local hurtZs: { number } = {}
-- Floor velocity of each target, for aiming shots ahead of them.
local targetVxs: { number } = {}
local targetVzs: { number } = {}
local targetInputXs: { number } = {}
local targetInputZs: { number } = {}
local targetDirectionXs: { number } = {}
local targetDirectionZs: { number } = {}

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
				local direction = MovementInput.getDirection(player)
				local input = direction * MovementInput.getSpeed(player)
				targetInputXs[targetCount], targetInputZs[targetCount] = input.X, input.Z
				targetDirectionXs[targetCount], targetDirectionZs[targetCount] = direction.X, direction.Z
				local lead = velocity * (Sim.contactLeadSeconds + pingOf(player))
				lead = Vector3.new(lead.X, 0, lead.Z)
				if lead.Magnitude > Sim.contactLeadMaxStuds then
					lead = lead.Unit * Sim.contactLeadMaxStuds
				end
				contactXs[targetCount] = position.X + lead.X
				contactZs[targetCount] = position.Z + lead.Z
				hurtXs[targetCount], hurtZs[targetCount] =
					PlayerHurt.center(contactXs[targetCount], contactZs[targetCount])
			end
		end
	end
	for i = targetCount + 1, #targetPlayers do
		targetPlayers[i] = nil -- do not keep players who left
	end
end

-- Turns the shots World reported this step into projectiles aimed ahead of their target: at the point a target
-- walking straight on would reach while the shot flies there, times the kind's aimLead, then turned by a random
-- angle within the kind's spreadRadians.
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
		if ranged.nativeVolley then
			NativeVolley.emit(ranged.nativeVolley, x, z, targetXs[t], targetZs[t], ranged.projectileSpeed, function()
				return RandomService.number("Combat")
			end, function(px, pz, dx, dz, speed)
				if ranged.nativePillar then
					EnemySim.NativePillar:Fire(shots[k + 1], px, pz, dx, dz, speed, damage, nil)
				else
					EnemySim.fireShot(px, pz, dx, dz, speed, ranged.projectileRange, ranged.projectileRadius, damage)
				end
			end)
			continue
		end
		local aimX, aimZ = contactXs[t], contactZs[t]
		if ranged.nativeSlash then
			EnemySim.NativeSlash:Fire(shots[k + 1], aimX, aimZ, damage, nil)
			continue
		end
		local flightSeconds = math.sqrt((aimX - x) ^ 2 + (aimZ - z) ^ 2) / ranged.projectileSpeed
		aimX += targetVxs[t] * flightSeconds * ranged.aimLead
		aimZ += targetVzs[t] * flightSeconds * ranged.aimLead
		local dx, dz = aimX - x, aimZ - z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance < 1e-3 then
			continue
		end
		dx, dz = dx / distance, dz / distance
		local spread = ranged.spreadRadians or 0
		if spread > 0 then
			local turn = (RandomService.number("Combat") * 2 - 1) * spread
			local c, s = math.cos(turn), math.sin(turn)
			dx, dz = dx * c - dz * s, dx * s + dz * c
		end
		local startX, startZ =
			if ranged.fromCenter then x else x + dx * kind.radius, if ranged.fromCenter then z else z + dz * kind.radius
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
	speedMultiplier: number,
	parentId: number?,
	area: number?
)
	local context = if parentId then spawnContexts[parentId] else nil
	local turn = RandomService.number("Spawns") * 2 * math.pi
	for k = 1, count do
		local angle = turn + (k - 1) / count * 2 * math.pi
		local sx, sz = x + math.cos(angle) * spread, z + math.sin(angle) * spread
		if area then
			-- Brotato ZoneService.get_rand_pos_in_area: anywhere in a square `area` wide around it
			sx = x + (RandomService.number("Spawns") - 0.5) * area
			sz = z + (RandomService.number("Spawns") - 0.5) * area
		end
		EnemySim.spawn(
			enemyId,
			sx,
			sz,
			if context then context.hp else hpMultiplier,
			if context then context.damage else damageMultiplier,
			nil,
			nil,
			if context then context.speed else speedMultiplier,
			if context then context.wave else nil
		)
	end
end

-- A counter-shooter that was hit sprays its ring of shots (kind.retaliate, B9), evenly around it.
local function fireRing(id: number)
	local kind = world:getKind(id)
	local retaliate = kind and kind.retaliate
	local x, z = world:getPosition(id)
	if not (kind and retaliate and x and z) then
		return
	end
	local damage = world:getShotDamage(id)
	local now = workspace:GetServerTimeNow()
	local turn = if retaliate.randomDirections then 0 else RandomService.number("Combat") * 2 * math.pi
	for k = 1, retaliate.count do
		local angle = if retaliate.randomDirections
			then RandomService.number("Combat") * 2 * math.pi
			else turn + (k - 1) / retaliate.count * 2 * math.pi
		local dx, dz = math.cos(angle), math.sin(angle)
		local startX, startZ =
			if retaliate.fromCenter then x else x + dx * kind.radius,
			if retaliate.fromCenter then z else z + dz * kind.radius
		local shotId = volleys:fire(
			startX,
			startZ,
			dx,
			dz,
			retaliate.projectileSpeed,
			retaliate.projectileRange,
			retaliate.projectileRadius,
			damage
		)
		table.insert(firedShots, {
			id = shotId,
			x = startX,
			z = startZ,
			dx = dx,
			dz = dz,
			speed = retaliate.projectileSpeed,
			range = retaliate.projectileRange,
			at = now,
		})
	end
end

-- Eggs the last step reported hatch: their enemies appear around them and the egg is gone (no kill, B9).
local function hatchEggs()
	local hatches = world.hatches
	for h = 1, world.hatchCount do
		local id = hatches[h]
		local kind = world:getKind(id)
		local hatch = kind and kind.hatch
		local x, z = world:getPosition(id)
		if hatch and x and z then
			local hpMultiplier, damageMultiplier, speedMultiplier = world:getMultipliers(id)
			if hatch.nativeDeath then
				EnemySim.damage(id, world:getHealth(id), nil)
			else
				world:remove(id)
			end
			spawnAround(
				hatch.enemy,
				x,
				z,
				hatch.count,
				hatch.spread,
				hpMultiplier,
				damageMultiplier,
				speedMultiplier,
				id
			)
		end
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
		if kind and kind.nativeSpawn and x and z then
			NativeSummons.emit(world, id, kind.nativeSpawn, nil, function()
				return RandomService.number("Spawns")
			end, function(...)
				EnemySim.NativeSummon:Fire(...)
			end)
			if kind.nativeSpawn.dieOnRequest then
				EnemySim.damage(id, world:getHealth(id), nil)
			end
		elseif kind and summon and x and z then
			local hpMultiplier, damageMultiplier, speedMultiplier = world:getMultipliers(id)
			spawnAround(
				summon.enemy,
				x,
				z,
				summon.count,
				kind.radius + 2,
				hpMultiplier,
				damageMultiplier,
				speedMultiplier,
				id
			)
		end
	end
end

local function stepOnce()
	local startedAt = os.clock()
	weakness:step(STEP_SECONDS)
	collectTargets()
	local contacts = world:step(
		STEP_SECONDS,
		targetXs,
		targetZs,
		targetCount,
		hurtXs,
		hurtZs,
		nil,
		targetInputXs,
		targetInputZs,
		targetDirectionXs,
		targetDirectionZs
	)
	currentTick += 1
	local stepNow = workspace:GetServerTimeNow()
	volleys:step(STEP_SECONDS, hurtXs, hurtZs, targetCount)
	local ended = volleys.ended
	for k = 1, volleys.endedCount * 2 do
		table.insert(endedShots, ended[k])
	end
	fireShots(stepNow)
	for i = 1, world.count do
		local id = world.ids[i]
		local charge = world.kinds[i].charge
		if charge and charge.projectileDamage and world.modes[i] == World.MODE_RUSH and world.hp[i] > 0 then
			local x, z = world.xs[i], world.zs[i]
			local trail = chargeTrails[id]
			if not trail then
				trail = { x = x, z = z, distance = charge.trailEvery or 1 }
				chargeTrails[id] = trail
			end
			trail.distance += math.sqrt((x - trail.x) ^ 2 + (z - trail.z) ^ 2)
			trail.x, trail.z = x, z
			if trail.distance >= (charge.trailEvery or 1) then
				trail.distance %= charge.trailEvery or 1
				local angle = charge.trailAngle or math.pi / 2
				local c, s = math.cos(angle), math.sin(angle)
				local rx, rz = world.rushXs[i], world.rushZs[i]
				for _, side in { -1, 1 } do
					EnemySim.fireShot(
						x,
						z,
						rx * c - rz * s * side,
						rx * s * side + rz * c,
						charge.projectileSpeed or 1,
						charge.projectileRange or 1,
						charge.projectileRadius or 0,
						world:getShotDamage(id)
					)
				end
			end
		else
			chargeTrails[id] = nil
		end
	end
	for id in spawnContexts do
		if not world:isAlive(id) then
			spawnContexts[id] = nil
			chargeTrails[id] = nil
		end
	end
	callSummons()
	hatchEggs()
	for id in nativeBases do
		if not world:isAlive(id) and not friends.world:isAlive(id) then
			nativeBases[id] = nil
		end
	end
	friends:step(STEP_SECONDS, stepNow, world)
	EnemySim.Stepped:Fire(STEP_SECONDS, stepNow)
	local seconds = os.clock() - startedAt
	window.steps += 1
	window.seconds += seconds
	window.maxSeconds = math.max(window.maxSeconds, seconds)

	for t = 1, targetCount do
		local damage = contacts[t]
		if damage > 0 then
			EnemySim.Contact:Fire(targetPlayers[t], damage, world.contactSources[t] or 0)
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
	-- Paket 22: one compact packet (Net/ShotFeed) instead of a table per shot
	local payload = ShotFeed.encode({ reset = reset, fired = firedShots, ended = endedShots })
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("EnemyShots", player, payload)
	end
	firedShots = {}
	endedShots = {}
end

-- Sends the current enemies of `currentTick` to every participant still in the server.
local function sendSnapshot()
	local count = 0
	local function append(actors: World.World, charmed: boolean)
		local ids, xs, zs, typeIds, hp, maxHp =
			actors.ids, actors.xs, actors.zs, actors.typeIds, actors.hp, actors.maxHp
		local kinds, modes, rushXs, rushZs = actors.kinds, actors.modes, actors.rushXs, actors.rushZs
		local slowFactors, burning, buffed = actors.slowFactors, actors.burning, actors.buffed
		for i = 1, actors.count do
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
				columns.statuses[count] = (if charmed then Snapshot.STATUS_CHARMED else 0)
					+ (if burning[i] then Snapshot.STATUS_BURNING else 0)
					+ (if slowFactors[i] < 1 or actors.nativeSlows:active(ids[i]) then Snapshot.STATUS_SLOWED else 0)
					+ (if buffed[i] then Snapshot.STATUS_BUFFED else 0)
					+ Snapshot.packPursuerStage(if actors.pursuers[i] then actors.pursuers[i].stage else 0)
			end
		end
	end
	append(world, false)
	append(friends.world, true)
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
	MapService.NativeTerrainChanged:Connect(function()
		local bodies = actorObstacles()
		local circles = MapService.getForbiddenCircles()
		world.params.obstacles = bodies
		friends.world.params.obstacles = bodies
		world.params.forbiddenCircles = circles
		friends.world.params.forbiddenCircles = circles
	end)
	MapService.ArenaResized:Connect(function(bounds: MapService.Bounds)
		local center = bounds.center
		local minX, maxX = center.X - bounds.halfX, center.X + bounds.halfX
		local minZ, maxZ = center.Z - bounds.halfZ, center.Z + bounds.halfZ
		world:setBounds(minX, maxX, minZ, maxZ)
		volleys:setBounds(minX, maxX, minZ, maxZ)
		friends.world:setBounds(minX, maxX, minZ, maxZ)
		friends.shots:setBounds(minX, maxX, minZ, maxZ)
	end)
	RunDirector.RunStarted:Connect(function()
		table.clear(spawnContexts)
		table.clear(chargeTrails)
		world:clear()
		friends:clear()
		table.clear(nativeBases)
		weakness:clear()
		volleys:clear()
		accumulator = 0
		firedShots, endedShots = {}, {}
		sendShots(true)
	end)
	local function clearAll()
		table.clear(spawnContexts)
		table.clear(chargeTrails)
		world:clear()
		friends:clear()
		table.clear(nativeBases)
		weakness:clear()
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
	speedMultiplier: number?,
	wave: number?
): number?
	local kind = EnemyKinds.get(enemyId, elite, affix)
	assert(kind, `Unknown enemy {enemyId}`)
	if EnemySim.getCount() >= Config.Run.spawn.cap.max then
		return nil
	end
	local baseShot = World.baseShotDamage(kind)
	local hpGrowth, contactGrowth, shotGrowth = 1, 1, 1
	if wave then
		hpGrowth, contactGrowth, shotGrowth = EnemyStats.growth(kind, wave)
	end
	local shotDamage = if baseShot > 0 then baseShot * damageMultiplier * shotGrowth else nil
	local speed = EnemyStats.spawnSpeedFactor(
		kind,
		RandomService.number("Spawns"),
		speedMultiplier or 1,
		RunDirector.getRunOptions().enemySpeed / 100
	)
	local id = world:spawn(
		kind,
		x,
		z,
		kind.hp * hpMultiplier * hpGrowth,
		kind.contactDamage * damageMultiplier * contactGrowth,
		shotDamage,
		speed,
		wave
	)
	if id then
		local index = world.indexOf[id]
		nativeBases[id] = {
			spawnedAt = workspace:GetServerTimeNow(),
			contact = if kind.pursuer
				then kind.contactDamage * damageMultiplier * contactGrowth
				else world.contactDamage[index],
			shot = world.shotDamage[index],
			spawn = { hp = hpMultiplier, damage = damageMultiplier, speed = speedMultiplier or 1, wave = wave },
		}
	end
	if id and wave then
		spawnContexts[id] = { hp = hpMultiplier, damage = damageMultiplier, speed = speedMultiplier or 1, wave = wave }
	end
	return id
end

-- Descendants of charmed summoners/splitters/eggs inherit Charm and a fresh native lifetime.
function EnemySim.spawnCharmChildren(
	member: any,
	kind: string,
	x: number,
	z: number,
	count: number,
	spread: number,
	area: number?
)
	local context = member.base.spawn
	local turn = RandomService.number("Spawns") * math.pi * 2
	for index = 1, count do
		local angle = turn + (index - 1) / count * math.pi * 2
		local sx, sz = x + math.cos(angle) * spread, z + math.sin(angle) * spread
		if area then
			sx = x + (RandomService.number("Spawns") - 0.5) * area
			sz = z + (RandomService.number("Spawns") - 0.5) * area
		end
		local id = EnemySim.spawn(kind, sx, sz, context.hp, context.damage, nil, nil, context.speed, context.wave)
		if id then
			friends:convert(world, id, member.owner, workspace:GetServerTimeNow(), nativeBases[id])
		end
	end
end
function EnemySim.resolveCharmDeath(member: any, x: number, z: number)
	local split = member.kind.split
	if split then
		EnemySim.spawnCharmChildren(member, split.enemy, x, z, split.count, split.spread, split.area)
	end
	EnemySim.EnemyKilled:Fire({
		id = member.id,
		enemyId = member.kind.id,
		typeId = member.kind.typeId,
		position = Vector3.new(x, floorY, z),
		xp = member.kind.xp,
		elite = false,
		boss = false,
		killer = nil,
	})
end

-- Charm is a pre-hit server decision; successful conversion absorbs the triggering hit completely.
function EnemySim.tryCharm(player: Player, id: number, stats: { [string]: number }, random: () -> number): boolean
	if not world:isAlive(id) then
		return false
	end
	local kind = world:getKind(id)
	if not kind then
		return false
	end
	local hp, maxHp = world:getHealth(id)
	local chance = CharmRules.chance(
		stats,
		{ kind = kind.id, hp = hp, maxHp = maxHp, elite = kind.elite, boss = kind.boss ~= nil },
		friends:count(player.UserId),
		require(Shared.Util.DangerRules).endlessFactor(RunDirector.getWave())
	)
	if not CharmRules.success(chance, random) then
		return false
	end
	return friends:convert(world, id, player.UserId, workspace:GetServerTimeNow(), nativeBases[id])
end
-- Trusted server-only completion after a native summon birth; no random on-hit Charm roll.
function EnemySim.charmSummoned(id: number, owner: number): boolean
	local base = nativeBases[id]
	return base ~= nil and friends:convert(world, id, owner, workspace:GetServerTimeNow(), base)
end
function EnemySim.isCharmed(id: number): boolean
	return friends.world:isAlive(id)
end
function EnemySim.getCharmedCount(owner: number): number
	return friends:count(owner)
end

-- Native timed/fixed speed additions for Tranq/Harpoon, preserving the normal snapshot and movement paths.
function EnemySim.nativeSlow(id: number, amount: number, percent: boolean, hold: number)
	world:nativeSlow(id, amount, percent, hold)
end

-- Stable Lute/Blowgun effects apply before their hit, share source stacks across players and expire together.
function EnemySim.applyWeakness(id: number, source: string, percent: number, seconds: number, stacks: number)
	if world:isAlive(id) then
		weakness:apply(id, source, percent, seconds, stacks)
	end
end

-- Deals damage to one enemy. Returns true if this hit killed it (and fires EnemyKilled), the HP it took and the
-- damage after the enemy's own damageTaken multiplier (for damage numbers). A killed Splitter falls apart; a
-- counter-shooter that survives sprays its ring (B9).
-- The effect service owns item policy; valid player-owned hitboxes share neutral tree execution here.
local treeHitRule: ((Player) -> boolean)? = nil
function EnemySim.setTreeHitRule(rule: (Player) -> boolean)
	treeHitRule = rule
end

function EnemySim.damage(
	id: number,
	amount: number,
	source: Player?,
	bonusPercent: number?,
	ownerHitbox: boolean?,
	digCrateChance: number?
): (boolean, number, number)
	local totalBonus = (bonusPercent or 0) + weakness:bonus(id)
	if totalBonus ~= 0 then
		amount = math.round(amount * (1 + totalBonus / 100))
	end
	local killed, dealt, applied, retaliates = world:damage(id, amount)
	local hitKind = world:getKind(id)
	if
		not killed
		and ownerHitbox
		and source
		and treeHitRule
		and hitKind
		and hitKind.id == "Tree"
		and treeHitRule(source)
	then
		killed = world:remove(id)
	end
	if not killed then
		if retaliates then
			fireRing(id)
		end
		return false, dealt, applied
	end
	weakness:remove(id)
	local kind = world:getKind(id)
	local x, z = world:getPosition(id)
	if kind and x and z then
		local split = kind.split
		if split then
			local hpMultiplier, damageMultiplier, speedMultiplier = world:getMultipliers(id)
			spawnAround(
				split.enemy,
				x,
				z,
				split.count,
				split.spread,
				hpMultiplier,
				damageMultiplier,
				speedMultiplier,
				id,
				split.area
			)
		end
		EnemySim.EnemyKilled:Fire({
			id = id,
			enemyId = kind.id,
			typeId = kind.typeId,
			position = Vector3.new(x, floorY, z),
			xp = kind.xp,
			elite = kind.elite == true,
			boss = kind.boss ~= nil,
			killer = source,
			aliveSeconds = if nativeBases[id]
				then math.max(0, workspace:GetServerTimeNow() - nativeBases[id].spawnedAt)
				else nil,
			digCrateChance = if ownerHitbox then digCrateChance else nil,
		} :: KillInfo)
	end
	return true, dealt, applied
end

-- Ranged weapon hits alone can trigger the Fly reference's counter-shot; called by WeaponService.onHit.
function EnemySim.retaliate(id: number, weaponKind: string)
	local kind = world:getKind(id)
	local ability = kind and kind.retaliate
	if
		world:isAlive(id)
		and ability
		and ability.rangedOnly
		and weaponKind == "Ranged"
		and (ability.chance or 1) ~= 0
		and RandomService.number("Combat") <= (ability.chance or 1)
	then
		fireRing(id)
	end
end

-- Pushes a living enemy along the floor by `offset` (x/z), less the more it resists knockback (World.push).
function EnemySim.push(id: number, offset: Vector3)
	world:push(id, offset.X, offset.Z)
end

-- Knocks a living enemy back like Brotato (World.knock): (dx, dz) is direction x knockback in weapon units; `add`
-- adds to the current knockback instead of replacing it.
function EnemySim.knock(id: number, dx: number, dz: number, add: boolean?)
	world:knock(id, dx, dz, add)
end

-- Brotato Enemy._on_hit_something: an enemy whose touch landed (hit, dodged or blocked) brakes by
-- max(recoilMinPoints, recoilShare x its speed) speed points, recovering like every native slow.
function EnemySim.contactRecoil(id: number)
	local kind = world:isAlive(id) and world:getKind(id)
	if not kind then
		return
	end
	local rule = Config.Simulation.contactRecoil
	local i = world.indexOf[id]
	local points = kind.speed * world.speedFactors[i] * world.boosts[i] / Config.Stats.range.studsPerPoint
	world:nativeSlow(id, -math.max(rule.minPoints, points * rule.speedShare), false, 0)
end

-- Slows a living enemy to `factor` of its speed for `seconds`; the stronger slow wins (B5, World.slow).
function EnemySim.slow(id: number, factor: number, seconds: number)
	world:slow(id, factor, seconds)
end

-- Shows a living enemy as burning (or not) in the snapshots; WeaponService runs the burn itself (B5).
function EnemySim.setBurning(id: number, on: boolean)
	world:setBurning(id, on)
end

-- Server pet targeting reads the same authoritative burn flag sent in enemy snapshots.
function EnemySim.isBurning(id: number): boolean
	local _, burning = world:getStatus(id)
	return burning
end

-- Removes a living enemy without a kill: no EnemyKilled, no loot (a Looter escaping, B6). Returns true if it was alive.
function EnemySim.remove(id: number): boolean
	weakness:remove(id)
	return world:remove(id)
end

-- Multiplier on a living enemy's speed (a boss phase, WP10).
function EnemySim.setSpeedFactor(id: number, factor: number)
	world:setSpeedFactor(id, factor)
end

-- Fires one enemy projectile from x/z along the unit direction dx/dz (boss attacks, WP10). It flies like a
-- Spitter's (Volleys) and goes to the participants with the next EnemyShots.
function EnemySim.fireShot(
	x: number,
	z: number,
	dx: number,
	dz: number,
	speed: number,
	range: number,
	radius: number,
	damage: number,
	motion: Types.EnemyShotMotion?
)
	local id = volleys:fire(x, z, dx, dz, speed, range, radius, damage, motion)
	table.insert(firedShots, {
		id = id,
		x = x,
		z = z,
		dx = dx,
		dz = dz,
		speed = speed,
		range = range,
		at = workspace:GetServerTimeNow(),
		motion = motion,
	})
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
	if friends.world:isAlive(id) then
		x, z = friends.world:getPosition(id)
	end
	if not (x and z) then
		return nil
	end
	return Vector3.new(x, floorY, z)
end

-- Exact live hurt-circle center/radius, separate from the actor origin used by snapshots and drops.
function EnemySim.getHurtGeometry(id: number): (Vector3?, number?)
	local actors = if friends.world.indexOf[id] then friends.world else world
	local x, z, radius = actors:getHurtGeometry(id)
	if not (x and z and radius) then
		return nil, nil
	end
	return Vector3.new(x, floorY, z), radius
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

-- Native damage geometry. Default uses the last compensated step; false reads the current authoritative root.
function EnemySim.getPlayerHurtGeometry(player: Player, compensated: boolean?): (Vector3?, number?)
	if RunDirector.getParticipantState(player) ~= "Alive" then
		return nil, nil
	end
	if compensated == false then
		local origin = MapService.getRootPosition(player)
		if not origin then
			return nil, nil
		end
		local x, z = PlayerHurt.center(origin.X, origin.Z)
		return Vector3.new(x, floorY, z), PlayerHurt.radius
	end
	local index = targetIndexOf[player]
	if not index then
		return nil, nil
	end
	return Vector3.new(hurtXs[index], floorY, hurtZs[index]), PlayerHurt.radius
end

-- Enemy id (key in Config.Enemies.types or .bosses) and whether it is an elite, nil for unknown ids. Bosses count as
-- elites (Damage vs Elites, item effects on elites; WP10).
function EnemySim.getKind(id: number): (string?, boolean)
	local kind = if friends.world:isAlive(id) then friends.world:getKind(id) else world:getKind(id)
	if not kind then
		return nil, false
	end
	return kind.id, kind.elite == true or kind.boss ~= nil
end

-- Sets the mode of a living boss or champion (World.MODE_*: walk, wind-up, rush, recover) and its rush direction x/z,
-- which the snapshots carry to the clients (BossService, WP10).
function EnemySim.setMode(id: number, mode: number, rushX: number?, rushZ: number?)
	world:setMode(id, mode, rushX, rushZ)
end

-- Enemy._on_hurt slow hooks can be overridden independently of damage, knockback and direct Unit speed effects.
function EnemySim.allowsHurtSlowEffects(id: number): boolean
	local actors = if friends.world.indexOf[id] then friends.world else world
	local index = actors.indexOf[id]
	return index ~= nil and actors.kinds[index].nativeHurtSlowEffects ~= false
end

-- Mode of a living enemy (EnemySim/World.MODE_*: walk, wind-up, rush, recover) and its rush direction x/z.
function EnemySim.getMode(id: number): (number, number, number)
	return (if friends.world:isAlive(id) then friends.world else world):getMode(id)
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

-- Wave-wide living counts include friendly charmed actors; hostile targeting continues to use collectIds.
function EnemySim.collectAllIds(out: { number }): number
	local count = EnemySim.collectIds(out)
	for index = 1, friends.world.count do
		if friends.world.hp[index] > 0 then
			count += 1
			out[count] = friends.world.ids[index]
		end
	end
	return count
end

-- Ids of the living enemies that eat orbs (kind.eat, the Gobbler, B9), written to out[1 .. n]; returns n.
function EnemySim.collectEaters(out: { number }): number
	local count = 0
	local ids, hp, kinds = world.ids, world.hp, world.kinds
	for i = 1, world.count do
		if hp[i] > 0 and kinds[i].eat then
			count += 1
			out[count] = ids[i]
		end
	end
	for index = 1, friends.world.count do
		if friends.world.hp[index] > 0 and friends.world.kinds[index].eat then
			count += 1
			out[count] = friends.world.ids[index]
		end
	end
	return count
end

-- Makes an enemy walk to `position` instead of the nearest player, or back to the players with nil (B9).
function EnemySim.setGoal(id: number, position: Vector3?)
	local actors = if friends.world:isAlive(id) then friends.world else world
	if position then
		actors:setGoal(id, position.X, position.Z)
	else
		actors:setGoal(id)
	end
end

-- Number of enemy projectiles in flight.
function EnemySim.getShotCount(): number
	return volleys:getCount()
end

-- Current HP of an enemy, 0 for dead or unknown ids (item effects since B8: damage by a share of the enemy's HP).
function EnemySim.getHealth(id: number): number
	local actors = if friends.world:isAlive(id) then friends.world else world
	return (actors:getHealth(id))
end

-- Current HP of an enemy as a share of its max HP, 0 for dead or unknown ids (BossService, WP10).
function EnemySim.getHealthShare(id: number): number
	local hp, maxHp = (if friends.world:isAlive(id) then friends.world else world):getHealth(id)
	return if maxHp > 0 then math.max(0, hp) / maxHp else 0
end

-- Max HP of an enemy, 0 for unknown ids.
function EnemySim.getMaxHealth(id: number): number
	local _, maxHp = (if friends.world:isAlive(id) then friends.world else world):getHealth(id)
	return maxHp
end

-- The HP, damage and speed multipliers the enemy was spawned with (1, 1, 1 for unknown ids).
function EnemySim.getMultipliers(id: number): (number, number, number)
	return world:getMultipliers(id)
end

-- Number of living enemies.
function EnemySim.getCount(): number
	return world:getAliveCount() + friends.world:getAliveCount()
end

function EnemySim.getStats(): Stats
	return stats
end

return EnemySim
