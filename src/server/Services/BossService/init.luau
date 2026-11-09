--!strict
-- The boss wave (DESIGN.md section 7, WP10, like Brotato's wave 20): when the last wave starts, red crosses show
-- where its boss comes (Config.Enemies.bossWave), then one boss picked at random appears (bossWave.count). Bosses are
-- enemies in EnemySim with a list of states (Config.Enemies.bosses, kind.boss, after Brotato 1.2.0.1's boss scenes);
-- BossBrain decides when the state changes and when its attack winds up and strikes, this service carries it out:
-- the boss's walk (following, roaming, near or away from the player), its speed per state, charges with the shots
-- fired on the way, bullets, pillars and slashes (warnings on the floor, BossTelegraphs, that strike once while their
-- hitbox is on), summons and the Predator's turning arm of projectiles. Killing every boss of the wave wins the run
-- (RunDirector.endRun("Victory")), as does surviving the wave (RunFlow). Sends BossState (HP bar, state) to the
-- participants.
-- Since WP10 part 2 also the champions of the elite waves (Config.Enemies.champions, eliteWaves, after Brotato's
-- elites): one comes in wave 11 or 12 the same way, grows with the wave like other enemies and drops a legendary
-- crate (LootService) without ending the run.
-- Since B11 the danger level decides (DangerService, Util/DangerRules): elite waves come from its plan (none below
-- danger 2), wave 20 brings two bosses on danger 5, and in endless mode killing the bosses does not end the run;
-- every 10th wave after 20 is a boss wave with every boss and extra champions.
-- Uses EnemySim, RunDirector, DangerService, CombatService, MapService, RandomService, SpawnDirector (summons) and StatService;
-- AdminService spawns and hurts bosses and champions for tests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DangerRules = require(Shared.Util.DangerRules)
local Enemies = require(Shared.Config.Enemies)
local EnemyKinds = require(Shared.Util.EnemyKinds)
local Net = require(Shared.Net)
local RunSchedule = require(Shared.Util.RunSchedule)
local StatMath = require(Shared.Util.StatMath)
local SegmentCircle = require(Shared.Util.SegmentCircle)
local Types = require(Shared.Net.Types)

local CombatService = require(script.Parent.CombatService)
local DangerService = require(script.Parent.DangerService)
local EnemySim = require(script.Parent.EnemySim)
local World = require(script.Parent.EnemySim.World)
local MapService = require(script.Parent.MapService)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local StatService = require(script.Parent.StatService)
local SpawnDirector = require(script.Parent.SpawnDirector)
local SpawnRules = require(script.Parent.SpawnDirector.SpawnRules)
local BossBrain = require(script.BossBrain)

local BossWave = Config.Enemies.bossWave
local EliteWaves = Config.Enemies.eliteWaves
local Projectiles = Config.Enemies.bossProjectiles
local PLAYER_RADIUS = Config.Simulation.playerRadius
local SPAWN_TRIES = 16
local AREA_TRIES = 5 -- Brotato ZoneService.get_rand_pos_in_area tries this many spots
local TARGET_TRIES = 8 -- Brotato's random-spot movements try this many spots
local REACHED = 1 -- studs (Brotato EQUALITY_PRECISION 10 px): a walk to a spot ends this close to it

type Target = { player: Player, x: number, z: number }

type Role = "Boss" | "Champion"

type Boss = {
	id: number,
	bossId: string,
	kind: Enemies.Enemy,
	plan: Enemies.BossPlan,
	role: Role,
	brain: BossBrain.Brain,
	wave: boolean, -- came with its wave (a boss of the boss wave: its death counts towards the victory)
	forWave: number, -- the wave it grows like: its projectiles add damagePerWave for every wave after the first
	damageMultiplier: number, -- contact damage
	attackMultiplier: number, -- projectiles: danger level, Enemy Damage, co-op and the early-wave share
	speedFactor: number, -- from the team's Enemy Speed at spawn; the state's speedPercent adds to it
	-- walking
	goalX: number?, -- the spot it walks to (Roam, AroundPlayer)
	goalZ: number?,
	range: number, -- AroundPlayer, KeepDistance: rolled when the state starts
	moveX: number, -- unit direction of its last walk (aim "Movement")
	moveZ: number,
	lastX: number,
	lastZ: number,
	-- a charge
	dirX: number,
	dirZ: number,
	chargeHit: { [Player]: boolean },
	-- the Predator's arm
	orbitStartedAt: number?,
	orbitAt: number,
	orbitAngle: number,
	orbitRate: number,
}

local BossService = {}

local bosses: { Boss } = {}
type Pending = { bossId: string, role: Role, x: number, z: number, at: number, share: number, wave: number }

local pendingSpawns: { Pending } = {}
local bossWavesStarted: { [number]: boolean } = {}
local eliteWavesStarted: { [number]: boolean } = {} -- B11: the plan comes from DangerService
local nextDebugChampion = 0
local victoryQueued = false
local nextDebugBoss = 0
local stateTimer = 0
local sentEmpty = true
local telegraphs: { Types.BossTelegraph } = {}
local targets: { Target } = {}
local orbitHits: { [Player]: boolean } = {}

-- Pillars and slashes: a circle or a strip from x/z along dx/dz that moves at vx/vz from startsAt and hurts each player
-- inside it once between hitsAt and endsAt.
type Hazard = {
	x: number,
	z: number,
	vx: number,
	vz: number,
	radius: number,
	dx: number?,
	dz: number?,
	length: number?,
	startsAt: number,
	hitsAt: number,
	endsAt: number,
	damage: number,
	hit: { [Player]: boolean },
}
local hazards: { Hazard } = {}

local bounds = (function()
	local arena = MapService.getArenaBounds()
	local center = arena.center
	return {
		minX = center.X - arena.halfX,
		maxX = center.X + arena.halfX,
		minZ = center.Z - arena.halfZ,
		maxZ = center.Z + arena.halfZ,
	}
end)()
local obstacles = MapService.getObstacles()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function roll(): number
	return RandomService.number("Combat")
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

local function clampToArena(x: number, z: number, margin: number): (number, number)
	return math.clamp(x, bounds.minX + margin, bounds.maxX - margin),
		math.clamp(z, bounds.minZ + margin, bounds.maxZ - margin)
end

-- Telegraphs and hazards ----------------------------------------------------------------

local function sendTelegraphs()
	if #telegraphs == 0 then
		return
	end
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("BossTelegraphs", player, telegraphs)
	end
	telegraphs = {}
end

-- A pillar or slash from now on: its warning on the floor and its hit window (Config.Enemies.bossProjectiles).
local function addHazard(
	x: number,
	z: number,
	vx: number,
	vz: number,
	radius: number,
	hitFrom: number,
	hitUntil: number,
	damage: number,
	dx: number?,
	dz: number?,
	length: number?
)
	local at = now()
	table.insert(hazards, {
		x = x,
		z = z,
		vx = vx,
		vz = vz,
		radius = radius,
		dx = dx,
		dz = dz,
		length = length,
		startsAt = at,
		hitsAt = at + hitFrom,
		endsAt = at + hitUntil,
		damage = damage,
		hit = {},
	})
	table.insert(telegraphs, {
		shape = if length then "Line" else "Circle",
		x = x,
		z = z,
		radius = radius,
		dx = dx,
		dz = dz,
		length = length,
		startsAt = at,
		hitsAt = at + hitFrom,
		vx = if vx ~= 0 then vx else nil,
		vz = if vz ~= 0 then vz else nil,
	})
end

local function insideHazard(hazard: Hazard, at: number, x: number, z: number): boolean
	local reach = hazard.radius + PLAYER_RADIUS
	local age = at - hazard.startsAt
	local hx, hz = hazard.x + hazard.vx * age, hazard.z + hazard.vz * age
	local dx, dz, length = hazard.dx, hazard.dz, hazard.length
	if dx and dz and length then
		local along = math.clamp((x - hx) * dx + (z - hz) * dz, 0, length)
		return (x - hx - dx * along) ^ 2 + (z - hz - dz * along) ^ 2 <= reach * reach
	end
	return (x - hx) ^ 2 + (z - hz) ^ 2 <= reach * reach
end

-- Hurts the players inside hazards whose hitbox is on (once each) and drops the ones that are over.
local function stepHazards(at: number)
	for index = #hazards, 1, -1 do
		local hazard = hazards[index]
		if at < hazard.hitsAt then
			continue
		end
		for _, target in targets do
			if not hazard.hit[target.player] and insideHazard(hazard, at, target.x, target.z) then
				hazard.hit[target.player] = true
				hurt(target.player, hazard.damage)
			end
		end
		if at >= hazard.endsAt then
			table.remove(hazards, index)
		end
	end
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
			phase = boss.brain.state,
			phaseCount = #boss.plan.states,
			orbitStartedAt = boss.orbitStartedAt,
			orbitAt = if boss.orbitStartedAt then boss.orbitAt else nil,
			orbitAngle = if boss.orbitStartedAt then boss.orbitAngle else nil,
			orbitRate = if boss.orbitStartedAt then boss.orbitRate else nil,
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
	return clampToArena(x, z, radius)
end

local function stateOf(boss: Boss): Enemies.BossState
	return boss.plan.states[boss.brain.state]
end

-- The angle of the Predator's arm right now.
local function orbitAngle(boss: Boss, at: number): number
	return boss.orbitAngle + (at - boss.orbitAt) * boss.orbitRate
end

-- A new state: its speed, a fresh walk and (Predator) a faster arm.
local function applyState(boss: Boss)
	local state = stateOf(boss)
	EnemySim.setSpeedFactor(boss.id, boss.speedFactor * math.max(0, 1 + (state.speedPercent or 0) / 100))
	boss.goalX, boss.goalZ = nil, nil
	boss.range = (state.range or 0) + (roll() * 2 - 1) * (state.rangeRandom or 0)
	EnemySim.setGoal(boss.id, nil)
	local multiplier = state.orbitTurnMultiplier
	if multiplier and boss.orbitStartedAt then
		local at = now()
		boss.orbitAngle = orbitAngle(boss, at)
		boss.orbitAt = at
		boss.orbitRate *= multiplier
	end
end

-- Puts boss or champion `bossId` at x/z with this run's multipliers: a champion also grows like an enemy of `wave`
-- (SpawnRules.growth). `share` of its HP. Returns its enemy id, or nil at the hard cap.
local function spawnUnit(
	bossId: string,
	x: number,
	z: number,
	role: Role,
	wave: boolean,
	share: number,
	forWave: number
): number?
	local kind = EnemyKinds.get(bossId)
	local plan = kind and kind.boss
	if not (kind and plan) then
		return nil
	end
	local dangerHp, dangerDamage, dangerSpeed = DangerService.multipliers(forWave)
	local earlyHp, earlyDamage = DangerRules.bossEarlyShares(forWave)
	local players = #RunDirector.getParticipants()
	local hpGrowth, damageGrowth = 1, 1
	if role == "Champion" then
		hpGrowth, damageGrowth = SpawnRules.growth(bossId, forWave)
	end
	local hpMultiplier = share
		* earlyHp
		* hpGrowth
		* dangerHp
		* StatMath.enemyFactor(StatService.getTeamStat("enemyHp"))
		* SpawnRules.coopHealth(players)
	local attackMultiplier = earlyDamage
		* dangerDamage
		* StatMath.enemyFactor(StatService.getTeamStat("enemyDamage"))
		* SpawnRules.coopDamage(players)
	local damageMultiplier = damageGrowth * attackMultiplier
	local speedFactor = dangerSpeed * StatMath.enemyFactor(StatService.getTeamStat("enemySpeed"))
	local id = EnemySim.spawn(bossId, x, z, hpMultiplier, damageMultiplier, nil, nil, speedFactor)
	if not id then
		return nil
	end
	local at = now()
	local boss: Boss = {
		id = id,
		bossId = bossId,
		kind = kind,
		plan = plan,
		role = role,
		brain = BossBrain.new(plan, roll),
		wave = wave,
		forWave = forWave,
		damageMultiplier = damageMultiplier,
		attackMultiplier = attackMultiplier,
		speedFactor = speedFactor,
		goalX = nil,
		goalZ = nil,
		range = 0,
		moveX = 1,
		moveZ = 0,
		lastX = x,
		lastZ = z,
		dirX = 1,
		dirZ = 0,
		chargeHit = {},
		orbitStartedAt = if plan.orbit then at else nil,
		orbitAt = at,
		orbitAngle = 0,
		orbitRate = if plan.orbit then plan.orbit.turnSpeed * (if roll() < 0.5 then -1 else 1) else 0,
	}
	table.insert(bosses, boss)
	applyState(boss)
	notifyParticipants(if role == "Boss" then `{kind.displayName} awakens!` else `{kind.displayName} arrives!`)
	sendState(true)
	return id
end

-- Red crosses where `ids` will appear (next to a random living player), then they come after introSeconds.
local function announceArrival(ids: { string }, role: Role, share: number, introSeconds: number, message: string)
	collectTargets()
	local anchor = targets[1]
	if #targets > 1 then
		anchor = targets[RandomService.stream("Spawns"):NextInteger(1, #targets)]
	end
	local center = Config.Map.arena.center
	local ax, az = if anchor then anchor.x else center.X, if anchor then anchor.z else center.Z
	local at = now() + introSeconds
	local wave = RunDirector.getWave()
	local points = {}
	for _, bossId in ids do
		local kind = EnemyKinds.get(bossId)
		local x, z = spotNear(ax, az, if kind then kind.radius else 4)
		table.insert(pendingSpawns, { bossId = bossId, role = role, x = x, z = z, at = at, share = share, wave = wave })
		table.insert(points, x)
		table.insert(points, z)
	end
	local markers: Types.SpawnMarkers = { points = points, spawnsAt = at }
	for _, player in RunDirector.getParticipants() do
		Net.fireClient("SpawnMarkers", player, markers)
	end
	notifyParticipants(message)
end

-- A boss wave started: pick its bosses (B11: two on danger 5, every boss in endless boss waves) and show where they
-- come.
local function startBossWave(wave: number)
	bossWavesStarted[wave] = true
	local order = BossWave.order
	local first = RandomService.stream("Spawns"):NextInteger(1, #order)
	local count = DangerRules.bossCount(DangerService.getDanger(), wave)
	local ids = {}
	for k = 1, count do
		table.insert(ids, order[(first + k - 2) % #order + 1])
	end
	announceArrival(ids, "Boss", DangerRules.bossShare(count), BossWave.introSeconds, "The boss wave begins!")
end

-- An elite wave started (B11: planned by DangerService): its champions come after red crosses.
local function startEliteWave(wave: number, ids: { string })
	eliteWavesStarted[wave] = true
	local message = if #ids > 1
		then `An elite wave! {#ids} champions approach.`
		else "An elite wave! A champion approaches."
	announceArrival(ids, "Champion", 1, EliteWaves.introSeconds, message)
end

local function spawnPending()
	local at = now()
	for index = #pendingSpawns, 1, -1 do
		local entry = pendingSpawns[index]
		if at >= entry.at then
			table.remove(pendingSpawns, index)
			spawnUnit(entry.bossId, entry.x, entry.z, entry.role, true, entry.share, entry.wave)
		end
	end
end

-- Attacks ---------------------------------------------------------------------------

-- Damage of one projectile of `attack` (Brotato: damage + damagePerWave per wave after the first, then the enemy
-- damage factors).
local function projectileDamage(boss: Boss, attack: Enemies.BossAttack): number
	local base = (attack.damage or 1) + (attack.damagePerWave or 1) * math.max(0, boss.forWave - 1)
	return base * boss.attackMultiplier
end

-- One projectile at px/pz flying along `angle` (radians on the x/z plane).
local function spawnProjectile(attack: Enemies.BossAttack, damage: number, px: number, pz: number, angle: number)
	local dx, dz = math.cos(angle), math.sin(angle)
	local speed = attack.projectileSpeed or 0
	local kind = attack.projectile or "Bullet"
	if kind == "Bullet" then
		local bullet = Projectiles.bullet
		EnemySim.fireShot(px, pz, dx, dz, speed, bullet.range, bullet.radius, damage)
	elseif kind == "Pillar" then
		local pillar = Projectiles.pillar
		addHazard(px, pz, dx * speed, dz * speed, pillar.radius, pillar.hitFrom, pillar.hitUntil, damage)
	else
		local slash = Projectiles.slash
		local from = slash.from + (if kind == "SlashAhead" then slash.aheadOffset else 0)
		addHazard(
			px + dx * from,
			pz + dz * from,
			dx * speed,
			dz * speed,
			slash.halfWidth,
			slash.hitFrom,
			slash.hitUntil,
			damage,
			dx,
			dz,
			slash.to - slash.from
		)
	end
end

-- Brotato ShootingAttackBehavior.shoot(): where each projectile appears and where it flies.
local function shoot(boss: Boss, attack: Enemies.BossAttack, x: number, z: number)
	local target = nearestTarget(x, z)
	local tx, tz = if target then target.x else x + boss.moveX, if target then target.z else z + boss.moveZ
	if attack.aim == "Movement" then
		tx, tz = x + boss.moveX, z + boss.moveZ
	end
	local damage = projectileDamage(boss, attack)
	local count = attack.count or 1
	local spawnHalf = (attack.spawnSpread or 0) / 2
	local spread = attack.spread or 0
	for index = 0, count - 1 do
		local px, pz = x, z
		if attack.onTarget then
			px, pz = tx, tz
		end
		if attack.onBorders then
			local angle = if attack.constantSpread then index * 2 * math.pi / count else roll() * 2 * math.pi
			px, pz = px + math.cos(angle) * spawnHalf, pz + math.sin(angle) * spawnHalf
		elseif not (attack.oneOnTarget and index == 0) then
			px, pz = px + (roll() * 2 - 1) * spawnHalf, pz + (roll() * 2 - 1) * spawnHalf
		end
		local base = math.atan2(tz - pz, tx - px)
		local angle = base + (roll() * 2 - 1) * spread
		if attack.constantSpread and count > 1 then
			angle = base - spread + index * 2 * spread / (count - 1)
		end
		if attack.randomDirection then
			angle = roll() * 2 * math.pi - math.pi
		end
		if attack.aim == "Away" then
			angle = math.atan2(pz - z, px - x)
		end
		spawnProjectile(attack, damage, px, pz, angle)
	end
end

-- Brotato SpawningAttackBehavior (spawn_in_radius_around_unit): each at a random spot of a square spawnArea wide
-- around the boss, kept inside the arena.
local function summon(attack: Enemies.BossAttack, x: number, z: number)
	local enemyId = attack.enemy
	local summoned = if enemyId then EnemyKinds.get(enemyId) else nil
	if not (enemyId and summoned) then
		return
	end
	local half = (attack.spawnArea or 0) / 2
	local cx, cz = clampToArena(x, z, math.min(half, (bounds.maxX - bounds.minX) / 2))
	for _ = 1, attack.spawnCount or 1 do
		for _ = 1, AREA_TRIES do
			local sx, sz = clampToArena(cx + (roll() * 2 - 1) * half, cz + (roll() * 2 - 1) * half, summoned.radius)
			if isFree(sx, sz, summoned.radius) then
				SpawnDirector.spawnAt(enemyId, sx, sz)
				break
			end
		end
	end
end

-- The wind-up of an attack: the boss flashes red; a charge fixes its direction at the nearest player now.
local function windup(boss: Boss, attack: Enemies.BossAttack, x: number, z: number)
	if attack.kind == "Charge" then
		local target = nearestTarget(x, z)
		local dx, dz = if target then target.x - x else boss.moveX, if target then target.z - z else boss.moveZ
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 1e-3 then
			dx, dz, length = boss.moveX, boss.moveZ, 1
		end
		boss.dirX, boss.dirZ = dx / length, dz / length
	end
	EnemySim.setMode(boss.id, World.MODE_WINDUP, boss.dirX, boss.dirZ)
end

local function strike(boss: Boss, attack: Enemies.BossAttack, x: number, z: number)
	if attack.kind == "Charge" then
		table.clear(boss.chargeHit)
		boss.moveX, boss.moveZ = boss.dirX, boss.dirZ
		EnemySim.setMode(boss.id, World.MODE_RUSH, boss.dirX, boss.dirZ)
		return
	end
	EnemySim.setMode(boss.id, World.MODE_WALK)
	if attack.kind == "Shoot" then
		shoot(boss, attack, x, z)
	elseif attack.kind == "Spawn" then
		summon(attack, x, z)
	end
	local extra = stateOf(boss).extraShot
	if extra then
		shoot(boss, extra, x, z)
	end
end

-- One step of a charge: along its direction at its walking speed + chargeSpeed, sliding along the arena edge and
-- stopped by obstacles; hurts every player on its way once with its contact damage.
local function chargeStep(boss: Boss, attack: Enemies.BossAttack, x: number, z: number, dt: number)
	local radius = boss.kind.radius
	local walk = boss.kind.speed * boss.speedFactor * math.max(0, 1 + (stateOf(boss).speedPercent or 0) / 100)
	local move = (walk + (attack.chargeSpeed or 0)) * dt
	local nx, nz = clampToArena(x + boss.dirX * move, z + boss.dirZ * move, radius)
	for _, obstacle in obstacles do
		if (nx - obstacle.x) ^ 2 + (nz - obstacle.z) ^ 2 < (obstacle.radius + radius) ^ 2 then
			nx, nz = x, z
			break
		end
	end
	local sx, sz = nx - x, nz - z
	local length = math.sqrt(sx * sx + sz * sz)
	if length > 1e-3 then
		EnemySim.teleport(boss.id, Vector3.new(nx, 0, nz))
		local reach = radius + PLAYER_RADIUS
		local damage = boss.kind.contactDamage * boss.damageMultiplier
		for _, target in targets do
			if
				not boss.chargeHit[target.player]
				and SegmentCircle.entry(x, z, sx / length, sz / length, length, target.x, target.z, reach) ~= nil
			then
				boss.chargeHit[target.player] = true
				hurt(target.player, damage)
			end
		end
	end
end

-- Walking ---------------------------------------------------------------------------

-- A random free spot from `pick`, or the last one tried (Brotato tries 8 and then pushes it out).
local function freeSpot(boss: Boss, pick: () -> (number, number)): (number, number)
	local x, z = pick()
	for _ = 1, TARGET_TRIES do
		if isFree(x, z, boss.kind.radius) then
			return x, z
		end
		x, z = pick()
	end
	return x, z
end

-- Where the boss walks in its state (Brotato's movement behaviors); nil goal = straight at the nearest player.
local function walk(boss: Boss, x: number, z: number)
	local state = stateOf(boss)
	local movement = state.movement
	local target = nearestTarget(x, z)
	local margin = boss.kind.radius
	if movement == "Follow" then
		EnemySim.setGoal(boss.id, nil)
		return
	end
	local gx, gz = boss.goalX, boss.goalZ
	local reached = gx ~= nil and gz ~= nil and (gx - x) ^ 2 + (gz - z) ^ 2 <= REACHED * REACHED
	if movement == "Roam" then
		if not (gx and gz) or reached then
			gx, gz = freeSpot(boss, function()
				return bounds.minX + margin + roll() * (bounds.maxX - bounds.minX - 2 * margin),
					bounds.minZ + margin + roll() * (bounds.maxZ - bounds.minZ - 2 * margin)
			end)
		end
	elseif movement == "AroundPlayer" then
		if (not (gx and gz) or reached) and target then
			local range = boss.range
			gx, gz = freeSpot(boss, function()
				return clampToArena(target.x + (roll() * 2 - 1) * range, target.z + (roll() * 2 - 1) * range, margin)
			end)
		end
	elseif movement == "KeepDistance" and target then
		local dx, dz = x - target.x, z - target.z
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 1e-3 then
			dx, dz, length = 1, 0, 1
		end
		gx, gz = clampToArena(target.x + dx / length * boss.range, target.z + dz / length * boss.range, margin)
		if (gx - x) ^ 2 + (gz - z) ^ 2 <= REACHED * REACHED then
			gx, gz = x, z
		end
	end
	boss.goalX, boss.goalZ = gx, gz
	if gx and gz then
		EnemySim.setGoal(boss.id, Vector3.new(gx, 0, gz))
	else
		EnemySim.setGoal(boss.id, nil)
	end
end

-- The Predator's arm: each projectile slides out to its distance and hurts the players it touches.
local function orbitStep(boss: Boss, x: number, z: number, at: number)
	local orbit = boss.plan.orbit
	local startedAt = boss.orbitStartedAt
	if not (orbit and startedAt) then
		return
	end
	table.clear(orbitHits)
	local angle = orbitAngle(boss, at)
	local cx, cz = math.cos(angle), math.sin(angle)
	local grown = (at - startedAt) * orbit.growSpeed
	local reach = orbit.hitRadius + PLAYER_RADIUS
	local damage = (orbit.damage + orbit.damagePerWave * math.max(0, boss.forWave - 1)) * boss.attackMultiplier
	for _, distance in orbit.distances do
		local r = math.min(distance, grown)
		local ox, oz = x + cx * r, z + cz * r
		for _, target in targets do
			if not orbitHits[target.player] and (target.x - ox) ^ 2 + (target.z - oz) ^ 2 <= reach * reach then
				orbitHits[target.player] = true
				hurt(target.player, damage)
			end
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
	local brain = boss.brain
	for _, event in BossBrain.step(brain, dt, EnemySim.getHealthShare(boss.id), distance) do
		if event.kind == "State" then
			applyState(boss)
			sendState(true)
		elseif event.kind == "Windup" then
			windup(boss, event.attack, x, z)
		elseif event.kind == "Strike" then
			strike(boss, event.attack, x, z)
		elseif event.kind == "ChargeShot" then
			shoot(boss, event.attack, x, z)
		elseif event.kind == "ChargeEnd" then
			EnemySim.setMode(boss.id, World.MODE_RECOVER, boss.dirX, boss.dirZ)
		end
	end
	local attack = brain.attack
	if brain.mode == "Charge" and attack then
		chargeStep(boss, attack, x, z, dt)
	elseif brain.mode == "Ready" and attack == nil then
		local mode = EnemySim.getMode(boss.id)
		if mode ~= World.MODE_WALK and mode ~= World.MODE_WINDUP then
			EnemySim.setMode(boss.id, World.MODE_WALK)
		end
	end
	if brain.mode == "Charge" or BossBrain.isHolding(brain) then
		EnemySim.setGoal(boss.id, EnemySim.getPosition(boss.id) or position) -- stands still (after this step's charge)
	else
		walk(boss, x, z)
	end
	-- the direction it walked since the last step (aim "Movement")
	local after = EnemySim.getPosition(boss.id) or position
	local mx, mz = after.X - boss.lastX, after.Z - boss.lastZ
	local moved = math.sqrt(mx * mx + mz * mz)
	if moved > 1e-3 then
		boss.moveX, boss.moveZ = mx / moved, mz / moved
	end
	boss.lastX, boss.lastZ = after.X, after.Z
	orbitStep(boss, x, z, at)
end

local function onStepped(dt: number, at: number)
	if #pendingSpawns > 0 then
		spawnPending()
	end
	if #bosses == 0 and #hazards == 0 then
		return
	end
	collectTargets()
	stepHazards(at)
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
	local role: Role? = nil
	for index = #bosses, 1, -1 do
		if bosses[index].id == info.id then
			wave = bosses[index].wave
			role = bosses[index].role
			table.remove(bosses, index)
		end
	end
	sendState(true)
	local kind = EnemyKinds.get(info.enemyId)
	if role == "Champion" then
		notifyParticipants(`{if kind then kind.displayName else "The champion"} is slain!`)
		return
	end
	if not wave or victoryQueued then
		return
	end
	if DangerService.isEndless() then
		-- B11: in endless mode the bosses' death does not end the run, nor the wave (Brotato)
		notifyParticipants(`{if kind then kind.displayName else "The boss"} is slain!`)
		return
	end
	for _, entry in pendingSpawns do
		if entry.role == "Boss" then
			return
		end
	end
	for _, boss in bosses do
		if boss.wave and boss.role == "Boss" then
			return
		end
	end
	-- the last boss of the wave died: the run is won (after this step, not in the middle of the weapons')
	victoryQueued = true
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
	table.clear(hazards)
	telegraphs = {}
	table.clear(bossWavesStarted)
	table.clear(eliteWavesStarted)
	sendState(true)
end

-- Lifecycle -------------------------------------------------------------------------

function BossService.init()
	MapService.ArenaResized:Connect(function(arena: MapService.Bounds)
		bounds.minX = arena.center.X - arena.halfX
		bounds.maxX = arena.center.X + arena.halfX
		bounds.minZ = arena.center.Z - arena.halfZ
		bounds.maxZ = arena.center.Z + arena.halfZ
	end)
	RunDirector.RunStarted:Connect(clear)
	RunDirector.RunEnded:Connect(clear)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Shop" then
			-- a wave ends: enemies fade away, so do champions and bosses called for a test, and their projectiles
			table.clear(bosses)
			table.clear(pendingSpawns)
			table.clear(hazards)
			sendState(true)
		end
	end)
	RunDirector.SyncRequested:Connect(function()
		sendState(true)
	end)
	EnemySim.Stepped:Connect(onStepped)
	EnemySim.EnemyKilled:Connect(onEnemyKilled)
	RunService.Heartbeat:Connect(function(dt: number)
		if RunDirector.getPhase() == "Running" then
			local wave = RunDirector.getWave()
			if RunSchedule.wave(wave).boss and not bossWavesStarted[wave] then
				startBossWave(wave)
			end
			local challenge = DangerService.getChallenge(wave)
			if challenge and challenge.kind == "Elite" and not eliteWavesStarted[wave] then
				startEliteWave(wave, challenge.champions)
			end
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
	return if spawnUnit(bossId, x, z, "Boss", false, 1, RunDirector.getWave()) then kind.displayName else nil
end

-- Spawns the next champion of Config.Enemies.eliteWaves.order near `around` (AdminService "SpawnChampion"), in any
-- wave, grown like one of at least eliteWaves.debugMinWave. Returns its name, or nil at the hard cap.
function BossService.spawnNextChampion(around: Vector3): string?
	local order = EliteWaves.order
	nextDebugChampion = nextDebugChampion % #order + 1
	local championId = order[nextDebugChampion]
	local kind = EnemyKinds.get(championId)
	if not kind then
		return nil
	end
	local x, z = spotNear(around.X, around.Z, kind.radius)
	local wave = math.max(RunDirector.getWave(), EliteWaves.debugMinWave)
	return if spawnUnit(championId, x, z, "Champion", false, 1, wave) then kind.displayName else nil
end

-- Candy Bag adds a random champion at this wave's real growth, independent of the danger-level elite schedule.
-- Called only by EffectService after the server's item chance succeeds; normal warning and death rewards apply.
function BossService.spawnItemChampion(player: Player): boolean
	if RunDirector.getPhase() ~= "Running" then
		return false
	end
	local order = EliteWaves.order
	local pick = RandomService.stream("Effects", player):NextInteger(1, #order)
	announceArrival({ order[pick] }, "Champion", 1, EliteWaves.introSeconds, "An extra champion approaches!")
	return true
end

-- Every living boss and champion loses `share` of its max HP (AdminService "HurtBoss", to see the phases). Returns how many.
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

-- The living bosses and champions: enemy id, boss or champion id, role, state (as phase) and BossBrain mode (tests).
function BossService.getBosses(): {
	{
		id: number,
		bossId: string,
		role: string,
		phase: number,
		state: string,
		wave: boolean,
	}
}
	local list = {}
	for _, boss in bosses do
		table.insert(list, {
			id = boss.id,
			bossId = boss.bossId,
			role = boss.role,
			phase = boss.brain.state,
			state = boss.brain.mode,
			wave = boss.wave,
		})
	end
	return list
end

-- Bosses and champions waiting to appear (their markers show).
function BossService.getPendingCount(): number
	return #pendingSpawns
end

-- The elite waves of this run and the champions coming in them (tests).
function BossService.getEliteWaves(): { [number]: { string } }
	local waves = {}
	for wave, challenge in DangerService.getPlan() do
		if challenge.kind == "Elite" then
			waves[wave] = challenge.champions
		end
	end
	return waves
end

return BossService
