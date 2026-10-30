--!strict
-- The boss wave (DESIGN.md section 7, WP10, like Brotato's wave 20): when the last wave starts, red crosses show
-- where its boss comes (Config.Enemies.bossWave), then one boss picked at random appears (bossWave.count). Bosses are
-- enemies in EnemySim with a plan of phases and attacks (Config.Enemies.bosses, kind.boss); BossBrain decides when
-- each attack winds up and strikes, this service carries it out: warnings on the floor (BossTelegraphs), dashes,
-- slams, rings of shots, red circles around the players and shots that close in on them, the embers circling the
-- boss, its phase speed and roaming. Killing every boss of the wave wins the run (RunDirector.endRun("Victory")),
-- as does surviving the wave (RunFlow). Sends BossState (HP bar, phase) to the participants.
-- Uses EnemySim, RunDirector, CombatService, MapService, RandomService and StatService; AdminService spawns and hurts
-- bosses for tests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Enemies = require(Shared.Config.Enemies)
local EnemyKinds = require(Shared.Util.EnemyKinds)
local Net = require(Shared.Net)
local RunSchedule = require(Shared.Util.RunSchedule)
local StatMath = require(Shared.Util.StatMath)
local Types = require(Shared.Net.Types)

local CombatService = require(script.Parent.CombatService)
local EnemySim = require(script.Parent.EnemySim)
local MapService = require(script.Parent.MapService)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local StatService = require(script.Parent.StatService)
local SpawnRules = require(script.Parent.SpawnDirector.SpawnRules)
local BossBrain = require(script.BossBrain)

local BossWave = Config.Enemies.bossWave
local PLAYER_RADIUS = Config.Simulation.playerRadius
local SPAWN_TRIES = 16
local ROAM_REACHED = 4 -- studs: a roaming boss picks its next spot this close to the last one
local ROAM_MARGIN = 12 -- studs from the arena edge

type Target = { player: Player, x: number, z: number }

type Boss = {
	id: number,
	bossId: string,
	kind: Enemies.Enemy,
	brain: BossBrain.Brain,
	wave: boolean, -- came with the boss wave (its death counts towards the victory)
	damageMultiplier: number,
	speedFactor: number, -- from the team's Enemy Speed at spawn; the phase multiplies it
	orbitStartedAt: number?,
	-- the attack in progress
	dirX: number, -- Dash direction
	dirZ: number,
	dashLeft: number,
	dashHit: { [Player]: boolean },
	spots: { number }, -- Rain and Circle: flat x, z of every spot, then for Circle the centre per spot (x, z)
	roamX: number?,
	roamZ: number?,
}

local BossService = {}

local bosses: { Boss } = {}
local pendingSpawns: { { bossId: string, x: number, z: number, at: number } } = {}
local bossWaveStarted = false
local victoryQueued = false
local nextDebugBoss = 0
local stateTimer = 0
local sentEmpty = true
local telegraphs: { Types.BossTelegraph } = {}
local targets: { Target } = {}
local orbitHits: { [Player]: boolean } = {}

local bounds = (function()
	local arena = MapService.getArenaBounds()
	local center, half = arena.center, arena.halfSize
	return { minX = center.X - half, maxX = center.X + half, minZ = center.Z - half, maxZ = center.Z + half }
end)()
local obstacles = MapService.getObstacles()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function notifyParticipants(text: string)
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("Notify", player, text)
	end
end

local function collectTargets()
	table.clear(targets)
	for _, player in RunDirector.getParticipants() do
		local position = EnemySim.getPlayerPosition(player) -- nil unless alive
		if position then
			table.insert(targets, { player = player, x = position.X, z = position.Z })
		end
	end
end

local function nearestTarget(x: number, z: number): (Target?, number)
	local best: Target? = nil
	local bestDistance = math.huge
	for _, target in targets do
		local d = math.sqrt((target.x - x) ^ 2 + (target.z - z) ^ 2)
		if d < bestDistance then
			best, bestDistance = target, d
		end
	end
	return best, bestDistance
end

local function hurt(player: Player, damage: number)
	CombatService.damagePlayer(player, damage)
end

local function isFree(x: number, z: number, radius: number): boolean
	return SpawnRules.isFree(x, z, radius, bounds, obstacles)
end

-- Telegraphs ------------------------------------------------------------------------

local function circle(x: number, z: number, radius: number, seconds: number)
	local at = now()
	table.insert(telegraphs, { shape = "Circle", x = x, z = z, radius = radius, startsAt = at, hitsAt = at + seconds })
end

local function line(x: number, z: number, dx: number, dz: number, length: number, halfWidth: number, seconds: number)
	local at = now()
	table.insert(telegraphs, {
		shape = "Line",
		x = x,
		z = z,
		radius = halfWidth,
		dx = dx,
		dz = dz,
		length = length,
		startsAt = at,
		hitsAt = at + seconds,
	})
end

local function sendTelegraphs()
	if #telegraphs == 0 then
		return
	end
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("BossTelegraphs", player, telegraphs)
	end
	telegraphs = {}
end

local function sendState(force: boolean?)
	if #bosses == 0 and sentEmpty and not force then
		return
	end
	local list: { Types.BossInfo } = {}
	for _, boss in bosses do
		table.insert(list, {
			id = boss.id,
			bossId = boss.bossId,
			hpFraction = EnemySim.getHealthShare(boss.id),
			phase = boss.brain.phase,
			phaseCount = #(boss.kind.boss :: Enemies.BossPlan).phases,
			orbitStartedAt = boss.orbitStartedAt,
		})
	end
	sentEmpty = #list == 0
	local payload: Types.BossState = { bosses = list }
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("BossState", player, payload)
	end
end

-- Spawning --------------------------------------------------------------------------

-- A free spot about spawnDistance from (x, z), or (x, z) pushed into the arena.
local function spotNear(x: number, z: number, radius: number): (number, number)
	local random = RandomService.stream("Spawns")
	for _ = 1, SPAWN_TRIES do
		local angle = random:NextNumber() * 2 * math.pi
		local px = x + math.cos(angle) * BossWave.spawnDistance
		local pz = z + math.sin(angle) * BossWave.spawnDistance
		if isFree(px, pz, radius) then
			return px, pz
		end
	end
	return math.clamp(x, bounds.minX + radius, bounds.maxX - radius),
		math.clamp(z, bounds.minZ + radius, bounds.maxZ - radius)
end

local function phaseOf(boss: Boss): Enemies.BossPhase
	return (boss.kind.boss :: Enemies.BossPlan).phases[boss.brain.phase]
end

local function applyPhase(boss: Boss)
	local phase = phaseOf(boss)
	EnemySim.setSpeedFactor(boss.id, boss.speedFactor * (phase.speedMultiplier or 1))
	boss.orbitStartedAt = if phase.orbit then now() else nil
	boss.roamX, boss.roamZ = nil, nil
	if not phase.roam then
		EnemySim.setGoal(boss.id, nil)
	end
end

-- Puts boss `bossId` at x/z with this run's multipliers. Returns its enemy id, or nil at the hard cap.
local function spawnBoss(bossId: string, x: number, z: number, wave: boolean, share: number): number?
	local kind = EnemyKinds.get(bossId)
	local plan = kind and kind.boss
	if not (kind and plan) then
		return nil
	end
	local tiers = Config.Difficulty.tiers
	local tier = tiers[RunDirector.getDifficulty()] or tiers[Config.Difficulty.default]
	local players = #RunDirector.getParticipants()
	local hpMultiplier = share
		* tier.enemyHp
		* StatMath.enemyFactor(StatService.getTeamStat("enemyHp"))
		* SpawnRules.playerFactor(players)
	local damageMultiplier = tier.enemyDamage * StatMath.enemyFactor(StatService.getTeamStat("enemyDamage"))
	local speedFactor = StatMath.enemyFactor(StatService.getTeamStat("enemySpeed"))
	local id = EnemySim.spawn(bossId, x, z, hpMultiplier, damageMultiplier, nil, nil, speedFactor)
	if not id then
		return nil
	end
	local boss: Boss = {
		id = id,
		bossId = bossId,
		kind = kind,
		brain = BossBrain.new(plan),
		wave = wave,
		damageMultiplier = damageMultiplier,
		speedFactor = speedFactor,
		orbitStartedAt = nil,
		dirX = 0,
		dirZ = 0,
		dashLeft = 0,
		dashHit = {},
		spots = {},
		roamX = nil,
		roamZ = nil,
	}
	table.insert(bosses, boss)
	applyPhase(boss)
	notifyParticipants(`{kind.displayName} awakens!`)
	sendState(true)
	return id
end

-- The boss wave started: pick its bosses and show where they come.
local function startBossWave()
	bossWaveStarted = true
	collectTargets()
	local anchor = targets[1]
	if #targets > 1 then
		anchor = targets[RandomService.stream("Spawns"):NextInteger(1, #targets)]
	end
	local center = Config.Map.arena.center
	local ax, az = if anchor then anchor.x else center.X, if anchor then anchor.z else center.Z
	local order = BossWave.order
	local first = RandomService.stream("Spawns"):NextInteger(1, #order)
	local at = now() + BossWave.introSeconds
	local points = {}
	for k = 1, BossWave.count do
		local bossId = order[(first + k - 2) % #order + 1]
		local kind = EnemyKinds.get(bossId)
		local x, z = spotNear(ax, az, if kind then kind.radius else 4)
		table.insert(pendingSpawns, { bossId = bossId, x = x, z = z, at = at })
		table.insert(points, x)
		table.insert(points, z)
	end
	local markers: Types.SpawnMarkers = { points = points, spawnsAt = at }
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("SpawnMarkers", player, markers)
	end
	notifyParticipants("The boss wave begins!")
end

local function spawnPending()
	local share = if BossWave.count > 1 then BossWave.hpShareWhenSeveral else 1
	local at = now()
	for index = #pendingSpawns, 1, -1 do
		local entry = pendingSpawns[index]
		if at >= entry.at then
			table.remove(pendingSpawns, index)
			spawnBoss(entry.bossId, entry.x, entry.z, true, share)
		end
	end
end

-- Attacks ---------------------------------------------------------------------------

local function attackOf(boss: Boss, attackId: string): Enemies.BossAttack
	return (boss.kind.boss :: Enemies.BossPlan).attacks[attackId]
end

-- The warning of an attack that starts winding up; fixes where it will hit.
local function windup(boss: Boss, attack: Enemies.BossAttack, x: number, z: number)
	local seconds = attack.windupSeconds
	local radius = boss.kind.radius
	table.clear(boss.spots)
	if attack.kind == "Dash" then
		local target = nearestTarget(x, z)
		local dx, dz = if target then target.x - x else 0, if target then target.z - z else 1
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 1e-3 then
			dx, dz, length = 0, 1, 1
		end
		boss.dirX, boss.dirZ = dx / length, dz / length
		table.clear(boss.dashHit)
		line(x, z, boss.dirX, boss.dirZ, radius + (attack.distance or 0), radius, seconds)
	elseif attack.kind == "Slam" then
		circle(x, z, attack.radius or 0, seconds)
	elseif attack.kind == "Ring" then
		circle(x, z, radius + 1.5, seconds)
	elseif attack.kind == "Rain" then
		local random = RandomService.stream("Combat")
		local spread = attack.spread or 0
		for _, target in targets do
			for _ = 1, attack.count or 0 do
				local angle = random:NextNumber() * 2 * math.pi
				local distance = math.sqrt(random:NextNumber()) * spread
				local sx, sz = target.x + math.cos(angle) * distance, target.z + math.sin(angle) * distance
				table.insert(boss.spots, sx)
				table.insert(boss.spots, sz)
				circle(sx, sz, attack.radius or 0, seconds)
			end
		end
	elseif attack.kind == "Circle" then
		local count = attack.count or 0
		local spread = attack.spread or 0
		local turn = RandomService.number("Combat") * 2 * math.pi
		for _, target in targets do
			for k = 1, count do
				local angle = turn + (k - 1) / count * 2 * math.pi
				local sx, sz = target.x + math.cos(angle) * spread, target.z + math.sin(angle) * spread
				table.insert(boss.spots, sx)
				table.insert(boss.spots, sz)
				circle(sx, sz, (attack.projectileRadius or 0.5) * 2, seconds)
			end
		end
	end
end

local function ring(boss: Boss, attack: Enemies.BossAttack, x: number, z: number, burst: number)
	local count = attack.count or 0
	local radius = boss.kind.radius
	local turn = (burst - 1) * 0.5 / math.max(count, 1) * 2 * math.pi -- every other burst fills the gaps
	for k = 1, count do
		local angle = turn + (k - 1) / count * 2 * math.pi
		local dx, dz = math.cos(angle), math.sin(angle)
		EnemySim.fireShot(
			x + dx * radius,
			z + dz * radius,
			dx,
			dz,
			attack.projectileSpeed or 15,
			attack.projectileRange or 50,
			attack.projectileRadius or 0.6,
			attack.damage * boss.damageMultiplier
		)
	end
end

local function strike(boss: Boss, attack: Enemies.BossAttack, x: number, z: number, burst: number)
	local damage = attack.damage * boss.damageMultiplier
	if attack.kind == "Dash" then
		boss.dashLeft = attack.distance or 0
	elseif attack.kind == "Slam" then
		local reach = (attack.radius or 0) + PLAYER_RADIUS
		for _, target in targets do
			if (target.x - x) ^ 2 + (target.z - z) ^ 2 <= reach * reach then
				hurt(target.player, damage)
			end
		end
	elseif attack.kind == "Ring" then
		ring(boss, attack, x, z, burst)
	elseif attack.kind == "Rain" then
		local reach = (attack.radius or 0) + PLAYER_RADIUS
		local spots = boss.spots
		for _, target in targets do
			for k = 1, #spots - 1, 2 do
				if (target.x - spots[k]) ^ 2 + (target.z - spots[k + 1]) ^ 2 <= reach * reach then
					hurt(target.player, damage)
					break
				end
			end
		end
	elseif attack.kind == "Circle" then
		local spots = boss.spots
		local count = attack.count or 0
		local spread = attack.spread or 0
		for k = 1, #spots - 1, 2 do
			-- the centre of this spot's circle: spots come in groups of `count` around one player
			local first = math.floor((k - 1) / (2 * count)) * 2 * count + 1
			local cx, cz = 0, 0
			for j = first, first + 2 * count - 1, 2 do
				cx += spots[j]
				cz += spots[j + 1]
			end
			cx, cz = cx / count, cz / count
			local dx, dz = cx - spots[k], cz - spots[k + 1]
			local length = math.sqrt(dx * dx + dz * dz)
			if length > 1e-3 then
				EnemySim.fireShot(
					spots[k],
					spots[k + 1],
					dx / length,
					dz / length,
					attack.projectileSpeed or 14,
					2 * spread,
					attack.projectileRadius or 0.6,
					damage
				)
			end
		end
	end
end

-- One step of a dash: moves the boss along its line, hurts every player it runs into once and stops at an obstacle,
-- the arena edge or the end of the line.
local function dashStep(boss: Boss, attack: Enemies.BossAttack, x: number, z: number, dt: number)
	local radius = boss.kind.radius
	local move = math.min((attack.speed or 0) * dt, boss.dashLeft)
	local nx, nz = x + boss.dirX * move, z + boss.dirZ * move
	local blocked = nx < bounds.minX + radius
		or nx > bounds.maxX - radius
		or nz < bounds.minZ + radius
		or nz > bounds.maxZ - radius
	for _, obstacle in obstacles do
		if (nx - obstacle.x) ^ 2 + (nz - obstacle.z) ^ 2 < (obstacle.radius + radius) ^ 2 then
			blocked = true
		end
	end
	if blocked then
		boss.dashLeft = 0
		BossBrain.endAct(boss.brain)
		return
	end
	boss.dashLeft -= move
	EnemySim.teleport(boss.id, Vector3.new(nx, 0, nz))
	local reach = radius + PLAYER_RADIUS
	local damage = attack.damage * boss.damageMultiplier
	for _, target in targets do
		if not boss.dashHit[target.player] and (target.x - nx) ^ 2 + (target.z - nz) ^ 2 <= reach * reach then
			boss.dashHit[target.player] = true
			hurt(target.player, damage)
		end
	end
	if boss.dashLeft <= 1e-3 then
		BossBrain.endAct(boss.brain)
	end
end

-- The embers circling the boss in this phase hurt the players they touch.
local function orbitStep(boss: Boss, x: number, z: number, at: number)
	local orbit = phaseOf(boss).orbit
	local startedAt = boss.orbitStartedAt
	if not (orbit and startedAt) then
		return
	end
	table.clear(orbitHits)
	local turn = (at - startedAt) * orbit.turnsPerSecond * 2 * math.pi
	local reach = orbit.hitRadius + PLAYER_RADIUS
	for k = 1, orbit.count do
		local angle = turn + (k - 1) / orbit.count * 2 * math.pi
		local ox, oz = x + math.cos(angle) * orbit.radius, z + math.sin(angle) * orbit.radius
		for _, target in targets do
			if not orbitHits[target.player] and (target.x - ox) ^ 2 + (target.z - oz) ^ 2 <= reach * reach then
				orbitHits[target.player] = true
				hurt(target.player, orbit.damage * boss.damageMultiplier)
			end
		end
	end
end

-- Where a roaming boss runs: a random spot of the arena, a new one once it got there.
local function roamStep(boss: Boss, x: number, z: number)
	local rx, rz = boss.roamX, boss.roamZ
	if rx and rz and (rx - x) ^ 2 + (rz - z) ^ 2 > ROAM_REACHED * ROAM_REACHED then
		return
	end
	local random = RandomService.stream("Spawns")
	for _ = 1, SPAWN_TRIES do
		local px = bounds.minX + ROAM_MARGIN + random:NextNumber() * (bounds.maxX - bounds.minX - 2 * ROAM_MARGIN)
		local pz = bounds.minZ + ROAM_MARGIN + random:NextNumber() * (bounds.maxZ - bounds.minZ - 2 * ROAM_MARGIN)
		if isFree(px, pz, boss.kind.radius) then
			boss.roamX, boss.roamZ = px, pz
			EnemySim.setGoal(boss.id, Vector3.new(px, 0, pz))
			return
		end
	end
end

local function stepBoss(boss: Boss, dt: number, at: number)
	local position = EnemySim.getPosition(boss.id)
	if not position then
		return
	end
	local x, z = position.X, position.Z
	local _, distance = nearestTarget(x, z)
	local edgeDistance = if distance == math.huge then math.huge else math.max(0, distance - boss.kind.radius)
	local brain = boss.brain
	for _, event in BossBrain.step(brain, dt, EnemySim.getHealthShare(boss.id), edgeDistance) do
		if event.kind == "Phase" then
			applyPhase(boss)
			local announce = phaseOf(boss).announce
			if announce then
				notifyParticipants(announce)
			end
			sendState(true)
		elseif event.kind == "Windup" then
			windup(boss, attackOf(boss, event.attackId), x, z)
		elseif event.kind == "Strike" then
			strike(boss, attackOf(boss, event.attackId), x, z, event.burst)
		end
	end
	local attackId = brain.attackId
	if brain.state == "Act" and attackId then
		local attack = attackOf(boss, attackId)
		if attack.kind == "Dash" then
			dashStep(boss, attack, x, z, dt)
		end
	end
	if BossBrain.isHolding(brain) then
		EnemySim.setGoal(boss.id, EnemySim.getPosition(boss.id) or position) -- stands still (after this step's dash)
	elseif phaseOf(boss).roam then
		roamStep(boss, x, z)
	else
		EnemySim.setGoal(boss.id, nil)
	end
	orbitStep(boss, x, z, at)
end

local function onStepped(dt: number, at: number)
	if #pendingSpawns > 0 then
		spawnPending()
	end
	if #bosses == 0 then
		return
	end
	collectTargets()
	for index = #bosses, 1, -1 do
		local boss = bosses[index]
		if EnemySim.isAlive(boss.id) then
			stepBoss(boss, dt, at)
		end
	end
	sendTelegraphs()
end

local function onEnemyKilled(info: EnemySim.KillInfo)
	if not info.boss then
		return
	end
	local wave = false
	for index = #bosses, 1, -1 do
		if bosses[index].id == info.id then
			wave = bosses[index].wave
			table.remove(bosses, index)
		end
	end
	sendState(true)
	if not wave or victoryQueued or #pendingSpawns > 0 then
		return
	end
	for _, boss in bosses do
		if boss.wave then
			return
		end
	end
	-- the last boss of the wave died: the run is won (after this step, not in the middle of the weapons')
	victoryQueued = true
	local kind = EnemyKinds.get(info.enemyId)
	notifyParticipants(`{if kind then kind.displayName else "The boss"} is slain!`)
	task.defer(function()
		victoryQueued = false
		if RunDirector.isOngoing() then
			RunDirector.endRun("Victory")
		end
	end)
end

local function clear()
	table.clear(bosses)
	table.clear(pendingSpawns)
	telegraphs = {}
	bossWaveStarted = false
	sendState(true)
end

-- Lifecycle -------------------------------------------------------------------------

function BossService.init()
	RunDirector.RunStarted:Connect(clear)
	RunDirector.RunEnded:Connect(clear)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Shop" then
			-- a wave ends: enemies fade away, so do bosses called for a test
			table.clear(bosses)
			table.clear(pendingSpawns)
			sendState(true)
		end
	end)
	RunDirector.SyncRequested:Connect(function()
		sendState(true)
	end)
	EnemySim.Stepped:Connect(onStepped)
	EnemySim.EnemyKilled:Connect(onEnemyKilled)
	RunService.Heartbeat:Connect(function(dt: number)
		if
			not bossWaveStarted
			and RunDirector.getPhase() == "Running"
			and RunDirector.getWave() >= RunSchedule.waveCount()
		then
			startBossWave()
		end
		stateTimer += dt
		if stateTimer >= BossWave.stateInterval then
			stateTimer = 0
			sendState()
		end
	end)
end

-- Commands --------------------------------------------------------------------------

-- Spawns the next boss of Config.Enemies.bossWave.order near `around` (AdminService "SpawnBoss"), in any wave; its
-- death does not end the run. Returns its name, or nil at the hard cap.
function BossService.spawnNext(around: Vector3): string?
	local order = BossWave.order
	nextDebugBoss = nextDebugBoss % #order + 1
	local bossId = order[nextDebugBoss]
	local kind = EnemyKinds.get(bossId)
	if not kind then
		return nil
	end
	local x, z = spotNear(around.X, around.Z, kind.radius)
	return if spawnBoss(bossId, x, z, false, 1) then kind.displayName else nil
end

-- Every living boss loses `share` of its max HP (AdminService "HurtBoss", to see the phases). Returns how many.
function BossService.hurtAll(share: number, source: Player?): number
	local count = 0
	for _, boss in table.clone(bosses) do
		if EnemySim.isAlive(boss.id) then
			count += 1
			EnemySim.damage(boss.id, EnemySim.getMaxHealth(boss.id) * share, source)
		end
	end
	return count
end

-- Queries ---------------------------------------------------------------------------

-- The living bosses: enemy id, boss id, phase and BossBrain state (tests).
function BossService.getBosses(): { { id: number, bossId: string, phase: number, state: string, wave: boolean } }
	local list = {}
	for _, boss in bosses do
		table.insert(list, {
			id = boss.id,
			bossId = boss.bossId,
			phase = boss.brain.phase,
			state = boss.brain.state,
			wave = boss.wave,
		})
	end
	return list
end

-- Bosses waiting to appear (their markers show).
function BossService.getPendingCount(): number
	return #pendingSpawns
end

return BossService
