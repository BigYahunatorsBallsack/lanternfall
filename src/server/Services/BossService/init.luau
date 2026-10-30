--!strict
-- The boss wave (DESIGN.md section 7, WP10, like Brotato's wave 20): when the last wave starts, red crosses show
-- where its boss comes (Config.Enemies.bossWave), then one boss picked at random appears (bossWave.count). Bosses are
-- enemies in EnemySim with a plan of phases and attacks (Config.Enemies.bosses, kind.boss); BossBrain decides when
-- each attack winds up and strikes, this service carries it out: warnings on the floor (BossTelegraphs), dashes,
-- slams, rings of shots, red circles around the players and shots that close in on them, the embers circling the
-- boss, its phase speed and roaming. Killing every boss of the wave wins the run (RunDirector.endRun("Victory")),
-- as does surviving the wave (RunFlow). Sends BossState (HP bar, phase) to the participants.
-- Since WP10 part 2 also the champions of the elite waves (Config.Enemies.champions, eliteWaves, after Brotato's
-- elites): one comes in wave 11 or 12 the same way, grows with the wave like other enemies, adds slashes, aimed and
-- scattered shots, summons and running away, and drops a legendary crate (LootService) without ending the run.
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
local Types = require(Shared.Net.Types)

local CombatService = require(script.Parent.CombatService)
local DangerService = require(script.Parent.DangerService)
local EnemySim = require(script.Parent.EnemySim)
local MapService = require(script.Parent.MapService)
local RandomService = require(script.Parent.RandomService)
local RunDirector = require(script.Parent.RunDirector)
local StatService = require(script.Parent.StatService)
local SpawnDirector = require(script.Parent.SpawnDirector)
local SpawnRules = require(script.Parent.SpawnDirector.SpawnRules)
local BossBrain = require(script.BossBrain)

local BossWave = Config.Enemies.bossWave
local EliteWaves = Config.Enemies.eliteWaves
local PLAYER_RADIUS = Config.Simulation.playerRadius
local SPAWN_TRIES = 16
local ROAM_REACHED = 4 -- studs: a roaming boss picks its next spot this close to the last one
local ROAM_MARGIN = 12 -- studs from the arena edge
local FLEE_LOOKAHEAD = 20 -- studs: a fleeing champion runs towards a spot this far away from the nearest player
local POOL_ARM_SECONDS = 0.4 -- a new pool shows this long before it hurts
local SHOWN_WINDUP = 0.2 -- seconds: shorter wind-ups of shots from its body show no warning (a spray every 0.15 s)

type Target = { player: Player, x: number, z: number }

type Role = "Boss" | "Champion"

type Boss = {
	id: number,
	bossId: string,
	kind: Enemies.Enemy,
	role: Role,
	brain: BossBrain.Brain,
	wave: boolean, -- came with its wave (a boss of the boss wave: its death counts towards the victory)
	damageMultiplier: number,
	speedFactor: number, -- from the team's Enemy Speed at spawn; the phase multiplies it
	orbitStartedAt: number?,
	-- the attack in progress
	dirX: number, -- Dash direction
	dirZ: number,
	dashLeft: number,
	dashHit: { [Player]: boolean },
	trailLeft: number, -- Dash: studs until its next pair of side projectiles
	poolLeft: number, -- Dash: studs until its next pool
	bouncesLeft: number, -- Dash: walls it may still bounce off
	leapX: number, -- Leap: where it lands
	leapZ: number,
	spots: { number }, -- Rain and Circle: flat x, z of every spot; Cleave: flat dx, dz of every slash
	roamX: number?,
	roamZ: number?,
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

-- Floor hazards that strike later than the attack that made them (Cross, March) or stay a while (pools): a circle or
-- a strip from x/z along dx/dz. Lingering ones hurt each player inside at most once per `tick`.
type Hazard = {
	x: number,
	z: number,
	radius: number,
	dx: number?,
	dz: number?,
	length: number?,
	hitsAt: number,
	endsAt: number?,
	tick: number,
	damage: number,
	lastHit: { [Player]: number },
}
local hazards: { Hazard } = {}
-- Thrown cleavers on their way out: at `at` one flies back from x/z to the champion that threw it (Boomerang).
local returns: { { id: number, x: number, z: number, at: number, attack: Enemies.BossAttack, damage: number } } = {}

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

local function circle(x: number, z: number, radius: number, seconds: number, lingerSeconds: number?)
	local at = now()
	table.insert(telegraphs, {
		shape = "Circle",
		x = x,
		z = z,
		radius = radius,
		startsAt = at,
		hitsAt = at + seconds,
		endsAt = if lingerSeconds then at + seconds + lingerSeconds else nil,
	})
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

-- A hazard striking `seconds` from now (lingering `lingerSeconds` after that), with its warning on the floor.
local function addHazard(
	x: number,
	z: number,
	radius: number,
	seconds: number,
	damage: number,
	lingerSeconds: number?,
	tick: number?,
	dx: number?,
	dz: number?,
	length: number?
)
	local at = now()
	table.insert(hazards, {
		x = x,
		z = z,
		radius = radius,
		dx = dx,
		dz = dz,
		length = length,
		hitsAt = at + seconds,
		endsAt = if lingerSeconds then at + seconds + lingerSeconds else nil,
		tick = tick or 0.5,
		damage = damage,
		lastHit = {},
	})
	if dx and dz and length then
		line(x, z, dx, dz, length, radius, seconds)
	else
		circle(x, z, radius, seconds, lingerSeconds)
	end
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
	local players = #RunDirector.getParticipants()
	local hpGrowth, damageGrowth = 1, 1
	if role == "Champion" then
		hpGrowth, damageGrowth = SpawnRules.growth(bossId, forWave)
	end
	local hpMultiplier = share
		* hpGrowth
		* dangerHp
		* StatMath.enemyFactor(StatService.getTeamStat("enemyHp"))
		* SpawnRules.playerFactor(players)
	local damageMultiplier = damageGrowth * dangerDamage * StatMath.enemyFactor(StatService.getTeamStat("enemyDamage"))
	local speedFactor = dangerSpeed * StatMath.enemyFactor(StatService.getTeamStat("enemySpeed"))
	local id = EnemySim.spawn(bossId, x, z, hpMultiplier, damageMultiplier, nil, nil, speedFactor)
	if not id then
		return nil
	end
	local boss: Boss = {
		id = id,
		bossId = bossId,
		kind = kind,
		role = role,
		brain = BossBrain.new(plan),
		wave = wave,
		damageMultiplier = damageMultiplier,
		speedFactor = speedFactor,
		orbitStartedAt = nil,
		dirX = 0,
		dirZ = 0,
		dashLeft = 0,
		dashHit = {},
		trailLeft = 0,
		poolLeft = 0,
		bouncesLeft = 0,
		leapX = x,
		leapZ = z,
		spots = {},
		roamX = nil,
		roamZ = nil,
	}
	table.insert(bosses, boss)
	applyPhase(boss)
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
	announceArrival(ids, "Champion", DangerRules.championShare(wave), EliteWaves.introSeconds, message)
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

local function attackOf(boss: Boss, attackId: string): Enemies.BossAttack
	return (boss.kind.boss :: Enemies.BossPlan).attacks[attackId]
end

local function shot(attack: Enemies.BossAttack, damage: number, x: number, z: number, dx: number, dz: number)
	EnemySim.fireShot(
		x,
		z,
		dx,
		dz,
		attack.projectileSpeed or 15,
		attack.projectileRange or 50,
		attack.projectileRadius or 0.6,
		damage
	)
end

-- Unit directions of `count` slashes or shots, flat dx, dz: evenly around (from a random turn), or a fan of `arc`
-- degrees at the nearest player (straight ahead along dirX/dirZ if nobody is alive).
local function fan(count: number, arc: number, around: boolean, x: number, z: number, out: { number })
	table.clear(out)
	local centre: number
	local step: number
	if around then
		centre = RandomService.number("Combat") * 2 * math.pi
		step = 2 * math.pi / math.max(count, 1)
	else
		local target = nearestTarget(x, z)
		centre = if target then math.atan2(target.z - z, target.x - x) else 0
		step = if count > 1 then math.rad(arc) / (count - 1) else 0
	end
	local first = if around then centre else centre - step * (count - 1) / 2
	for k = 1, count do
		local angle = first + (k - 1) * step
		table.insert(out, math.cos(angle))
		table.insert(out, math.sin(angle))
	end
	return out
end

local scratchDirections: { number } = {}

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
	elseif
		attack.kind == "Ring"
		or attack.kind == "Volley"
		or attack.kind == "Scatter"
		or attack.kind == "Summon"
		or attack.kind == "Boomerang"
		or attack.kind == "Pools"
	then
		if seconds >= SHOWN_WINDUP then
			circle(x, z, radius + 1.5, seconds)
		end
	elseif attack.kind == "Cleave" then
		-- the slashes start at its edge; their directions are fixed now, so stepping out of a strip dodges it
		fan(attack.count or 1, attack.arc or 0, attack.around == true, x, z, boss.spots)
		local spots = boss.spots
		for k = 1, #spots - 1, 2 do
			line(x, z, spots[k], spots[k + 1], radius + (attack.distance or 0), attack.radius or 1, seconds)
		end
	elseif attack.kind == "Leap" then
		-- it lands where the nearest player stands now (a shadow on the floor), if there is room
		local target = nearestTarget(x, z)
		local lx, lz = if target then target.x else x, if target then target.z else z
		lx = math.clamp(lx, bounds.minX + radius, bounds.maxX - radius)
		lz = math.clamp(lz, bounds.minZ + radius, bounds.maxZ - radius)
		if not isFree(lx, lz, radius) then
			lx, lz = x, z
		end
		boss.leapX, boss.leapZ = lx, lz
		circle(lx, lz, attack.radius or radius, seconds)
	elseif attack.kind == "March" then
		-- a row of circles from it towards the nearest player and beyond, striking one after another
		local target = nearestTarget(x, z)
		local dx, dz = if target then target.x - x else 0, if target then target.z - z else 1
		local length = math.max(math.sqrt(dx * dx + dz * dz), 1e-3)
		dx, dz = dx / length, dz / length
		local damage = attack.damage * boss.damageMultiplier
		local spacing = attack.spacing or 4
		for k = 1, attack.count or 1 do
			local cx, cz = x + dx * (radius + spacing * k), z + dz * (radius + spacing * k)
			if cx < bounds.minX or cx > bounds.maxX or cz < bounds.minZ or cz > bounds.maxZ then
				break
			end
			addHazard(cx, cz, attack.radius or 2, seconds + (k - 1) * (attack.stepSeconds or 0.1), damage)
		end
	elseif attack.kind == "Cross" then
		-- an X of two long strips on the nearest player (later ones at random spots around it), one after another
		local target = nearestTarget(x, z)
		local damage = attack.damage * boss.damageMultiplier
		local random = RandomService.stream("Combat")
		local length = attack.distance or 20
		for k = 1, attack.count or 1 do
			local cx, cz = if target then target.x else x, if target then target.z else z
			if k > 1 then
				local angle = random:NextNumber() * 2 * math.pi
				local distance = random:NextNumber() * (attack.spread or 0)
				cx, cz = cx + math.cos(angle) * distance, cz + math.sin(angle) * distance
			end
			local turn = random:NextNumber() * math.pi
			for _, extra in { 0, math.pi / 2 } do
				local dx, dz = math.cos(turn + extra), math.sin(turn + extra)
				local delay = seconds + (k - 1) * (attack.stepSeconds or 0)
				addHazard(
					cx - dx * length / 2,
					cz - dz * length / 2,
					attack.radius or 1,
					delay,
					damage,
					nil,
					nil,
					dx,
					dz,
					length
				)
			end
		end
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
	-- every other burst fills the gaps, or with spinPerBurst each burst turns further: a spiral
	local turn = if attack.spinPerBurst
		then (burst - 1) * math.rad(attack.spinPerBurst)
		else (burst - 1) * 0.5 / math.max(count, 1) * 2 * math.pi
	for k = 1, count do
		local angle = turn + (k - 1) / count * 2 * math.pi
		local dx, dz = math.cos(angle), math.sin(angle)
		shot(attack, attack.damage * boss.damageMultiplier, x + dx * radius, z + dz * radius, dx, dz)
	end
end

local function strike(boss: Boss, attack: Enemies.BossAttack, x: number, z: number, burst: number)
	local damage = attack.damage * boss.damageMultiplier
	if attack.kind == "Dash" then
		boss.dashLeft = attack.distance or 0
		boss.trailLeft = attack.trailEvery or 0
		boss.poolLeft = attack.poolEvery or 0
		boss.bouncesLeft = attack.bounces or 0
		local starting = attack.startShots or 0
		if starting > 0 then
			local radius = boss.kind.radius
			local directions = fan(starting, attack.arc or 0, false, x, z, scratchDirections)
			for k = 1, #directions - 1, 2 do
				local dx, dz = directions[k], directions[k + 1]
				shot(attack, damage, x + dx * radius, z + dz * radius, dx, dz)
			end
		end
	elseif attack.kind == "Slam" then
		local reach = (attack.radius or 0) + PLAYER_RADIUS
		for _, target in targets do
			if (target.x - x) ^ 2 + (target.z - z) ^ 2 <= reach * reach then
				hurt(target.player, damage)
			end
		end
	elseif attack.kind == "Ring" then
		ring(boss, attack, x, z, burst)
	elseif attack.kind == "Cleave" then
		local spots = boss.spots
		local length = boss.kind.radius + (attack.distance or 0)
		local reach = (attack.radius or 1) + PLAYER_RADIUS
		for _, target in targets do
			for k = 1, #spots - 1, 2 do
				-- distance from the player to the strip from (x, z) along (dx, dz)
				local dx, dz = spots[k], spots[k + 1]
				local along = math.clamp((target.x - x) * dx + (target.z - z) * dz, 0, length)
				local px, pz = x + dx * along, z + dz * along
				if (target.x - px) ^ 2 + (target.z - pz) ^ 2 <= reach * reach then
					hurt(target.player, damage)
					break
				end
			end
		end
	elseif attack.kind == "Volley" or attack.kind == "Scatter" then
		local radius = boss.kind.radius
		local count = attack.count or 1
		local directions: { number }
		if attack.kind == "Volley" then
			directions = fan(count, attack.arc or 0, false, x, z, scratchDirections)
		else
			table.clear(scratchDirections)
			local random = RandomService.stream("Combat")
			for _ = 1, count do
				local angle = random:NextNumber() * 2 * math.pi
				table.insert(scratchDirections, math.cos(angle))
				table.insert(scratchDirections, math.sin(angle))
			end
			directions = scratchDirections
		end
		for k = 1, #directions - 1, 2 do
			local dx, dz = directions[k], directions[k + 1]
			shot(attack, damage, x + dx * radius, z + dz * radius, dx, dz)
		end
	elseif attack.kind == "Leap" then
		local lx, lz = boss.leapX, boss.leapZ
		EnemySim.teleport(boss.id, Vector3.new(lx, 0, lz))
		local reach = (attack.radius or boss.kind.radius) + PLAYER_RADIUS
		for _, target in targets do
			if (target.x - lx) ^ 2 + (target.z - lz) ^ 2 <= reach * reach then
				hurt(target.player, damage)
			end
		end
		if (attack.count or 0) > 0 then
			ring(boss, attack, lx, lz, burst)
		end
	elseif attack.kind == "Boomerang" then
		-- cleavers fly out and, once at their range, back to where the champion is then
		local radius = boss.kind.radius
		local range = attack.projectileRange or 20
		local outSeconds = range / math.max(attack.projectileSpeed or 15, 1e-3)
		local directions = fan(attack.count or 1, attack.arc or 0, false, x, z, scratchDirections)
		for k = 1, #directions - 1, 2 do
			local dx, dz = directions[k], directions[k + 1]
			local sx, sz = x + dx * radius, z + dz * radius
			shot(attack, damage, sx, sz, dx, dz)
			local ex = math.clamp(sx + dx * range, bounds.minX, bounds.maxX)
			local ez = math.clamp(sz + dz * range, bounds.minZ, bounds.maxZ)
			table.insert(
				returns,
				{ id = boss.id, x = ex, z = ez, at = now() + outSeconds, attack = attack, damage = damage }
			)
		end
	elseif attack.kind == "Pools" then
		local random = RandomService.stream("Combat")
		local spread = attack.spread or 6
		for _ = 1, attack.count or 1 do
			local angle = random:NextNumber() * 2 * math.pi
			local distance = boss.kind.radius + random:NextNumber() * spread
			local px, pz = x + math.cos(angle) * distance, z + math.sin(angle) * distance
			addHazard(
				px,
				pz,
				attack.poolRadius or 3,
				POOL_ARM_SECONDS,
				damage,
				attack.poolSeconds or 4,
				attack.poolTick
			)
		end
	elseif attack.kind == "Summon" then
		local enemyId = attack.enemy
		local summoned = if enemyId then EnemyKinds.get(enemyId) else nil
		if enemyId and summoned then
			local random = RandomService.stream("Spawns")
			local spread = attack.spread or 4
			for _ = 1, attack.count or 1 do
				for _ = 1, SPAWN_TRIES do
					local angle = random:NextNumber() * 2 * math.pi
					local distance = boss.kind.radius + summoned.radius + random:NextNumber() * spread
					local sx, sz = x + math.cos(angle) * distance, z + math.sin(angle) * distance
					if isFree(sx, sz, summoned.radius) then
						SpawnDirector.spawnAt(enemyId, sx, sz)
						break
					end
				end
			end
		end
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
-- Turns a homing dash towards the nearest player, at most turnRate degrees a second.
local function steer(boss: Boss, attack: Enemies.BossAttack, x: number, z: number, dt: number)
	local target = nearestTarget(x, z)
	if not (target and attack.turnRate) then
		return
	end
	local current = math.atan2(boss.dirZ, boss.dirX)
	local wanted = math.atan2(target.z - z, target.x - x)
	local delta = (wanted - current + math.pi) % (2 * math.pi) - math.pi
	local maxTurn = math.rad(attack.turnRate) * dt
	local angle = current + math.clamp(delta, -maxTurn, maxTurn)
	boss.dirX, boss.dirZ = math.cos(angle), math.sin(angle)
end

local function dashStep(boss: Boss, attack: Enemies.BossAttack, x: number, z: number, dt: number)
	local radius = boss.kind.radius
	local damage = attack.damage * boss.damageMultiplier
	steer(boss, attack, x, z, dt)
	local move = math.min((attack.speed or 0) * dt, boss.dashLeft)
	local nx, nz = x + boss.dirX * move, z + boss.dirZ * move
	local outX = nx < bounds.minX + radius or nx > bounds.maxX - radius
	local outZ = nz < bounds.minZ + radius or nz > bounds.maxZ - radius
	local hitObstacle: typeof(obstacles[1])? = nil
	for _, obstacle in obstacles do
		if (nx - obstacle.x) ^ 2 + (nz - obstacle.z) ^ 2 < (obstacle.radius + radius) ^ 2 then
			hitObstacle = obstacle
		end
	end
	if outX or outZ or hitObstacle then
		if boss.bouncesLeft <= 0 then
			boss.dashLeft = 0
			BossBrain.endAct(boss.brain)
			return
		end
		-- bounces off the wall or pillar (Brass Ram) and bursts a ring of projectiles
		boss.bouncesLeft -= 1
		if outX then
			boss.dirX = -boss.dirX
		end
		if outZ then
			boss.dirZ = -boss.dirZ
		end
		if hitObstacle and not (outX or outZ) then
			local ox, oz = x - hitObstacle.x, z - hitObstacle.z
			local length = math.max(math.sqrt(ox * ox + oz * oz), 1e-3)
			ox, oz = ox / length, oz / length
			local along = boss.dirX * ox + boss.dirZ * oz
			boss.dirX, boss.dirZ = boss.dirX - 2 * along * ox, boss.dirZ - 2 * along * oz
		end
		local count = attack.bounceShots or 0
		for k = 1, count do
			local angle = (k - 1) / count * 2 * math.pi
			local dx, dz = math.cos(angle), math.sin(angle)
			shot(attack, damage, x + dx * radius, z + dz * radius, dx, dz)
		end
		return
	end
	boss.dashLeft -= move
	EnemySim.teleport(boss.id, Vector3.new(nx, 0, nz))
	local reach = radius + PLAYER_RADIUS
	local poolEvery = attack.poolEvery
	if poolEvery and poolEvery > 0 then
		-- leaves pools behind (Mire Jaw's mud)
		boss.poolLeft -= move
		if boss.poolLeft <= 0 then
			boss.poolLeft += poolEvery
			addHazard(
				nx,
				nz,
				attack.poolRadius or 3,
				POOL_ARM_SECONDS,
				damage,
				attack.poolSeconds or 4,
				attack.poolTick
			)
		end
	end
	local every = attack.trailEvery
	if every and every > 0 then
		-- a pair of projectiles to its sides every `every` studs (Brotato's Rhino and Mantis)
		boss.trailLeft -= move
		while boss.trailLeft <= 0 do
			boss.trailLeft += every
			for _, side in { -1, 1 } do
				local dx, dz = -boss.dirZ * side, boss.dirX * side
				shot(attack, damage, nx + dx * radius, nz + dz * radius, dx, dz)
			end
		end
	end
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

-- A fleeing champion runs to a spot away from the nearest player, inside the arena.
local function fleeStep(boss: Boss, x: number, z: number)
	local target = nearestTarget(x, z)
	if not target then
		EnemySim.setGoal(boss.id, nil)
		return
	end
	local dx, dz = x - target.x, z - target.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-3 then
		dx, dz, length = 1, 0, 1
	end
	local margin = boss.kind.radius + 1
	local gx = math.clamp(x + dx / length * FLEE_LOOKAHEAD, bounds.minX + margin, bounds.maxX - margin)
	local gz = math.clamp(z + dz / length * FLEE_LOOKAHEAD, bounds.minZ + margin, bounds.maxZ - margin)
	EnemySim.setGoal(boss.id, Vector3.new(gx, 0, gz))
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
	elseif phaseOf(boss).flee then
		fleeStep(boss, x, z)
	else
		EnemySim.setGoal(boss.id, nil)
	end
	orbitStep(boss, x, z, at)
end

local function insideHazard(hazard: Hazard, x: number, z: number): boolean
	local reach = hazard.radius + PLAYER_RADIUS
	local dx, dz, length = hazard.dx, hazard.dz, hazard.length
	if dx and dz and length then
		local along = math.clamp((x - hazard.x) * dx + (z - hazard.z) * dz, 0, length)
		return (x - hazard.x - dx * along) ^ 2 + (z - hazard.z - dz * along) ^ 2 <= reach * reach
	end
	return (x - hazard.x) ^ 2 + (z - hazard.z) ^ 2 <= reach * reach
end

-- Strikes the hazards whose time came, hurts players standing in pools, ends pools whose time ran out and sends
-- thrown cleavers back.
local function stepHazards(at: number)
	for index = #hazards, 1, -1 do
		local hazard = hazards[index]
		if at < hazard.hitsAt then
			continue
		end
		local endsAt = hazard.endsAt
		if endsAt and at >= endsAt then
			table.remove(hazards, index)
			continue
		end
		for _, target in targets do
			local last = hazard.lastHit[target.player]
			if (not last or at - last >= hazard.tick) and insideHazard(hazard, target.x, target.z) then
				hazard.lastHit[target.player] = at
				hurt(target.player, hazard.damage)
			end
		end
		if not endsAt then
			table.remove(hazards, index)
		end
	end
	for index = #returns, 1, -1 do
		local entry = returns[index]
		if at >= entry.at then
			table.remove(returns, index)
			local home = EnemySim.getPosition(entry.id)
			if home then
				local dx, dz = home.X - entry.x, home.Z - entry.z
				local length = math.sqrt(dx * dx + dz * dz)
				if length > 1e-3 then
					EnemySim.fireShot(
						entry.x,
						entry.z,
						dx / length,
						dz / length,
						entry.attack.projectileSpeed or 15,
						length,
						entry.attack.projectileRadius or 0.6,
						entry.damage
					)
				end
			end
		end
	end
end

local function onStepped(dt: number, at: number)
	if #pendingSpawns > 0 then
		spawnPending()
	end
	if #bosses == 0 and #hazards == 0 and #returns == 0 then
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
	table.clear(returns)
	telegraphs = {}
	table.clear(bossWavesStarted)
	table.clear(eliteWavesStarted)
	sendState(true)
end

-- Lifecycle -------------------------------------------------------------------------

function BossService.init()
	RunDirector.RunStarted:Connect(clear)
	RunDirector.RunEnded:Connect(clear)
	RunDirector.PhaseChanged:Connect(function(phase)
		if phase == "Shop" then
			-- a wave ends: enemies fade away, so do champions and bosses called for a test, and their pools
			table.clear(bosses)
			table.clear(pendingSpawns)
			table.clear(hazards)
			table.clear(returns)
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

-- The living bosses and champions: enemy id, boss or champion id, role, phase and BossBrain state (tests).
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
			phase = boss.brain.phase,
			state = boss.brain.state,
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
