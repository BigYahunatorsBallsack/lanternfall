--!strict
--!native
-- Enemies as plain data (DESIGN.md section 15): column arrays, a spatial hash and one step function.
-- No Roblox instances, so tests/EnemyWorld.spec.luau can run it. Owned by EnemySim, which feeds it the
-- player positions and turns the result into snapshots and signals; weapons query, damage and push it.
--
-- One step:
--   1. remove enemies that died since the last step
--   2. move each enemy towards its nearest target; ranged enemies hold their distance instead, chargers wind up
--      near a target and then rush in a straight line (modes below). Enemies slide around obstacles and give way
--      to enemies in front that are at least as heavy, so crowds queue up instead of squeezing into each other
--      (Brutes push through lighter ones; a rushing charger gives way to nobody).
--   3. push still-overlapping enemies apart; mass decides who moves more
--   4. keep enemies out of obstacles and players and inside the arena
--   5. report the strongest contact damage touching each target, rebuild the hash for queries
--   6. ranged enemies with a target in fire range count down and report shots (World.shots); EnemySim aims and
--      flies them (EnemySim/Volleys)
--   7. summoners count down while there is a target and report themselves in World.summons; EnemySim spawns the
--      enemies they call
--   8. slows run out (since B5: a slowed enemy walks and rushes at slowFactors of its speed, see World.slow)
-- Since B6 fleeing enemies (Looters, kind.flee) run away from the nearest target instead, along the wall when it is
-- close, and anchored ones (Trees, kind.anchored) never move: separation pushes only the other enemy and players
-- walk through them.
-- Since B9 (part 2) more behaviours: accelerating enemies get faster while they live (kind.accelerate), fleeing
-- shooters flee only from players inside flee.range, counter-shooters report a ring of shots when hit (World.damage,
-- kind.retaliate), pulsing enemies buff or heal the others around them (kind.pulse, step 7), eggs report themselves
-- when they hatch (World.hatches, kind.hatch), slashers wind up near a player and hit everyone in their circle
-- (kind.slash, like a charger's modes; the hit counts as contact damage) and enemies with a goal (World.setGoal: the
-- Gobbler's orb) walk to it instead of the nearest target.
-- Since WP10 bosses (kind.boss) walk like any enemy; BossService holds them still, sends them roaming (setGoal),
-- moves them during a dash (teleport) and changes their speed per phase (setSpeedFactor). Heralds and Menders skip
-- them (Brotato: bosses cannot be buffed).
-- Enemies that die between steps stay in the arrays with hp 0 until the next step; every query skips them,
-- so array indices (and the hash) stay valid until then.

local Shared = game:GetService("ReplicatedStorage").Shared
local Enemies = require(Shared.Config.Enemies)
local ShootingClock = require(Shared.Util.NativeEnemyShootingClock)
local Combat = require(Shared.Config.Combat)
local PointScale = require(Shared.Config.Stats).range.studsPerPoint
local DecayingSpeed = require(script.Parent.DecayingSpeed)
local NativePursuer = require(script.Parent.NativePursuer)
local EntryHealing = require(script.Parent.NativeEntryHealing)
local NativeMovement = require(script.Parent.NativeMovement)
local NativeCharge = require(script.Parent.NativeStraightCharge)
local SpatialHash = require(Shared.Util.SpatialHash)
local SegmentCircle = require(Shared.Util.SegmentCircle)
local StaticShapes = require(Shared.Util.StaticShapes)
local Body = require(Shared.Util.NativeBodyGeometry)
local Hurt = require(Shared.Util.NativeHurtGeometry)
local Hit = require(Shared.Util.NativeHitGeometry)
local circleEntry = SegmentCircle.entry

export type Kind = Enemies.Enemy
export type Circle = StaticShapes.Shape

export type Params = {
	cellSize: number,
	maxEnemies: number,
	playerRadius: number,
	contactMargin: number,
	separationStiffness: number,
	separationPasses: number,
	obstacleSteerMargin: number,
	keepDistanceTolerance: number,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	obstacles: { Circle },
	forbiddenCircles: { { x: number, z: number, radius: number } }?, -- native spawn exclusion zones, independent of physical capsule obstacles
	allocateId: (() -> number)?,
	referencePlayerSpeed: ((number?, number?, number?) -> number?)?, -- target player index, or fastest living player when nil
	nativeChargeAccessibility: (() -> number)?, -- source charge bonus uses only the current run accessibility speed slider
	goalsWithoutTargets: boolean?,
	collideTargets: boolean?, -- false for native pet bodies, which collide only with pets and obstacles
	seed: number?, -- for the wander points (kind.wander) and keep-distance jitter; tests pass one
}

local MAX_ID = 65535 -- ids are u16 in snapshots
local EPSILON = 1e-6
local HEAD_ON = 0.05 -- below this share of sideways movement an enemy counts as running straight at an obstacle
local GOLDEN_ANGLE = 2.399963 -- spreads the push direction of enemies standing exactly on top of each other
local GOLDEN_RATIO = 0.618034 -- spreads the first shot of ranged enemies so they do not fire in sync
local PULSE_SHOW_SECONDS = 0.5 -- clients see the ring of a buff or heal this long (mode wind-up; look only)
local HATCH_WARN_SECONDS = 1.6 -- an egg shakes (mode wind-up) this long before it hatches: Brotato's half-speed shoot animation (look only)

local World = {}
World.__index = World

-- What an enemy with a `charge` is doing (World.modes; clients see it in the snapshot flags, Net/Snapshot).
World.MODE_WALK = 0 -- also every enemy without a charge
World.MODE_WINDUP = 1 -- standing still and glowing, the rush direction is fixed
World.MODE_RUSH = 2
World.MODE_RECOVER = 3 -- standing still after the rush
local MODE_WALK, MODE_WINDUP, MODE_RUSH, MODE_RECOVER = 0, 1, 2, 3

export type World = typeof(setmetatable(
	{} :: {
		params: Params,
		count: number, -- entries in the arrays, including enemies that died since the last step
		alive: number,
		ids: { number },
		kinds: { Kind },
		typeIds: { number },
		xs: { number },
		zs: { number },
		moveInputXs: { number },
		moveInputZs: { number },
		hp: { number },
		maxHp: { number },
		contactDamage: { number }, -- damage per touch
		shotDamage: { number }, -- damage per projectile, 0 for enemies that do not shoot
		waves: { number }, -- wave at spawn, for flat enemy healing
		shootingClocks: { ShootingClock.State? },
		shotCooldown: { number }, -- seconds in fire range until the next shot
		modes: { number }, -- MODE_*
		modeTimers: { number }, -- seconds left in the wind-up or recovery; while walking: until a wind-up may start
		rushXs: { number }, -- unit rush direction, fixed when the wind-up starts
		rushZs: { number },
		rushLeft: { number }, -- studs the rush may still go
		summonTimers: { number }, -- seconds until a summoner calls again
		nativeSlows: DecayingSpeed.Slow,
		slowFactors: { number }, -- share of its speed a slowed enemy keeps, 1 when not slowed (B5)
		speedBonuses: { number },
		speedFactors: { number }, -- multiplier on its kind's speed from spawning (the team's Enemy Speed stat, B9)
		boosts: { number }, -- multiplier on its speed from accelerating (kind.accelerate), 1 otherwise (B9)
		pursuers: { NativePursuer.State? },
		nativeCharges: { NativeCharge.State? },
		nativeSpawnClocks: { ShootingClock.State? },
		boostClocks: { number }, -- seconds towards its next accelerate step
		zoneMembers: { [number]: { [number]: boolean } }, -- by Mender id: ids of the enemies in its radius (pulse.onEnter)
		buffed: { boolean }, -- a Herald made it stronger (once per enemy, shown in snapshots; B9)
		abilityTimers: { number }, -- seconds until it pulses or hatches, or its counter-shot cooldown (B9)
		goalXs: { number }, -- where it walks instead of the nearest target while hasGoal (World.setGoal, B9)
		goalZs: { number },
		hasGoal: { boolean },
		keeps: { number }, -- its own keepDistance (ranged.keepDistanceJitter) or wander range (wander.rangeJitter)
		wanderXs: { number }, -- the spot a wandering enemy walks to (kind.wander), valid while wanderLeft > 0
		wanderZs: { number },
		wanderLeft: { number }, -- seconds until it picks a new spot even if it has not arrived
		randomState: number, -- xorshift32 state for nextRandom (no Roblox Random, so the spec runs without a mock)
		slowLeft: { number }, -- seconds the slow lasts
		knockXs: { number }, -- Brotato's knockback vector in studs-scaled points (Config.Combat.knockback), 0 when none
		knockZs: { number },
		knocked: { boolean }, -- the knockback moved it faster than it walks this step: no contact damage
		contactSources: { number }, -- by target index: id of the enemy behind contacts[t] (0 for none)
		burning: { boolean }, -- shown in snapshots; the weapons (WeaponService/Afflictions) run the burn itself
		columns: { { any } }, -- every per-enemy array above, for compacting and clearing
		indexOf: { [number]: number }, -- id -> array index
		nextId: number,
		maxRadius: number, -- conservative root-based collider extent, including physical body offsets
		maxColliderRadius: number, -- original circle-radius bound for the internal body-center hash
		maxSpeed: number, -- fastest enemy speed seen, widens neighbour queries while enemies move
		hash: SpatialHash.SpatialHash,
		scratch: { number }, -- query results inside step()
		queryScratch: { number }, -- query results for callers between steps
		bodyXs: { number }, -- transient physical-center scratch, rebuilt for separation (not persistent actor columns)
		bodyZs: { number },
		contacts: { number },
		-- shots of the last step, flat: enemy id, x, z, target index, damage per shot
		shots: { number },
		shotCount: number,
		-- ids of the summoners that call enemies after the last step
		summons: { number },
		summonCount: number,
		-- ids of the eggs that hatch after the last step (B9)
		hatches: { number },
		hatchCount: number,
		strikers: { number }, -- scratch: indices of slashers that strike in this step
		rushes: { number }, -- scratch: swept rush paths, flat as enemy index, start x/z and end x/z
	},
	World
))

-- A number in [0, 1) from the world's own xorshift32 stream.
local function nextRandom(self: World): number
	local x = self.randomState
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.randomState = x
	return x / 4294967296
end

-- A charger's next cooldown: cooldownSeconds +- cooldownRandomSeconds (Brotato get_cd, rolled each time).
local function chargeCooldown(self: World, charge: Enemies.Charge): number
	local spread = charge.cooldownRandomSeconds or 0
	return math.max(0, charge.cooldownSeconds + (nextRandom(self) * 2 - 1) * spread)
end

function World.new(params: Params): World
	assert(params.maxEnemies < MAX_ID, "maxEnemies must leave room for free ids")
	local self = {
		params = params,
		nativeSlows = DecayingSpeed.new(),
		count = 0,
		alive = 0,
		ids = {},
		kinds = {},
		typeIds = {},
		xs = {},
		zs = {},
		moveInputXs = {},
		moveInputZs = {},
		hp = {},
		maxHp = {},
		contactDamage = {},
		shotDamage = {},
		waves = {},
		shotCooldown = {},
		shootingClocks = {},
		modes = {},
		modeTimers = {},
		rushXs = {},
		rushZs = {},
		rushLeft = {},
		summonTimers = {},
		slowFactors = {},
		speedFactors = {},
		speedBonuses = {},
		boosts = {},
		pursuers = {},
		nativeCharges = {},
		nativeSpawnClocks = {},
		boostClocks = {},
		zoneMembers = {},
		buffed = {},
		abilityTimers = {},
		goalXs = {},
		goalZs = {},
		hasGoal = {},
		keeps = {},
		wanderXs = {},
		wanderZs = {},
		wanderLeft = {},
		randomState = math.max(1, math.floor(params.seed or 1) % 4294967296),
		slowLeft = {},
		knockXs = {},
		knockZs = {},
		knocked = {},
		contactSources = {},
		burning = {},
		columns = {},
		indexOf = {},
		nextId = 0,
		maxRadius = 0,
		maxColliderRadius = 0,
		maxSpeed = 0,
		hash = SpatialHash.new(params.cellSize),
		scratch = {},
		queryScratch = {},
		bodyXs = {},
		bodyZs = {},
		contacts = {},
		shots = {},
		shotCount = 0,
		summons = {},
		summonCount = 0,
		hatches = {},
		hatchCount = 0,
		strikers = {},
		rushes = {},
	}
	self.columns = {
		self.ids,
		self.kinds,
		self.typeIds,
		self.xs,
		self.zs,
		self.moveInputXs,
		self.moveInputZs,
		self.hp,
		self.maxHp,
		self.contactDamage,
		self.shotDamage,
		self.waves,
		self.shotCooldown,
		self.shootingClocks,
		self.modes,
		self.modeTimers,
		self.rushXs,
		self.rushZs,
		self.rushLeft,
		self.summonTimers,
		self.slowFactors,
		self.speedFactors,
		self.speedBonuses,
		self.boosts,
		self.pursuers,
		self.nativeCharges,
		self.nativeSpawnClocks,
		self.boostClocks,
		self.buffed,
		self.abilityTimers,
		self.goalXs,
		self.goalZs,
		self.hasGoal,
		self.keeps,
		self.wanderXs,
		self.wanderZs,
		self.wanderLeft,
		self.slowLeft,
		self.knockXs,
		self.knockZs,
		self.knocked,
		self.burning,
	} :: { { any } }
	return setmetatable(self, World)
end

-- Spawning and removing -------------------------------------------------------------

-- The config damage behind a kind's shotDamage column: its projectile, its slash or its counter-shots (0 for none).
function World.baseShotDamage(kind: Kind): number
	if kind.ranged then
		return kind.ranged.projectileDamage
	elseif kind.slash then
		return kind.slash.damage
	elseif kind.retaliate then
		return kind.retaliate.projectileDamage
	elseif kind.charge then
		return kind.charge.projectileDamage or 0
	end
	return 0
end

local function allocateId(self: World): number
	repeat
		self.nextId = self.nextId % MAX_ID + 1
	until self.indexOf[self.nextId] == nil
	return self.nextId
end

-- Adds an enemy and returns its id, or nil when maxEnemies are alive. `shotDamage` is the damage of each projectile
-- of a ranged kind, the hit of a slasher or the shots of a counter-shooter (default: its config value), `speedFactor`
-- a multiplier on its kind's speed (default 1).
function World.spawn(
	self: World,
	kind: Kind,
	x: number,
	z: number,
	hp: number,
	contactDamage: number,
	shotDamage: number?,
	speedFactor: number?,
	wave: number?
): number?
	if self.alive >= self.params.maxEnemies then
		return nil
	end
	local id = if self.params.allocateId then self.params.allocateId() else allocateId(self)
	local i = self.count + 1
	self.count = i
	self.alive += 1
	self.ids[i] = id
	self.kinds[i] = kind
	self.typeIds[i] = kind.typeId
	self.xs[i] = x
	self.zs[i] = z
	self.hp[i] = hp
	self.maxHp[i] = hp
	self.contactDamage[i] = if kind.pursuer then math.round(contactDamage) else contactDamage
	local ranged = kind.ranged
	local spread = (id * GOLDEN_RATIO) % 1 -- so a group spawned together does not act in sync
	self.shotDamage[i] = shotDamage or World.baseShotDamage(kind)
	self.waves[i] = wave or 1
	self.shotCooldown[i] = if ranged then ranged.fireInterval * spread else 0
	self.shootingClocks[i] = if ranged and ranged.nativeTiming
		then ShootingClock.new(ranged.nativeTiming, function()
			return nextRandom(self)
		end)
		else nil
	self.nativeSpawnClocks[i] = if kind.nativeSpawn
		then ShootingClock.new(kind.nativeSpawn.timing, function()
			return nextRandom(self)
		end)
		else nil
	self.nativeCharges[i] = if kind.nativeCharge
		then NativeCharge.new(kind.nativeCharge, kind.mass, function()
			return nextRandom(self)
		end)
		else nil
	self.modes[i] = MODE_WALK
	-- a charger starts with a whole rolled cooldown (Brotato ChargingAttackBehavior._ready)
	self.modeTimers[i] = if kind.charge
		then chargeCooldown(self, kind.charge)
		elseif kind.slash then kind.slash.cooldownSeconds * spread
		else 0
	self.rushXs[i], self.rushZs[i], self.rushLeft[i] = 0, 0, 0
	self.summonTimers[i] = if kind.summon then kind.summon.intervalSeconds * (0.5 + 0.5 * spread) else 0
	self.slowFactors[i], self.slowLeft[i], self.burning[i] = 1, 0, false
	self.knockXs[i], self.knockZs[i], self.knocked[i] = 0, 0, false
	local speed = math.max(0, speedFactor or 1)
	self.speedFactors[i] = speed
	self.speedBonuses[i] = 0
	self.moveInputXs[i], self.moveInputZs[i] = 0, 0
	self.boosts[i], self.buffed[i], self.hasGoal[i] = 1, false, false
	self.boostClocks[i] = 0
	self.pursuers[i] = if kind.pursuer then NativePursuer.new(contactDamage) else nil
	local pursuer = self.pursuers[i]
	if pursuer and self.params.referencePlayerSpeed then
		pursuer.referenceSpeed = self.params.referencePlayerSpeed(nil, x, z)
	end
	self.zoneMembers[id] = nil
	self.goalXs[i], self.goalZs[i] = 0, 0
	local wander = kind.wander
	local stay = kind.stayInRange
	local jitter = if wander
		then wander.rangeJitter or 0
		elseif stay then stay.jitter
		elseif ranged then ranged.keepDistanceJitter or 0
		else 0
	local keep = if wander
		then wander.range or 0
		elseif stay then stay.distance
		elseif ranged then ranged.keepDistance
		else 0
	self.keeps[i] = keep + (nextRandom(self) * 2 - 1) * jitter
	if kind.nativeMovement and wander and (wander.around == "Target" or wander.around == "Offset") then
		self.keeps[i] = math.modf(self.keeps[i] / PointScale) * PointScale
	end
	self.wanderXs[i], self.wanderZs[i], self.wanderLeft[i] = x, z, 0
	if wander and wander.around == "Offset" then
		-- Brotato's FollowRandPosAroundPlayer: one offset from the target for its whole life, anywhere in the square
		-- (allow_within) or on its edge circle
		local range = self.keeps[i]
		local ox, oz = (nextRandom(self) * 2 - 1) * range, (nextRandom(self) * 2 - 1) * range
		if not wander.within then
			local length = math.sqrt(ox * ox + oz * oz)
			if length > EPSILON then
				ox, oz = ox / length * range, oz / length * range
			end
		end
		self.wanderXs[i], self.wanderZs[i] = ox, oz
	end
	self.abilityTimers[i] = if kind.pulse and kind.pulse.firstSeconds
		then kind.pulse.firstSeconds
		elseif kind.pulse then kind.pulse.intervalSeconds * (0.5 + 0.5 * spread)
		elseif kind.hatch then kind.hatch.seconds
		else 0
	self.indexOf[id] = i
	self.maxColliderRadius = math.max(self.maxColliderRadius, kind.radius, kind.hurtRadius or 0, kind.hitRadius or 0)
	self.maxRadius = math.max(self.maxRadius, Body.extent(kind), Hurt.extent(kind), Hit.extent(kind))
	self.maxSpeed = math.max(self.maxSpeed, kind.speed * speed)
	self.hash:insert(i, x, z) -- visible to queries right away
	return id
end

-- Removes dead enemies by moving the last entry into their slot. Returns true if anything moved.
local function compact(self: World): boolean
	if self.alive == self.count then
		return false
	end
	local ids, hp, indexOf, columns = self.ids, self.hp, self.indexOf, self.columns
	local i = 1
	while i <= self.count do
		if hp[i] > 0 then
			i += 1
			continue
		end
		local last = self.count
		indexOf[ids[i]] = nil
		if i ~= last then
			for _, column in columns do
				column[i] = column[last]
			end
			indexOf[ids[i]] = i
		end
		for _, column in columns do
			column[last] = nil
		end
		self.count = last - 1
	end
	return true
end

-- Removes a living enemy without a kill (a Looter escaping, B6). Returns true if it was alive.
-- The arena's walls moved (map-size effect at run start); enemies are pushed inside on their next step.
function World.setBounds(self: World, minX: number, maxX: number, minZ: number, maxZ: number)
	local p = self.params
	p.minX, p.maxX, p.minZ, p.maxZ = minX, maxX, minZ, maxZ
end

function World.remove(self: World, id: number): boolean
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 then
		return false
	end
	self.hp[i] = 0
	self.nativeSlows:remove(id)
	self.alive -= 1
	return true
end

-- Move a live actor to a disjoint faction world, retaining every AI timer and the network identity.
function World.transferTo(self: World, destination: World, id: number): boolean
	local index = self.indexOf[id]
	if
		not index
		or self.hp[index] <= 0
		or destination.indexOf[id]
		or destination.alive >= destination.params.maxEnemies
	then
		return false
	end
	local temporary = destination:spawn(
		self.kinds[index],
		self.xs[index],
		self.zs[index],
		self.maxHp[index],
		self.contactDamage[index]
	)
	if not temporary then
		return false
	end
	local target = destination.indexOf[temporary]
	for column, values in self.columns do
		destination.columns[column][target] = values[index]
	end
	destination.indexOf[temporary] = nil
	destination.indexOf[id] = target
	local slow = self.nativeSlows.targets[id]
	if slow then
		destination.nativeSlows.targets[id] = table.clone(slow)
	end
	destination.maxSpeed =
		math.max(destination.maxSpeed, self.kinds[index].speed * self.speedFactors[index] * self.boosts[index])
	self:remove(id)
	return true
end

-- Removes every enemy without reporting kills (run start and end).
function World.clear(self: World)
	self.nativeSlows:clear()
	for _, column in self.columns do
		table.clear(column)
	end
	table.clear(self.indexOf)
	table.clear(self.shots)
	table.clear(self.summons)
	table.clear(self.bodyXs)
	table.clear(self.bodyZs)
	self.shotCount = 0
	self.summonCount = 0
	self.count = 0
	self.alive = 0
	self.hash:clear()
end

-- Damage ------------------------------------------------------------------------------

-- Returns true when this hit killed the enemy, the HP it actually took (at most what was left) and the damage after
-- the enemy's damageTaken multiplier (Armored elites take less), and since B9 whether a counter-shooter that
-- survived fires its ring now (its cooldown starts). Hits on unknown or dead enemies do nothing.
function World.damage(self: World, id: number, amount: number): (boolean, number, number, boolean)
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 or not (amount > 0) then
		return false, 0, 0, false
	end
	local kind = self.kinds[i]
	local applied = amount * (kind.damageTaken or 1)
	local hp = self.hp[i]
	local left = hp - applied
	if left > 0 then
		self.hp[i] = left
		local retaliate = kind.retaliate
		if retaliate and not retaliate.rangedOnly and self.abilityTimers[i] <= 0 then
			self.abilityTimers[i] = retaliate.cooldownSeconds
			return false, applied, applied, true
		end
		return false, applied, applied, false
	end
	self.hp[i] = 0
	self.nativeSlows:remove(id)
	self.alive -= 1
	return true, hp, applied, false
end

function World.getShotDamage(self: World, id: number): number
	local i = self.indexOf[id]
	return if i then self.shotDamage[i] else 0
end

-- Queries (dead enemies are skipped; data of an enemy killed since the last step stays readable) --------------

function World.isAlive(self: World, id: number): boolean
	local i = self.indexOf[id]
	return i ~= nil and self.hp[i] > 0
end

function World.getAliveCount(self: World): number
	return self.alive
end

function World.getKind(self: World, id: number): Kind?
	local i = self.indexOf[id]
	return if i then self.kinds[i] else nil
end

function World.getPosition(self: World, id: number): (number?, number?)
	local i = self.indexOf[id]
	if not i then
		return nil, nil
	end
	return self.xs[i], self.zs[i]
end

-- Steering intent before obstacle/crowd corrections and knockback, for native anticipated targets.
function World.getMoveInput(self: World, id: number): (number, number)
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 then
		return 0, 0
	end
	return self.moveInputXs[i], self.moveInputZs[i]
end

-- Returns hp and max hp.
function World.getHealth(self: World, id: number): (number, number)
	local i = self.indexOf[id]
	if not i then
		return 0, 0
	end
	return self.hp[i], self.maxHp[i]
end

-- The HP, damage and speed multipliers the enemy was spawned with (wave and difficulty, on top of its kind's values),
-- so enemies it splits into or calls can get the same. 1, 1, 1 for unknown ids.
function World.getMultipliers(self: World, id: number): (number, number, number)
	local i = self.indexOf[id]
	if not i then
		return 1, 1, 1
	end
	local kind = self.kinds[i]
	local hpMultiplier = self.maxHp[i] / kind.hp
	local damageMultiplier = 1
	if kind.contactDamage > 0 then
		damageMultiplier = self.contactDamage[i] / kind.contactDamage
	elseif World.baseShotDamage(kind) > 0 then
		damageMultiplier = self.shotDamage[i] / World.baseShotDamage(kind)
	end
	return hpMultiplier, damageMultiplier, self.speedFactors[i]
end

-- Sets a living enemy's mode and rush direction (a boss's attack, WP10: it glows during the wind-up like a charger).
-- Only for kinds whose mode World.step does not drive (no charge, slash, pulse or hatch).
function World.setMode(self: World, id: number, mode: number, rushX: number?, rushZ: number?)
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 then
		return
	end
	self.modes[i] = mode
	if rushX and rushZ then
		self.rushXs[i], self.rushZs[i] = rushX, rushZ
	end
end

-- The enemy's mode (World.MODE_*) and its rush direction (only meaningful from the wind-up on).
function World.getMode(self: World, id: number): (number, number, number)
	local i = self.indexOf[id]
	if not i then
		return MODE_WALK, 0, 0
	end
	return self.modes[i], self.rushXs[i], self.rushZs[i]
end

-- Live hurt geometry also remains readable for enemies killed since the last compact, like getPosition.
function World.getHurtGeometry(self: World, id: number): (number?, number?, number?)
	local i = self.indexOf[id]
	if not i then
		return nil, nil, nil
	end
	local kind = self.kinds[i]
	local x, z = Hurt.center(kind, self.xs[i], self.zs[i])
	return x, z, kind.hurtRadius or kind.radius
end

-- Ids of living enemies whose circle overlaps the circle (x, z, radius), written to out[1 .. n]; returns n.
function World.queryRadius(self: World, x: number, z: number, radius: number, out: { number }): number
	local scratch = self.queryScratch
	local found = self.hash:query(x, z, radius + self.maxRadius, scratch)
	local hp, kinds, xs, zs, ids = self.hp, self.kinds, self.xs, self.zs, self.ids
	local count = 0
	for s = 1, found do
		local i = scratch[s]
		if hp[i] > 0 then
			local reach = radius + (kinds[i].hurtRadius or kinds[i].radius) -- Brotato's Hurtbox
			local hx, hz = Hurt.center(kinds[i], xs[i], zs[i])
			local dx, dz = hx - x, hz - z
			if dx * dx + dz * dz <= reach * reach then
				count += 1
				out[count] = ids[i]
			end
		end
	end
	return count
end

-- Ids of living enemies whose circle comes within `radius` of the segment (x0, z0)-(x1, z1), written to
-- out[1 .. n]; returns n. For projectiles and blades that sweep over the floor between two steps.
function World.querySegment(
	self: World,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	radius: number,
	out: { number }
): number
	local sx, sz = x1 - x0, z1 - z0
	local lengthSquared = sx * sx + sz * sz
	local scratch = self.queryScratch
	local found =
		self.hash:query((x0 + x1) / 2, (z0 + z1) / 2, math.sqrt(lengthSquared) / 2 + radius + self.maxRadius, scratch)
	local hp, kinds, xs, zs, ids = self.hp, self.kinds, self.xs, self.zs, self.ids
	local count = 0
	for s = 1, found do
		local i = scratch[s]
		if hp[i] > 0 then
			local hx, hz = Hurt.center(kinds[i], xs[i], zs[i])
			local px, pz = hx - x0, hz - z0
			local t = if lengthSquared > EPSILON then math.clamp((px * sx + pz * sz) / lengthSquared, 0, 1) else 0
			local dx, dz = px - sx * t, pz - sz * t
			local reach = radius + (kinds[i].hurtRadius or kinds[i].radius) -- Brotato's Hurtbox
			if dx * dx + dz * dz <= reach * reach then
				count += 1
				out[count] = ids[i]
			end
		end
	end
	return count
end

-- Id of the living enemy closest to (x, z) within maxRange (centre distance), and its distance.
function World.nearest(self: World, x: number, z: number, maxRange: number?): (number?, number)
	local range = maxRange or math.huge
	local bestId, bestSquared = nil, range * range
	local hp, xs, zs = self.hp, self.xs, self.zs
	for i = 1, self.count do
		if hp[i] > 0 then
			local dx, dz = xs[i] - x, zs[i] - z
			local squared = dx * dx + dz * dz
			if squared <= bestSquared then
				bestId, bestSquared = self.ids[i], squared
			end
		end
	end
	return bestId, if bestId then math.sqrt(bestSquared) else math.huge
end

-- Step ----------------------------------------------------------------------------------

-- Unit direction away from the nearest target (dx, dz: from the enemy to it, `distance` long) for a fleeing enemy at
-- (x, z): the part that runs into a wall closer than `margin` is dropped, and in a corner it slips out along the wall
-- that leads away from the target, towards the middle of the arena.
local function fleeDirection(
	p: Params,
	x: number,
	z: number,
	dx: number,
	dz: number,
	distance: number,
	margin: number
): (number, number)
	local ax, az = -dx / distance, -dz / distance
	if (x - p.minX < margin and ax < 0) or (p.maxX - x < margin and ax > 0) then
		ax = 0
	end
	if (z - p.minZ < margin and az < 0) or (p.maxZ - z < margin and az > 0) then
		az = 0
	end
	if math.abs(ax) <= EPSILON and math.abs(az) <= EPSILON then
		if math.abs(dx) < math.abs(dz) then
			ax = if (p.minX + p.maxX) / 2 >= x then 1 else -1
		else
			az = if (p.minZ + p.maxZ) / 2 >= z then 1 else -1
		end
	end
	local length = math.sqrt(ax * ax + az * az)
	return ax / length, az / length
end

-- Turns a velocity that runs into an obstacle into one that slides along its edge at the same speed.
local function slideAroundObstacles(
	obstacles: { Circle },
	x: number,
	z: number,
	vx: number,
	vz: number,
	reach: number,
	side: number
): (number, number)
	for _, obstacle in obstacles do
		local cx, cz = obstacle.x, obstacle.z
		if obstacle.halfLength then
			cx, cz = StaticShapes.closest(x, z, obstacle)
		end
		local nx, nz = x - cx, z - cz
		local distance = math.sqrt(nx * nx + nz * nz)
		if distance < obstacle.radius + reach and distance > EPSILON then
			nx, nz = nx / distance, nz / distance
			local into = vx * nx + vz * nz
			if into < 0 then
				local speed = math.sqrt(vx * vx + vz * vz)
				local sx, sz = vx - into * nx, vz - into * nz
				local sideways = math.sqrt(sx * sx + sz * sz)
				if sideways < speed * HEAD_ON then
					-- straight at the centre: pick a side by id so a crowd splits both ways
					if side % 2 == 0 then
						sx, sz = -nz, nx
					else
						sx, sz = nz, -nx
					end
					sideways = 1
				end
				vx, vz = sx / sideways * speed, sz / sideways * speed
			end
		end
	end
	return vx, vz
end

-- Moves (x, z) out of the circle (cx, cz, minDistance) along the line from its centre.
local function pushOut(
	x: number,
	z: number,
	cx: number,
	cz: number,
	minDistance: number,
	seed: number
): (number, number)
	local dx, dz = x - cx, z - cz
	local squared = dx * dx + dz * dz
	if squared >= minDistance * minDistance then
		return x, z
	end
	local distance = math.sqrt(squared)
	if distance > EPSILON then
		return cx + dx / distance * minDistance, cz + dz / distance * minDistance
	end
	local angle = seed * GOLDEN_ANGLE
	return cx + math.cos(angle) * minDistance, cz + math.sin(angle) * minDistance
end

local function pushOutObstacle(x: number, z: number, obstacle: Circle, radius: number, seed: number): (number, number)
	if obstacle.halfLength then
		return StaticShapes.pushOut(x, z, obstacle, radius, seed)
	end
	return pushOut(x, z, obstacle.x, obstacle.z, obstacle.radius + radius, seed)
end

-- How much of a knockback reaches the enemy (since B5 Brotato's knockback resistance): 1 - knockbackResistance if
-- the kind sets it, else 1 / mass above 1, so heavy enemies barely budge.
function World.knockbackShare(kind: Kind): number
	local resistance = kind.knockbackResistance
	if resistance then
		return math.clamp(1 - resistance, 0, 1)
	end
	return 1 / math.max(1, kind.mass)
end

-- Moves a living enemy by (dx, dz) times its knockback share (World.knockbackShare), keeping it out of obstacles and
-- inside the arena. For knockback. The hash follows on the next step.
function World.push(self: World, id: number, dx: number, dz: number)
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 then
		return
	end
	local p = self.params
	local kind = self.kinds[i]
	local scale = World.knockbackShare(kind)
	local radius = kind.radius
	local x, z = Body.center(kind, self.xs[i] + dx * scale, self.zs[i] + dz * scale)
	if kind.nativeObstacleCollision ~= false then
		for _, obstacle in p.obstacles do
			x, z = pushOutObstacle(x, z, obstacle, radius, id)
		end
	end
	x, z = Body.origin(kind, x, z)
	self.xs[i], self.zs[i] = NativeMovement.clampPosition(p, kind, x, z)
end

-- Knockback like Brotato (Unit.take_damage, Config.Combat.knockback): sets the enemy's knockback vector to (dx, dz),
-- in weapon units (points x studsPerPoint); with `add` it adds to the current vector instead (extra piercing
-- knockback). The enemy then glides over the next steps (World.step); resistance scales the movement, not the vector.
function World.knock(self: World, id: number, dx: number, dz: number, add: boolean?)
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 or self.kinds[i].anchored then
		return
	end
	if add then
		self.knockXs[i] += dx
		self.knockZs[i] += dz
	else
		self.knockXs[i], self.knockZs[i] = dx, dz
	end
end

-- Current knockback vector of a living enemy (weapon units), 0, 0 when none.
function World.getKnockback(self: World, id: number): (number, number)
	local i = self.indexOf[id]
	if not i then
		return 0, 0
	end
	return self.knockXs[i], self.knockZs[i]
end

-- Cap the base before additive native penalties; a stationary player still has a stat move speed.
local function baseMoveSpeed(self: World, i: number): number
	local speed = self.kinds[i].speed * self.speedFactors[i] * self.boosts[i] + self.speedBonuses[i]
	local rule = self.kinds[i].pursuer
	local state = self.pursuers[i]
	return if rule and state then NativePursuer.cap(rule, state, speed) else speed
end

-- Stable Unit speed penalties are additive in original points, hold independently, then recover at the source rate.
local function nativeSpeedFactor(self: World, i: number): number
	local points = baseMoveSpeed(self, i) / PointScale
	return self.nativeSlows:factor(self.ids[i], points)
end
function World.nativeSlow(self: World, id: number, amount: number, percent: boolean, hold: number)
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 then
		return
	end
	local points = self.kinds[i].speed * self.speedFactors[i] * self.boosts[i] / PointScale
	-- Unit.add_decaying_speed clamps and diminishes against current_stats.speed, even when Baby T-Rex caps movement.
	local percentBase = if self.pursuers[i] then math.floor(baseMoveSpeed(self, i) / PointScale) else points
	self.nativeSlows:add(id, points, if percent then percentBase * amount / 100 else amount, hold)
end

-- Slows a living enemy to `factor` (0..1) of its speed for `seconds` (B5). Slows do not stack: the stronger one wins,
-- an equal one refreshes the time (assumption, DESIGN.md section 6).
function World.slow(self: World, id: number, factor: number, seconds: number)
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 or not (seconds > 0) then
		return
	end
	factor = math.clamp(factor, 0, 1)
	local current = self.slowFactors[i]
	if factor < current or self.slowLeft[i] <= 0 then
		self.slowFactors[i], self.slowLeft[i] = factor, seconds
	elseif factor == current then
		self.slowLeft[i] = math.max(self.slowLeft[i], seconds)
	end
end

-- Marks a living enemy as burning or not, for the snapshots (the burn itself is WeaponService/Afflictions).
function World.setBurning(self: World, id: number, on: boolean)
	local i = self.indexOf[id]
	if i and self.hp[i] > 0 then
		self.burning[i] = on
	end
end

-- Whether the enemy is slowed, whether it burns and whether a Herald buffed it (B9).
function World.getStatus(self: World, id: number): (boolean, boolean, boolean)
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 then
		return false, false, false
	end
	return self.slowFactors[i] < 1 or self.nativeSlows:active(id), self.burning[i], self.buffed[i]
end

-- Makes a living enemy walk to (x, z) instead of the nearest target, or back to the target without x and z (the
-- Gobbler going for an orb, B9).
function World.setGoal(self: World, id: number, x: number?, z: number?)
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 then
		return
	end
	if x and z then
		self.goalXs[i], self.goalZs[i], self.hasGoal[i] = x, z, true
	else
		self.hasGoal[i] = false
	end
end

-- Sets the multiplier on a living enemy's speed (spawned with the team's Enemy Speed; a boss phase changes it, WP10).
function World.setSpeedFactor(self: World, id: number, factor: number)
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 then
		return
	end
	local speed = math.max(0, factor)
	self.speedFactors[i] = speed
	self.maxSpeed = math.max(self.maxSpeed, self.kinds[i].speed * speed * self.boosts[i])
end

-- Puts a living enemy at (x, z) right away (SpawnDirector moves enemies left far behind). The hash follows on the
-- next step.
function World.teleport(self: World, id: number, x: number, z: number)
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 then
		return
	end
	self.xs[i], self.zs[i] = x, z
end

-- Sweeps the whole rush segment and stops at its first collision. A fast enemy cannot jump through a player
-- or a thin obstacle between ticks; step 5 checks the travelled path even if crowd separation moves it afterward.
local function rushStep(self: World, i: number, charge: Enemies.Charge?, dt: number)
	local p = self.params
	local radius = self.kinds[i].radius
	local native = self.kinds[i].nativeCharge
	local speed = if native
		then (self.kinds[i].speed * self.speedFactors[i] * self.boosts[i] + assert(self.nativeCharges[i]).bonus)
			* self.slowFactors[i]
		else (assert(charge).speed * self.speedFactors[i] + self.speedBonuses[i]) * self.slowFactors[i]
	speed *= if native then self.nativeSlows:factor(self.ids[i], speed / PointScale) else nativeSpeedFactor(self, i)
	local move = if native then speed * dt else math.min(speed * dt, self.rushLeft[i])
	local x, z = self.xs[i], self.zs[i]
	local bx, bz = Body.center(self.kinds[i], x, z)
	local dx, dz = self.rushXs[i], self.rushZs[i]
	self.moveInputXs[i], self.moveInputZs[i] = dx * speed, dz * speed
	local stopAt: number? = nil
	if self.kinds[i].nativeObstacleCollision ~= false then
		for _, obstacle in p.obstacles do
			local entry = if obstacle.halfLength
				then StaticShapes.entry(bx, bz, dx, dz, move, obstacle, radius)
				else circleEntry(bx, bz, dx, dz, move, obstacle.x, obstacle.z, obstacle.radius + radius)
			if entry and entry < (stopAt or math.huge) then
				stopAt = entry
			end
		end
	end
	local endX, endZ = x + dx * move, z + dz * move
	local margin = NativeMovement.borderMargin(self.kinds[i])
	if margin then
		if math.abs(dx) > EPSILON and (endX < p.minX + margin or endX > p.maxX - margin) then
			local edge = if dx < 0 then p.minX + margin else p.maxX - margin
			stopAt = math.min(stopAt or move, math.max(0, (edge - x) / dx))
		end
		if math.abs(dz) > EPSILON and (endZ < p.minZ + margin or endZ > p.maxZ - margin) then
			local edge = if dz < 0 then p.minZ + margin else p.maxZ - margin
			stopAt = math.min(stopAt or move, math.max(0, (edge - z) / dz))
		end
	end
	-- Players do not stop a rush (Brotato: enemies do not collide with players); step 5 hurts everyone along the path.

	local travelled = stopAt or move
	endX, endZ = x + dx * travelled, z + dz * travelled
	local paths = self.rushes
	local at = #paths
	paths[at + 1], paths[at + 2], paths[at + 3] = i, x, z
	paths[at + 4], paths[at + 5] = endX, endZ
	self.xs[i], self.zs[i] = endX, endZ
	local left = self.rushLeft[i] - travelled
	self.rushLeft[i] = left
	if not native and (stopAt or left <= EPSILON) then
		self.modes[i] = MODE_RECOVER
		self.modeTimers[i] = assert(charge).recoverSeconds
	end
end

-- Handles a charger's modes in the steering step. Returns true if it is done for this step (winding up, rushing or
-- recovering); false lets it walk normally.
local function chargeStep(
	self: World,
	i: number,
	charge: Enemies.Charge,
	dt: number,
	dx: number,
	dz: number,
	distance: number
): boolean
	local modes, timers = self.modes, self.modeTimers
	local mode = modes[i]
	if mode == MODE_RUSH then
		rushStep(self, i, charge, dt)

		return true
	end
	local timer = timers[i] - dt
	if mode == MODE_WINDUP or mode == MODE_RECOVER then
		if timer > 0 then
			timers[i] = timer
		elseif mode == MODE_WINDUP then
			modes[i] = MODE_RUSH
			self.rushLeft[i] = charge.maxDistance
		else
			modes[i] = MODE_WALK
			-- Brotato counts the cooldown (plus the rush time) from the rush's start, so the recovery is part of it
			timers[i] = math.max(0, chargeCooldown(self, charge) - charge.recoverSeconds)
		end
		return true
	end
	timers[i] = math.max(timer, 0)
	if timer <= 0 and distance <= charge.triggerRange and distance > EPSILON then
		modes[i] = MODE_WINDUP
		timers[i] = charge.windupSeconds
		self.rushXs[i], self.rushZs[i] = dx / distance, dz / distance
		return true
	end
	return false
end

-- One step of a slasher (B9): it walks until a target is within triggerRange, then stands and winds up, strikes
-- everyone in its circle when the wind-up ends (step 5 counts the hit as contact damage) and recovers. Returns true
-- while it stands still.
local function slashStep(self: World, i: number, slash: Enemies.Slash, dt: number, distance: number): boolean
	local modes, timers = self.modes, self.modeTimers
	local mode = modes[i]
	local timer = timers[i] - dt
	if mode == MODE_WINDUP then
		if timer > 0 then
			timers[i] = timer
		else
			table.insert(self.strikers, i)
			modes[i] = MODE_RECOVER
			timers[i] = slash.recoverSeconds
		end
		return true
	elseif mode == MODE_RECOVER then
		if timer > 0 then
			timers[i] = timer
		else
			modes[i] = MODE_WALK
			timers[i] = slash.cooldownSeconds
		end
		return true
	end
	timers[i] = math.max(timer, 0)
	if timer <= 0 and distance <= slash.triggerRange then
		modes[i] = MODE_WINDUP
		timers[i] = slash.windupSeconds
		return true
	end
	return false
end

-- A Herald's buff or a Mender's heal on the enemies around enemy i (B9). A Herald buffs up to buffCount enemies,
-- picked at random among those in its radius that are not buffed yet and are no Heralds or bosses (Brotato's Buffer
-- shuffles its zone). A Mender with onEnter heals each hurt enemy once when it comes into its radius (Brotato's Healer
-- BoostZone body_entered); returns true if it healed one.
local function pulseAt(self: World, i: number, pulse: Enemies.Pulse): boolean
	if pulse.nativeEnemyEntry then
		local id = self.ids[i]
		local inside, healed =
			EntryHealing.step(self, id, self.waves[i], self.xs[i], self.zs[i], pulse, self.zoneMembers[id])
		self.zoneMembers[id] = inside
		return healed
	end

	local xs, zs, hp, maxHp, kinds = self.xs, self.zs, self.hp, self.maxHp, self.kinds
	local scratch = self.scratch
	local found = self.hash:query(xs[i], zs[i], pulse.radius + self.maxRadius, scratch)
	local candidates = {}
	local inside: { [number]: boolean }? = if pulse.onEnter then {} else nil
	local previous = if pulse.onEnter then self.zoneMembers[self.ids[i]] else nil
	local healed = false
	for s = 1, found do
		local j = scratch[s]
		if j ~= i and hp[j] > 0 then
			local reach = pulse.radius + kinds[j].radius
			local bx, bz = Body.center(kinds[j], xs[j], zs[j])
			local dx, dz = bx - xs[i], bz - zs[i]
			if dx * dx + dz * dz <= reach * reach then
				if inside then
					inside[self.ids[j]] = true
				end
				local entering = not (previous and previous[self.ids[j]])
				if (pulse.heal or pulse.healFlat) and not kinds[j].boss and (not inside or entering) then
					local healing = if pulse.healFlat
						then pulse.healFlat + (pulse.healPerWave or 0) * (self.waves[i] - 1)
						else maxHp[j] * (pulse.heal or 0)
					if hp[j] < maxHp[j] then
						healed = true
					end
					hp[j] = math.min(maxHp[j], hp[j] + healing)
				end
				if
					(pulse.buffCount or 0) > 0
					and not self.buffed[j]
					and not (kinds[j].pulse and kinds[j].pulse.buffCount)
					and not kinds[j].boss
				then
					table.insert(candidates, j)
				end
			end
		end
	end
	if inside then
		self.zoneMembers[self.ids[i]] = inside
	end
	for _ = 1, math.min(pulse.buffCount or 0, #candidates) do
		local pick = math.floor(nextRandom(self) * #candidates) + 1
		local j = candidates[pick]
		candidates[pick] = candidates[#candidates]
		candidates[#candidates] = nil
		self.buffed[j] = true
		if pulse.nativeResetStats then
			-- Unit.reset_* takes integer base health/contact damage, then EntityService rounds the final boosted stat.
			local kind = kinds[j]
			local steps = self.waves[j] - 1
			local baseHp = kind.hp + kind.hpPerWave * steps
			local baseContact = kind.contactDamage + kind.damagePerWave * steps
			maxHp[j] = math.round(math.floor(baseHp) * (maxHp[j] / baseHp) * (1 + (pulse.buffHp or 0)))
			hp[j] = maxHp[j]
			self.contactDamage[j] = if baseContact > 0
				then math.round(
					math.floor(baseContact) * (self.contactDamage[j] / baseContact) * (pulse.buffDamage or 1)
				)
				else 0
			self.shotDamage[j] = math.round(self.shotDamage[j] * (pulse.buffDamage or 1))
		else
			self.contactDamage[j] *= pulse.buffDamage or 1
			self.shotDamage[j] *= pulse.buffDamage or 1
			local bonus = maxHp[j] * (pulse.buffHp or 0)
			maxHp[j] += bonus
			hp[j] += bonus
		end
		self.speedFactors[j] *= pulse.buffSpeed or 1
		self.maxSpeed = math.max(self.maxSpeed, kinds[j].speed * self.speedFactors[j] * self.boosts[j])
	end
	return healed
end

local function rebuildHash(self: World, positionsX: { number }?, positionsZ: { number }?)
	local hash, xs, zs = self.hash, positionsX or self.xs, positionsZ or self.zs
	hash:clear()
	for i = 1, self.count do
		hash:insert(i, xs[i], zs[i])
	end
end

-- Where a wandering enemy (kind.wander, Brotato's random-position movement) walks: the spot it picked, or a new one
-- once it is within arriveStuds of it or wander.maxSeconds ran out. "Arena" picks anywhere in the arena (Junkie),
-- "Target" within its range of the nearest target on both axes (Fly). Spots inside an obstacle are re-rolled up to
-- 8 times like Brotato's forbidden zones. Returns the offset from the enemy to the spot.
local function wanderStep(
	self: World,
	i: number,
	wander: Enemies.Wander,
	dt: number,
	tx: number,
	tz: number
): (number, number)
	local p = self.params
	local x, z = self.xs[i], self.zs[i]
	local wx, wz = self.wanderXs[i], self.wanderZs[i]
	if wander.around == "Offset" then
		return tx + wx - x, tz + wz - z
	end
	local left = self.wanderLeft[i] - dt
	local arrive = wander.arriveStuds
	local kind = self.kinds[i]
	if left <= 0 or (kind.nativeMovement and wx == 0 and wz == 0) or (wx - x) ^ 2 + (wz - z) ^ 2 <= arrive * arrive then
		if kind.nativeMovement then
			wx, wz = NativeMovement.goal(p, kind, wander, self.keeps[i], tx, tz, p.forbiddenCircles, function()
				return nextRandom(self)
			end)
		else
			local radius = self.kinds[i].radius
			for _ = 1, 8 do
				if wander.around == "Target" then
					local range = self.keeps[i]
					wx = tx + (nextRandom(self) * 2 - 1) * range
					wz = tz + (nextRandom(self) * 2 - 1) * range
				else
					wx = p.minX + nextRandom(self) * (p.maxX - p.minX)
					wz = p.minZ + nextRandom(self) * (p.maxZ - p.minZ)
				end
				wx = math.clamp(wx, p.minX + radius, p.maxX - radius)
				wz = math.clamp(wz, p.minZ + radius, p.maxZ - radius)
				local blocked = false
				for _, circle in p.obstacles do
					local cx, cz = circle.x, circle.z
					if circle.halfLength then
						cx, cz = StaticShapes.closest(wx, wz, circle)
					end
					if (wx - cx) ^ 2 + (wz - cz) ^ 2 < (circle.radius + radius) ^ 2 then
						blocked = true
						break
					end
				end
				if not blocked then
					break
				end
			end
		end
		self.wanderXs[i], self.wanderZs[i] = wx, wz
		left = wander.maxSeconds
	end
	self.wanderLeft[i] = left
	return wx - x, wz - z
end

-- Advances every enemy by dt seconds towards the targets (x/z of living players, targetCount of them).
-- Returns contacts[t] = the highest contact damage touching target t, 0 if none (reused table).
-- Contacts are checked against contactXs/contactZs if given (e.g. positions corrected for network lag),
-- otherwise against the targets. Shots fired in this step are in self.shots[1 .. 5 * self.shotCount].
function World.step(
	self: World,
	dt: number,
	targetXs: { number },
	targetZs: { number },
	targetCount: number,
	contactXs: { number }?,
	contactZs: { number }?,
	targetRadii: { number }?,
	targetInputXs: { number }?,
	targetInputZs: { number }?
): { number }
	if compact(self) then
		rebuildHash(self)
	end
	local p = self.params
	local count = self.count
	local ids, kinds, xs, zs = self.ids, self.kinds, self.xs, self.zs
	local hash, scratch = self.hash, self.scratch
	local playerRadius = p.playerRadius
	local obstacles = p.obstacles
	local maxRadius = self.maxRadius

	table.clear(self.strikers)
	table.clear(self.rushes)

	-- Native Timer runs independently of target availability. Only two boosts can allocate a grown kind.
	for i = 1, count do
		local rule = kinds[i].pursuer
		local state = self.pursuers[i]
		if rule and state then
			local grown, speed, damage = NativePursuer.step(rule, state, kinds[i], dt)
			if grown then
				kinds[i] = grown
				self.speedBonuses[i] += speed
				self.contactDamage[i] = damage or self.contactDamage[i]
				self.maxColliderRadius =
					math.max(self.maxColliderRadius, grown.radius, grown.hurtRadius or 0, grown.hitRadius or 0)
				self.maxRadius = math.max(self.maxRadius, Body.extent(grown), Hurt.extent(grown), Hit.extent(grown))
				self.maxSpeed = math.max(self.maxSpeed, grown.speed * self.speedFactors[i] + self.speedBonuses[i])
			end
			local bestTarget: number? = nil
			local bestSquared = math.huge
			for t = 1, targetCount do
				local squared = (targetXs[t] - xs[i]) ^ 2 + (targetZs[t] - zs[i]) ^ 2
				if squared < bestSquared then
					bestSquared, bestTarget = squared, t
				end
			end
			state.referenceSpeed = if p.referencePlayerSpeed then p.referencePlayerSpeed(bestTarget) else nil
		end
	end
	maxRadius = self.maxRadius

	-- 1b. knockback glide (Brotato: each 60 Hz frame the vector shrinks to `decay` of itself, then moves the enemy by
	-- vector x speedPerPoint x share px/s); frames = dt x frameRate, summed as a geometric series
	local knock = Combat.knockback
	local frames = dt * knock.frameRate
	local decay = knock.decayPerFrame
	local decayed = decay ^ frames
	local frameSum = decay * (1 - decayed) / (1 - decay) -- sum of decay^k for k = 1..frames
	local moveScale = frameSum * knock.speedPerPoint / knock.frameRate
	local stopBelow = knock.stopBelow * knock.studsPerPoint
	local knockXs, knockZs, knocked = self.knockXs, self.knockZs, self.knocked
	for i = 1, count do
		local kx, kz = knockXs[i], knockZs[i]
		self.moveInputXs[i], self.moveInputZs[i] = 0, 0
		if kx == 0 and kz == 0 then
			knocked[i] = false
			continue
		end
		local kind = kinds[i]
		local share = World.knockbackShare(kind)
		xs[i] += kx * moveScale * share
		zs[i] += kz * moveScale * share
		kx, kz = kx * decayed, kz * decayed
		local length = math.sqrt(kx * kx + kz * kz)
		-- the hitbox stays off while the push is faster than the enemy walks (Enemy._physics_process)
		local walk = (
			if kind.pursuer then baseMoveSpeed(self, i) else kind.speed * self.speedFactors[i] * self.boosts[i]
		) * self.slowFactors[i]
		knocked[i] = share > 0 and length * knock.speedPerPoint * share > walk
		if length < stopBelow then
			kx, kz = 0, 0
		end
		knockXs[i], knockZs[i] = kx, kz
	end

	-- Native charge clocks run even after the last target disappears; mass/bonus changes survive column transfers.
	for i = 1, count do
		local kind = kinds[i]
		local rule, state = kind.nativeCharge, self.nativeCharges[i]
		if not rule or not state then
			continue
		end
		local dx, dz, best = 0, 0, math.huge
		for t = 1, targetCount do
			local x, z = targetXs[t] - xs[i], targetZs[t] - zs[i]
			local squared = x * x + z * z
			if squared < best then
				dx, dz, best = x, z, squared
			end
		end
		local changed = NativeCharge.step(state, rule, dt, dx, dz, targetCount > 0, function()
			return nextRandom(self)
		end, if p.nativeChargeAccessibility then p.nativeChargeAccessibility() else 1)
		if changed then
			self.speedBonuses[i] = if state.stage == "Rush" then state.bonus else 0
		end
		local mass = state.originalMass
			* (if state.stage == "Windup" or state.stage == "Rush" then rule.massMultiplier else 1)
		if kind.mass ~= mass then
			local adjusted = table.clone(kind)
			adjusted.mass = mass
			kinds[i] = adjusted
		end
		self.modes[i] = if state.stage == "Windup"
			then MODE_WINDUP
			elseif state.stage == "Rush" then MODE_RUSH
			elseif state.stage == "Recover" then MODE_RECOVER
			else MODE_WALK
		if state.rushDt > 0 then
			self.rushXs[i], self.rushZs[i], self.rushLeft[i] = state.direction, 0, math.huge
			rushStep(self, i, nil, state.rushDt)
		end
		self.maxSpeed = math.max(self.maxSpeed, kind.speed * self.speedFactors[i] * self.boosts[i] + state.bonus)
	end

	-- 2. steering
	if targetCount > 0 or p.goalsWithoutTargets then
		local tolerance = p.keepDistanceTolerance
		local steerMargin = p.obstacleSteerMargin
		-- neighbours may have moved up to one step since the hash was built
		local queryPadding = maxRadius + self.maxSpeed * dt
		for i = 1, count do
			local kind = kinds[i]
			if targetCount == 0 and not self.hasGoal[i] and not kind.wander then
				continue
			end
			local nativeChargeState = self.nativeCharges[i]
			if nativeChargeState and nativeChargeState.walkDt <= 0 then
				continue
			end
			local x, z = xs[i], zs[i]
			local bestDx, bestDz, bestSquared = 0, 0, math.huge
			local bestTarget = 1
			for t = 1, targetCount do
				local dx, dz = targetXs[t] - x, targetZs[t] - z
				local squared = dx * dx + dz * dz
				if squared < bestSquared then
					bestDx, bestDz, bestSquared = dx, dz, squared
					bestTarget = t
				end
			end
			local distance = math.sqrt(bestSquared)
			local charge = kind.charge
			if charge and chargeStep(self, i, charge, dt, bestDx, bestDz, distance) then
				continue
			end
			local slash = kind.slash
			if slash and slashStep(self, i, slash, dt, distance) then
				continue
			end
			local accelerate = kind.accelerate
			if accelerate then
				-- Brotato's Pursuer: +perStep of its base speed every everySeconds, at most maxSteps times
				local clock = self.boostClocks[i] + dt
				local steps = math.floor(clock / accelerate.everySeconds)
				if steps > 0 then
					clock -= steps * accelerate.everySeconds
					local boost = math.min(
						1 + accelerate.perStep * accelerate.maxSteps,
						self.boosts[i] + steps * accelerate.perStep
					)
					self.boosts[i] = boost
					self.maxSpeed = math.max(self.maxSpeed, kind.speed * self.speedFactors[i] * boost)
				end
				self.boostClocks[i] = clock
			end
			local toGoal = self.hasGoal[i]
			local wander = kind.wander
			if toGoal then
				bestDx, bestDz = self.goalXs[i] - x, self.goalZs[i] - z
				distance = math.sqrt(bestDx * bestDx + bestDz * bestDz)
			elseif wander then
				bestDx, bestDz = wanderStep(self, i, wander, dt, x + bestDx, z + bestDz)
				distance = math.sqrt(bestDx * bestDx + bestDz * bestDz)
			elseif kind.anticipate then
				local rule = kind.anticipate
				bestDx += (if targetInputXs then targetInputXs[bestTarget] or 0 else 0) * rule.seconds
				if not rule.horizontalOnly then
					bestDz += (if targetInputZs then targetInputZs[bestTarget] or 0 else 0) * rule.seconds
				end
				distance = math.sqrt(bestDx * bestDx + bestDz * bestDz)
			end
			if kind.nativeFollowXShare then
				bestDx *= kind.nativeFollowXShare
				distance = math.sqrt(bestDx * bestDx + bestDz * bestDz)
			end
			if distance <= EPSILON or kind.anchored then
				continue
			end
			local radius = kind.radius
			local moveDt = if nativeChargeState then nativeChargeState.walkDt else dt
			local maxMove = baseMoveSpeed(self, i) * self.slowFactors[i] * nativeSpeedFactor(self, i) * moveDt
			local dirX, dirZ = bestDx / distance, bestDz / distance
			local advance
			local ranged = kind.ranged
			local flee = kind.flee
			if toGoal or wander then
				advance = math.min(maxMove, distance)
			elseif kind.stayInRange then
				-- Brotato's StayInRangeFromPlayer: walks to the spot at its range on the line from the target
				advance = if kind.nativeMovement
						and math.abs(distance - self.keeps[i]) <= kind.nativeMovement.precision
					then 0
					else math.clamp(distance - self.keeps[i], -maxMove, maxMove)
			elseif flee and (flee.range == nil or distance < flee.range) then
				dirX, dirZ = fleeDirection(p, x, z, bestDx, bestDz, distance, flee.edgeMargin)
				advance = maxMove
			elseif ranged then
				local keep = self.keeps[i]
				if distance > keep + tolerance then
					advance = math.min(maxMove, distance - keep)
				elseif distance < keep - tolerance then
					advance = -math.min(maxMove * (ranged.retreatSpeedFactor or 1), keep - distance)
				else
					advance = 0
				end
			else
				local stopAt = if not NativeMovement.collidesTargets(p.collideTargets, kind)
					then 0
					else (kind.hitRadius or radius) + (if targetRadii
						then targetRadii[bestTarget]
						else playerRadius)
				advance = math.min(maxMove, math.max(0, distance - stopAt))
			end
			local inputSpeed = if moveDt > 0 then maxMove / moveDt else 0
			local sign = if advance < 0 then -1 elseif advance > 0 or not (ranged or kind.stayInRange) then 1 else 0
			self.moveInputXs[i], self.moveInputZs[i] = dirX * inputSpeed * sign, dirZ * inputSpeed * sign
			if advance == 0 then
				continue
			end
			local vx, vz = dirX * advance, dirZ * advance
			local bx, bz = Body.center(kind, x, z)
			if kind.nativeObstacleCollision ~= false then
				vx, vz = slideAroundObstacles(obstacles, bx, bz, vx, vz, radius + steerMargin, ids[i])
			end

			-- give way: move towards a neighbour at most until touching it
			local mass = kind.mass
			local found = hash:query(bx, bz, radius + queryPadding, scratch)
			for s = 1, found do
				local j = scratch[s]
				local other = kinds[j]
				if j ~= i and other.mass >= mass then
					local nx = bx - xs[j] - (other.nativeBodyOffsetX or 0)
					local nz = bz - zs[j] - (other.nativeBodyOffsetZ or 0)
					local gap = math.sqrt(nx * nx + nz * nz)
					local minDistance = radius + other.radius
					if gap > EPSILON and gap < minDistance + maxMove then
						nx, nz = nx / gap, nz / gap
						local towards = vx * nx + vz * nz -- negative when moving towards the neighbour
						local allowed = -math.max(gap - minDistance, 0)
						if towards < allowed then
							vx += nx * (allowed - towards)
							vz += nz * (allowed - towards)
						end
					end
				end
			end
			xs[i], zs[i] = x + vx, z + vz
		end
	end

	-- 3. separation (each pass resolves `stiffness` of every overlap; passes after the first catch chains)
	-- Cache physical centers once. The hot pair loop then retains its original two-subtraction distance calculation.
	-- Only this internal collision pass hashes centers; actor origins and the public hash are restored below/at step5.
	local originsX, originsZ = xs, zs
	xs, zs = self.bodyXs, self.bodyZs
	for i = 1, count do
		xs[i], zs[i] = Body.center(kinds[i], originsX[i], originsZ[i])
	end
	local stiffness = p.separationStiffness
	for _ = 1, p.separationPasses do
		rebuildHash(self, xs, zs)
		for i = 1, count do
			local kindI = kinds[i]
			local radiusI, massI = kindI.radius, kindI.mass
			local found = hash:query(xs[i], zs[i], radiusI + self.maxColliderRadius, scratch)
			for s = 1, found do
				local j = scratch[s]
				if j > i then
					local kindJ = kinds[j]
					local dx, dz = xs[j] - xs[i], zs[j] - zs[i]
					local minDistance = radiusI + kindJ.radius
					local squared = dx * dx + dz * dz
					if squared < minDistance * minDistance then
						local distance = math.sqrt(squared)
						local nx, nz
						if distance > EPSILON then
							nx, nz = dx / distance, dz / distance
						else
							local angle = (i + j) * GOLDEN_ANGLE
							nx, nz = math.cos(angle), math.sin(angle)
						end
						local push = (minDistance - distance) * stiffness
						local massJ = kindJ.mass
						local total = massI + massJ
						local pushI, pushJ = push * massJ / total, push * massI / total
						if kindI.anchored then
							pushI, pushJ = 0, if kindJ.anchored then 0 else push
						elseif kindJ.anchored then
							pushI, pushJ = push, 0
						end
						xs[i] -= nx * pushI
						zs[i] -= nz * pushI
						xs[j] += nx * pushJ
						zs[j] += nz * pushJ
					end
				end
			end
		end
	end

	for i = 1, count do
		originsX[i], originsZ[i] = Body.origin(kinds[i], xs[i], zs[i])
	end
	xs, zs = originsX, originsZ

	-- 4. constraints
	for i = 1, count do
		local kind = kinds[i]
		if kind.anchored then
			continue
		end
		local radius = kind.radius
		local x, z = Body.center(kind, xs[i], zs[i])
		if kind.nativeObstacleCollision ~= false then
			for _, obstacle in obstacles do
				x, z = pushOutObstacle(x, z, obstacle, radius, ids[i])
			end
		end
		x, z = Body.origin(kind, x, z)
		if NativeMovement.collidesTargets(p.collideTargets, kind) then
			for t = 1, targetCount do
				x, z = pushOut(
					x,
					z,
					targetXs[t],
					targetZs[t],
					(kind.hitRadius or radius) + (if targetRadii then targetRadii[t] else playerRadius),
					ids[i]
				)
			end
		end
		xs[i], zs[i] = NativeMovement.clampPosition(p, kind, x, z)
	end

	-- 5. contacts and the hash for queries until the next step
	local contacts = self.contacts
	local sources = self.contactSources
	table.clear(contacts)
	table.clear(sources)

	for t = 1, targetCount do
		contacts[t] = 0
		sources[t] = 0
	end
	local margin = p.contactMargin
	local damage = self.contactDamage
	local hitXs, hitZs = contactXs or targetXs, contactZs or targetZs
	for i = 1, count do
		local hit = damage[i]
		if hit > 0 and not knocked[i] then
			local hx, hz = Hit.center(kinds[i], xs[i], zs[i])
			for t = 1, targetCount do
				local reach = (kinds[i].hitRadius or kinds[i].radius)
					+ (if targetRadii then targetRadii[t] else playerRadius)
					+ margin
				local reachSquared = reach * reach
				local dx, dz = hitXs[t] - hx, hitZs[t] - hz
				if dx * dx + dz * dz <= reachSquared then
					if hit > contacts[t] then
						contacts[t] = hit
						sources[t] = ids[i]
					end
					local accelerate = kinds[i].accelerate
					if accelerate and accelerate.resetOnHit then
						self.boosts[i] = 1 -- Brotato's Pursuer loses its boosts when it hits
					end
				end
			end
		end
	end
	-- Contacts along fast rushes use the same lag-corrected target positions as ordinary contact damage.
	for k = 1, #self.rushes, 5 do
		local paths = self.rushes
		local i, x, z = paths[k], paths[k + 1], paths[k + 2]
		local dx, dz = paths[k + 3] - x, paths[k + 4] - z
		local hx, hz = Hit.center(kinds[i], x, z)
		local length = math.sqrt(dx * dx + dz * dz)

		if length > EPSILON then
			for t = 1, targetCount do
				local reach = (kinds[i].hitRadius or kinds[i].radius)
					+ (if targetRadii then targetRadii[t] else playerRadius)
					+ margin
					+ EPSILON
				if
					damage[i] > contacts[t]
					and circleEntry(hx, hz, dx / length, dz / length, length, hitXs[t], hitZs[t], reach)
				then
					contacts[t] = damage[i]
					self.contactSources[t] = ids[i]
				end
			end
		end
	end
	-- slashers that strike in this step hit every target in their circle (B9)
	for _, i in self.strikers do
		local slash = kinds[i].slash
		local hit = self.shotDamage[i]
		if slash and hit > 0 then
			for t = 1, targetCount do
				local reach = slash.radius + (if targetRadii then targetRadii[t] else playerRadius)
				local dx, dz = hitXs[t] - xs[i], hitZs[t] - zs[i]
				if dx * dx + dz * dz <= reach * reach and hit > contacts[t] then
					contacts[t] = hit
					self.contactSources[t] = ids[i]
				end
			end
		end
	end
	rebuildHash(self)

	-- 6. ranged enemies count down while a target is in fire range and report a shot at the nearest one (not closer
	-- than minFireRange)
	local shots, shotCount = self.shots, 0
	local shotDamage, shotCooldown = self.shotDamage, self.shotCooldown
	for i = 1, count do
		local ranged = kinds[i].ranged
		if ranged and shotDamage[i] > 0 and targetCount > 0 then
			local x, z = xs[i], zs[i]
			local best, bestSquared = 0, if ranged.nativeTiming then math.huge else ranged.fireRange * ranged.fireRange
			for t = 1, targetCount do
				local dx, dz = hitXs[t] - x, hitZs[t] - z
				local squared = dx * dx + dz * dz
				if squared <= bestSquared then
					best, bestSquared = t, squared
				end
			end
			local fires = false
			if ranged.nativeTiming then
				local minRange = ranged.minFireRange or 0
				fires = ShootingClock.step(
					self.shootingClocks[i] :: ShootingClock.State,
					ranged.nativeTiming,
					dt,
					best > 0
						and bestSquared <= ranged.fireRange * ranged.fireRange
						and bestSquared >= minRange * minRange,
					function()
						return nextRandom(self)
					end
				)
			elseif best > 0 then
				local cooldown = shotCooldown[i] - dt
				local minRange = ranged.minFireRange or 0
				if cooldown <= 0 and bestSquared < minRange * minRange then
					cooldown = 0
				elseif cooldown <= 0 then
					cooldown += ranged.fireInterval
					fires = true
				end
				shotCooldown[i] = cooldown
			end
			if fires and best > 0 then
				for _ = 1, (if ranged.nativeSlash or ranged.nativeVolley then 1 else ranged.projectileCount or 1) do
					local k = shotCount * 5
					shots[k + 1], shots[k + 2], shots[k + 3] = ids[i], x, z
					shots[k + 4], shots[k + 5] = best, shotDamage[i]
					shotCount += 1
				end
			end
		end
	end
	for k = shotCount * 5 + 1, self.shotCount * 5 do
		shots[k] = nil
	end
	self.shotCount = shotCount

	-- 7. summoners count down while there is a target and report themselves when they call
	local summons, summonCount = self.summons, 0
	local summonTimers = self.summonTimers
	for i = 1, count do
		local rule = kinds[i].nativeSpawn
		local state = self.nativeSpawnClocks[i]
		if rule and state then
			if rule.maxCount == -1 or state.shots * rule.count < rule.maxCount then
				local fired = ShootingClock.step(state, rule.timing, dt, true, function()
					return nextRandom(self)
				end)
				self.modes[i] = if state.stage == "Animation" then MODE_WINDUP else MODE_WALK
				if fired then
					summonCount += 1
					summons[summonCount] = ids[i]
				end
			else
				self.modes[i] = MODE_WALK
			end
		elseif targetCount > 0 then
			local summon = kinds[i].summon
			if summon then
				local timer = summonTimers[i] - dt
				if timer <= 0 then
					timer += summon.intervalSeconds
					summonCount += 1
					summons[summonCount] = ids[i]
				end
				summonTimers[i] = timer
			end
		end
	end
	for k = summonCount + 1, self.summonCount do
		summons[k] = nil
	end
	self.summonCount = summonCount

	-- 7b. (B9) pulsing enemies buff or heal the others around them while there is a target, eggs count down and
	-- report themselves when they hatch, counter-shot cooldowns run out
	local hatches, hatchCount = self.hatches, 0
	local abilityTimers, modes, modeTimers = self.abilityTimers, self.modes, self.modeTimers
	for i = 1, count do
		local kind = kinds[i]
		local pulse = kind.pulse
		if pulse then
			if modes[i] == MODE_WINDUP then
				modeTimers[i] -= dt
				if modeTimers[i] <= 0 then
					modes[i] = MODE_WALK
				end
			end
			if pulse.onEnter then
				if pulseAt(self, i, pulse) and not pulse.nativeEnemyEntry then
					modes[i], modeTimers[i] = MODE_WINDUP, PULSE_SHOW_SECONDS
				end
			elseif targetCount > 0 then
				local timer = abilityTimers[i] - dt
				if timer <= 0 then
					timer += pulse.intervalSeconds
					pulseAt(self, i, pulse)
					modes[i], modeTimers[i] = MODE_WINDUP, PULSE_SHOW_SECONDS
				end
				abilityTimers[i] = timer
			end
		elseif kind.hatch then
			local before = abilityTimers[i]
			local timer = before - dt
			abilityTimers[i] = timer
			modes[i] = if timer <= HATCH_WARN_SECONDS then MODE_WINDUP else MODE_WALK
			if timer <= 0 and before > 0 then
				hatchCount += 1
				hatches[hatchCount] = ids[i]
			end
		elseif kind.retaliate then
			abilityTimers[i] = math.max(0, abilityTimers[i] - dt)
		end
	end
	for k = hatchCount + 1, self.hatchCount do
		hatches[k] = nil
	end
	self.hatchCount = hatchCount

	-- 8. slows run out
	local slowFactors, slowLeft = self.slowFactors, self.slowLeft
	for i = 1, count do
		if slowFactors[i] < 1 then
			local left = slowLeft[i] - dt
			slowLeft[i] = left
			if left <= 0 then
				slowFactors[i], slowLeft[i] = 1, 0
			end
		end
	end
	self.nativeSlows:step(dt)
	return contacts
end

return World
