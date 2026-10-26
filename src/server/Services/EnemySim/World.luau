--!strict
-- Enemies as plain data (DESIGN.md section 15): column arrays, a spatial hash and one step function.
-- No Roblox instances, so tests/EnemyWorld.spec.luau can run it. Owned by EnemySim, which feeds it the
-- player positions and turns the result into snapshots and signals.
--
-- One step:
--   1. remove enemies that died since the last step
--   2. move each enemy towards its nearest target; ranged enemies hold their distance instead.
--      Enemies slide around obstacles and give way to enemies in front that are at least as heavy,
--      so crowds queue up instead of squeezing into each other (Brutes push through lighter ones).
--   3. push still-overlapping enemies apart; mass decides who moves more
--   4. keep enemies out of obstacles and players and inside the arena
--   5. report the strongest contact damage touching each target, rebuild the hash for queries
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

local World = {}
World.__index = World

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
		indexOf: { [number]: number }, -- id -> array index
		nextId: number,
		maxRadius: number, -- largest enemy radius seen, widens neighbour queries
		maxSpeed: number, -- fastest enemy speed seen, widens neighbour queries while enemies move
		hash: SpatialHash.SpatialHash,
		scratch: { number }, -- query results inside step()
		queryScratch: { number }, -- query results for callers between steps
		contacts: { number },
	},
	World
))

function World.new(params: Params): World
	assert(params.maxEnemies < MAX_ID, "maxEnemies must leave room for free ids")
	return setmetatable({
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
		indexOf = {},
		nextId = 0,
		maxRadius = 0,
		maxSpeed = 0,
		hash = SpatialHash.new(params.cellSize),
		scratch = {},
		queryScratch = {},
		contacts = {},
	}, World)
end

-- Spawning and removing -------------------------------------------------------------

local function allocateId(self: World): number
	repeat
		self.nextId = self.nextId % MAX_ID + 1
	until self.indexOf[self.nextId] == nil
	return self.nextId
end

-- Adds an enemy and returns its id, or nil when maxEnemies are alive.
function World.spawn(self: World, kind: Kind, x: number, z: number, hp: number, contactDamage: number): number?
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
	local ids, kinds, typeIds, xs, zs = self.ids, self.kinds, self.typeIds, self.xs, self.zs
	local hp, maxHp, damage, indexOf = self.hp, self.maxHp, self.contactDamage, self.indexOf
	local i = 1
	while i <= self.count do
		if hp[i] > 0 then
			i += 1
			continue
		end
		local last = self.count
		indexOf[ids[i]] = nil
		if i ~= last then
			ids[i], kinds[i], typeIds[i] = ids[last], kinds[last], typeIds[last]
			xs[i], zs[i], hp[i], maxHp[i], damage[i] = xs[last], zs[last], hp[last], maxHp[last], damage[last]
			indexOf[ids[i]] = i
		end
		ids[last], kinds[last], typeIds[last] = nil, nil, nil
		xs[last], zs[last], hp[last], maxHp[last], damage[last] = nil, nil, nil, nil, nil
		self.count = last - 1
	end
	return true
end

-- Removes every enemy without reporting kills (run start and end).
function World.clear(self: World)
	for _, column in { self.ids, self.kinds, self.typeIds, self.xs, self.zs, self.hp, self.maxHp, self.contactDamage } do
		table.clear(column :: { any })
	end
	table.clear(self.indexOf)
	self.count = 0
	self.alive = 0
	self.hash:clear()
end

-- Damage ------------------------------------------------------------------------------

-- Returns true when this hit killed the enemy. Hits on unknown or dead enemies do nothing.
function World.damage(self: World, id: number, amount: number): boolean
	local i = self.indexOf[id]
	if not i or self.hp[i] <= 0 or not (amount > 0) then
		return false
	end
	local left = self.hp[i] - amount
	if left > 0 then
		self.hp[i] = left
		return false
	end
	self.hp[i] = 0
	self.alive -= 1
	return true
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
-- otherwise against the targets.
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
			if distance <= EPSILON then
				continue
			end
			local radius = kind.radius
			local maxMove = kind.speed * dt
			local advance
			local ranged = kind.ranged
			if ranged then
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
			local vx, vz = bestDx / distance * advance, bestDz / distance * advance
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
		local radius = kinds[i].radius
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
	return contacts
end

return World
