--!strict
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
-- Enemies that die between steps stay in the arrays with hp 0 until the next step; every query skips them,
-- so array indices (and the hash) stay valid until then.

local Shared = game:GetService("ReplicatedStorage").Shared
local Enemies = require(Shared.Config.Enemies)
local SpatialHash = require(Shared.Util.SpatialHash)

export type Kind = Enemies.Enemy
export type Circle = { x: number, z: number, radius: number }

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
}

local MAX_ID = 65535 -- ids are u16 in snapshots
local EPSILON = 1e-6
local HEAD_ON = 0.05 -- below this share of sideways movement an enemy counts as running straight at an obstacle
local GOLDEN_ANGLE = 2.399963 -- spreads the push direction of enemies standing exactly on top of each other
local GOLDEN_RATIO = 0.618034 -- spreads the first shot of ranged enemies so they do not fire in sync

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
		hp: { number },
		maxHp: { number },
		contactDamage: { number }, -- damage per touch
		shotDamage: { number }, -- damage per projectile, 0 for enemies that do not shoot
		shotCooldown: { number }, -- seconds in fire range until the next shot
		modes: { number }, -- MODE_*
		modeTimers: { number }, -- seconds left in the wind-up or recovery; while walking: until a wind-up may start
		rushXs: { number }, -- unit rush direction, fixed when the wind-up starts
		rushZs: { number },
		rushLeft: { number }, -- studs the rush may still go
		summonTimers: { number }, -- seconds until a summoner calls again
		slowFactors: { number }, -- share of its speed a slowed enemy keeps, 1 when not slowed (B5)
		slowLeft: { number }, -- seconds the slow lasts
		burning: { boolean }, -- shown in snapshots; the weapons (WeaponService/Afflictions) run the burn itself
		columns: { { any } }, -- every per-enemy array above, for compacting and clearing
		indexOf: { [number]: number }, -- id -> array index
		nextId: number,
		maxRadius: number, -- largest enemy radius seen, widens neighbour queries
		maxSpeed: number, -- fastest enemy speed seen, widens neighbour queries while enemies move
		hash: SpatialHash.SpatialHash,
		scratch: { number }, -- query results inside step()
		queryScratch: { number }, -- query results for callers between steps
		contacts: { number },
		-- shots of the last step, flat: enemy id, x, z, target index, damage per shot
		shots: { number },
		shotCount: number,
		-- ids of the summoners that call enemies after the last step
		summons: { number },
		summonCount: number,
	},
	World
))

function World.new(params: Params): World
	assert(params.maxEnemies < MAX_ID, "maxEnemies must leave room for free ids")
	local self = {
		params = params,
		count = 0,
		alive = 0,
		ids = {},
		kinds = {},
		typeIds = {},
		xs = {},
		zs = {},
		hp = {},
		maxHp = {},
		contactDamage = {},
		shotDamage = {},
		shotCooldown = {},
		modes = {},
		modeTimers = {},
		rushXs = {},
		rushZs = {},
		rushLeft = {},
		summonTimers = {},
		slowFactors = {},
		slowLeft = {},
		burning = {},
		columns = {},
		indexOf = {},
		nextId = 0,
		maxRadius = 0,
		maxSpeed = 0,
		hash = SpatialHash.new(params.cellSize),
		scratch = {},
		queryScratch = {},
		contacts = {},
		shots = {},
		shotCount = 0,
		summons = {},
		summonCount = 0,
	}
	self.columns = {
		self.ids,
		self.kinds,
		self.typeIds,
		self.xs,
		self.zs,
		self.hp,
		self.maxHp,
		self.contactDamage,
		self.shotDamage,
		self.shotCooldown,
		self.modes,
		self.modeTimers,
		self.rushXs,
		self.rushZs,
		self.rushLeft,
		self.summonTimers,
		self.slowFactors,
		self.slowLeft,
		self.burning,
	} :: { { any } }
	return setmetatable(self, World)
end

-- Spawning and removing -------------------------------------------------------------

local function allocateId(self: World): number
	repeat
		self.nextId = self.nextId % MAX_ID + 1
	until self.indexOf[self.nextId] == nil
	return self.nextId
end

-- Adds an enemy and returns its id, or nil when maxEnemies are alive. `shotDamage` is the damage of each projectile
-- of a ranged kind (default: its config value).
function World.spawn(
	self: World,
	kind: Kind,
	x: number,
	z: number,
	hp: number,
	contactDamage: number,
	shotDamage: number?
): number?
	if self.alive >= self.params.maxEnemies then
		return nil
	end
	local id = allocateId(self)
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
	self.contactDamage[i] = contactDamage
	local ranged = kind.ranged
	local spread = (id * GOLDEN_RATIO) % 1 -- so a group spawned together does not act in sync
	self.shotDamage[i] = if ranged then shotDamage or ranged.projectileDamage else 0
	self.shotCooldown[i] = if ranged then ranged.fireInterval * spread else 0
	self.modes[i] = MODE_WALK
	self.modeTimers[i] = if kind.charge then kind.charge.cooldownSeconds * spread else 0
	self.rushXs[i], self.rushZs[i], self.rushLeft[i] = 0, 0, 0
	self.summonTimers[i] = if kind.summon then kind.summon.intervalSeconds * (0.5 + 0.5 * spread) else 0
	self.slowFactors[i], self.slowLeft[i], self.burning[i] = 1, 0, false
	self.indexOf[id] = i
	self.maxRadius = math.max(self.maxRadius, kind.radius)
	self.maxSpeed = math.max(self.maxSpeed, kind.speed)
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
function World.remove(self: World, id: number): boolean
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 then
		return false
	end
	self.hp[i] = 0
	self.alive -= 1
	return true
end

-- Removes every enemy without reporting kills (run start and end).
function World.clear(self: World)
	for _, column in self.columns do
		table.clear(column)
	end
	table.clear(self.indexOf)
	table.clear(self.shots)
	table.clear(self.summons)
	self.shotCount = 0
	self.summonCount = 0
	self.count = 0
	self.alive = 0
	self.hash:clear()
end

-- Damage ------------------------------------------------------------------------------

-- Returns true when this hit killed the enemy, the HP it actually took (at most what was left) and the damage after
-- the enemy's damageTaken multiplier (Armored elites take less). Hits on unknown or dead enemies do nothing.
function World.damage(self: World, id: number, amount: number): (boolean, number, number)
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 or not (amount > 0) then
		return false, 0, 0
	end
	local applied = amount * (self.kinds[i].damageTaken or 1)
	local hp = self.hp[i]
	local left = hp - applied
	if left > 0 then
		self.hp[i] = left
		return false, applied, applied
	end
	self.hp[i] = 0
	self.alive -= 1
	return true, hp, applied
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

-- Returns hp and max hp.
function World.getHealth(self: World, id: number): (number, number)
	local i = self.indexOf[id]
	if not i then
		return 0, 0
	end
	return self.hp[i], self.maxHp[i]
end

-- The HP and damage multipliers the enemy was spawned with (minute and difficulty, on top of its kind's values),
-- so enemies it splits into or calls can get the same. 1, 1 for unknown ids.
function World.getMultipliers(self: World, id: number): (number, number)
	local i = self.indexOf[id]
	if not i then
		return 1, 1
	end
	local kind = self.kinds[i]
	local hpMultiplier = self.maxHp[i] / kind.hp
	local damageMultiplier = 1
	if kind.contactDamage > 0 then
		damageMultiplier = self.contactDamage[i] / kind.contactDamage
	elseif kind.ranged and kind.ranged.projectileDamage > 0 then
		damageMultiplier = self.shotDamage[i] / kind.ranged.projectileDamage
	end
	return hpMultiplier, damageMultiplier
end

-- The enemy's mode (World.MODE_*) and its rush direction (only meaningful from the wind-up on).
function World.getMode(self: World, id: number): (number, number, number)
	local i = self.indexOf[id]
	if not i then
		return MODE_WALK, 0, 0
	end
	return self.modes[i], self.rushXs[i], self.rushZs[i]
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
			local reach = radius + kinds[i].radius
			local dx, dz = xs[i] - x, zs[i] - z
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
			local px, pz = xs[i] - x0, zs[i] - z0
			local t = if lengthSquared > EPSILON then math.clamp((px * sx + pz * sz) / lengthSquared, 0, 1) else 0
			local dx, dz = px - sx * t, pz - sz * t
			local reach = radius + kinds[i].radius
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
		local nx, nz = x - obstacle.x, z - obstacle.z
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
	local x, z = self.xs[i] + dx * scale, self.zs[i] + dz * scale
	for _, obstacle in p.obstacles do
		x, z = pushOut(x, z, obstacle.x, obstacle.z, obstacle.radius + radius, id)
	end
	self.xs[i] = math.clamp(x, p.minX + radius, p.maxX - radius)
	self.zs[i] = math.clamp(z, p.minZ + radius, p.maxZ - radius)
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

-- Whether the enemy is slowed and whether it burns.
function World.getStatus(self: World, id: number): (boolean, boolean)
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 then
		return false, false
	end
	return self.slowFactors[i] < 1, self.burning[i]
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

-- One step of a rush along the fixed direction. It ends after maxDistance, in an obstacle, at the arena edge or
-- touching a target; step 4 then puts the charger back outside of what it ran into.
local function rushStep(
	self: World,
	i: number,
	charge: Enemies.Charge,
	dt: number,
	targetXs: { number },
	targetZs: { number },
	targetCount: number
)
	local p = self.params
	local radius = self.kinds[i].radius
	local move = math.min(charge.speed * self.slowFactors[i] * dt, self.rushLeft[i])
	local x, z = self.xs[i] + self.rushXs[i] * move, self.zs[i] + self.rushZs[i] * move
	local left = self.rushLeft[i] - move
	local stop = left <= EPSILON
	for _, obstacle in p.obstacles do
		local reach = obstacle.radius + radius
		if (x - obstacle.x) ^ 2 + (z - obstacle.z) ^ 2 < reach * reach then
			stop = true
		end
	end
	if x < p.minX + radius or x > p.maxX - radius or z < p.minZ + radius or z > p.maxZ - radius then
		stop = true
	end
	local touch = radius + p.playerRadius + p.contactMargin
	for t = 1, targetCount do
		if (targetXs[t] - x) ^ 2 + (targetZs[t] - z) ^ 2 <= touch * touch then
			stop = true
		end
	end
	self.xs[i], self.zs[i] = x, z
	self.rushLeft[i] = left
	if stop then
		self.modes[i] = MODE_RECOVER
		self.modeTimers[i] = charge.recoverSeconds
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
	distance: number,
	targetXs: { number },
	targetZs: { number },
	targetCount: number
): boolean
	local modes, timers = self.modes, self.modeTimers
	local mode = modes[i]
	if mode == MODE_RUSH then
		rushStep(self, i, charge, dt, targetXs, targetZs, targetCount)
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
			timers[i] = charge.cooldownSeconds
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

local function rebuildHash(self: World)
	local hash, xs, zs = self.hash, self.xs, self.zs
	hash:clear()
	for i = 1, self.count do
		hash:insert(i, xs[i], zs[i])
	end
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
	contactZs: { number }?
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

	-- 2. steering
	if targetCount > 0 then
		local tolerance = p.keepDistanceTolerance
		local steerMargin = p.obstacleSteerMargin
		-- neighbours may have moved up to one step since the hash was built
		local queryPadding = maxRadius + self.maxSpeed * dt
		for i = 1, count do
			local kind = kinds[i]
			local x, z = xs[i], zs[i]
			local bestDx, bestDz, bestSquared = 0, 0, math.huge
			for t = 1, targetCount do
				local dx, dz = targetXs[t] - x, targetZs[t] - z
				local squared = dx * dx + dz * dz
				if squared < bestSquared then
					bestDx, bestDz, bestSquared = dx, dz, squared
				end
			end
			local distance = math.sqrt(bestSquared)
			local charge = kind.charge
			if
				charge
				and chargeStep(self, i, charge, dt, bestDx, bestDz, distance, targetXs, targetZs, targetCount)
			then
				continue
			end
			if distance <= EPSILON or kind.anchored then
				continue
			end
			local radius = kind.radius
			local maxMove = kind.speed * self.slowFactors[i] * dt
			local dirX, dirZ = bestDx / distance, bestDz / distance
			local advance
			local ranged = kind.ranged
			local flee = kind.flee
			if flee then
				dirX, dirZ = fleeDirection(p, x, z, bestDx, bestDz, distance, flee.edgeMargin)
				advance = maxMove
			elseif ranged then
				local keep = ranged.keepDistance
				if distance > keep + tolerance then
					advance = math.min(maxMove, distance - keep)
				elseif distance < keep - tolerance then
					advance = -math.min(maxMove, keep - distance)
				else
					advance = 0
				end
			else
				advance = math.min(maxMove, math.max(0, distance - radius - playerRadius))
			end
			if advance == 0 then
				continue
			end
			local vx, vz = dirX * advance, dirZ * advance
			vx, vz = slideAroundObstacles(obstacles, x, z, vx, vz, radius + steerMargin, ids[i])

			-- give way: move towards a neighbour at most until touching it
			local mass = kind.mass
			local found = hash:query(x, z, radius + queryPadding, scratch)
			for s = 1, found do
				local j = scratch[s]
				local other = kinds[j]
				if j ~= i and other.mass >= mass then
					local nx, nz = x - xs[j], z - zs[j]
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
	local stiffness = p.separationStiffness
	for _ = 1, p.separationPasses do
		rebuildHash(self)
		for i = 1, count do
			local kindI = kinds[i]
			local radiusI, massI = kindI.radius, kindI.mass
			local found = hash:query(xs[i], zs[i], radiusI + maxRadius, scratch)
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

	-- 4. constraints
	local minX, maxX, minZ, maxZ = p.minX, p.maxX, p.minZ, p.maxZ
	for i = 1, count do
		local kind = kinds[i]
		if kind.anchored then
			continue
		end
		local radius = kind.radius
		local x, z = xs[i], zs[i]
		for _, obstacle in obstacles do
			x, z = pushOut(x, z, obstacle.x, obstacle.z, obstacle.radius + radius, ids[i])
		end
		for t = 1, targetCount do
			x, z = pushOut(x, z, targetXs[t], targetZs[t], radius + playerRadius, ids[i])
		end
		xs[i] = math.clamp(x, minX + radius, maxX - radius)
		zs[i] = math.clamp(z, minZ + radius, maxZ - radius)
	end

	-- 5. contacts and the hash for queries until the next step
	local contacts = self.contacts
	table.clear(contacts)
	for t = 1, targetCount do
		contacts[t] = 0
	end
	local margin = p.contactMargin
	local damage = self.contactDamage
	local hitXs, hitZs = contactXs or targetXs, contactZs or targetZs
	for i = 1, count do
		local hit = damage[i]
		if hit > 0 then
			local reach = kinds[i].radius + playerRadius + margin
			local reachSquared = reach * reach
			for t = 1, targetCount do
				local dx, dz = hitXs[t] - xs[i], hitZs[t] - zs[i]
				if dx * dx + dz * dz <= reachSquared and hit > contacts[t] then
					contacts[t] = hit
				end
			end
		end
	end
	rebuildHash(self)

	-- 6. ranged enemies count down while a target is in fire range and report a shot at the nearest one
	local shots, shotCount = self.shots, 0
	local shotDamage, shotCooldown = self.shotDamage, self.shotCooldown
	for i = 1, count do
		local ranged = kinds[i].ranged
		if ranged and shotDamage[i] > 0 and targetCount > 0 then
			local x, z = xs[i], zs[i]
			local best, bestSquared = 0, ranged.fireRange * ranged.fireRange
			for t = 1, targetCount do
				local dx, dz = hitXs[t] - x, hitZs[t] - z
				local squared = dx * dx + dz * dz
				if squared <= bestSquared then
					best, bestSquared = t, squared
				end
			end
			if best > 0 then
				local cooldown = shotCooldown[i] - dt
				if cooldown <= 0 then
					cooldown += ranged.fireInterval
					local k = shotCount * 5
					shots[k + 1], shots[k + 2], shots[k + 3] = ids[i], x, z
					shots[k + 4], shots[k + 5] = best, shotDamage[i]
					shotCount += 1
				end
				shotCooldown[i] = cooldown
			end
		end
	end
	for k = shotCount * 5 + 1, self.shotCount * 5 do
		shots[k] = nil
	end
	self.shotCount = shotCount

	-- 7. summoners count down while there is a target and report themselves when they call
	local summons, summonCount = self.summons, 0
	if targetCount > 0 then
		local summonTimers = self.summonTimers
		for i = 1, count do
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
	return contacts
end

return World
