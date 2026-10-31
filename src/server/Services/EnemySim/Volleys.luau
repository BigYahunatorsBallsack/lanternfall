--!strict
--!native
-- Enemy projectiles as plain data (DESIGN.md section 7, Spitter shots): each flies straight at its speed, ends at
-- its range, at an obstacle or the arena edge, and hurts the first target it touches. No Roblox instances, so
-- tests/EnemyWorld.spec.luau can run it. Owned by EnemySim, which fires the shots World reports and turns hits into
-- player damage (EnemySim.ShotHit) and ends into EnemyShots effects for the clients.

local EPSILON = 1e-6

export type Circle = { x: number, z: number, radius: number }

export type Params = {
	playerRadius: number,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	obstacles: { Circle },
}

type Shot = {
	id: number,
	x: number, -- where it was fired
	z: number,
	dx: number, -- unit direction
	dz: number,
	speed: number,
	range: number,
	radius: number,
	damage: number,
	flown: number, -- studs so far
}

local Volleys = {}
Volleys.__index = Volleys

export type Volleys = typeof(setmetatable(
	{} :: {
		params: Params,
		shots: { Shot },
		nextId: number,
		-- results of the last step (reused): hits flat as target index, damage; ends flat as shot id, distance flown
		hits: { number },
		hitCount: number,
		ended: { number },
		endedCount: number,
	},
	Volleys
))

function Volleys.new(params: Params): Volleys
	return setmetatable({
		params = params,
		shots = {},
		nextId = 0,
		hits = {},
		hitCount = 0,
		ended = {},
		endedCount = 0,
	}, Volleys)
end

-- Starts a shot at (x, z) along the unit direction (dx, dz). Returns its id (unique until clear).
function Volleys.fire(
	self: Volleys,
	x: number,
	z: number,
	dx: number,
	dz: number,
	speed: number,
	range: number,
	radius: number,
	damage: number
): number
	self.nextId += 1
	table.insert(self.shots, {
		id = self.nextId,
		x = x,
		z = z,
		dx = dx,
		dz = dz,
		speed = speed,
		range = range,
		radius = radius,
		damage = damage,
		flown = 0,
	})
	return self.nextId
end

function Volleys.clear(self: Volleys)
	table.clear(self.shots)
	table.clear(self.hits)
	table.clear(self.ended)
	self.hitCount = 0
	self.endedCount = 0
end

function Volleys.getCount(self: Volleys): number
	return #self.shots
end

-- Distance along the segment from (x, z) in unit direction (dx, dz), length `length`, at which a point of it first
-- comes within `reach` of (cx, cz); nil if it never does.
local function entryDistance(
	x: number,
	z: number,
	dx: number,
	dz: number,
	length: number,
	cx: number,
	cz: number,
	reach: number
): number?
	local px, pz = cx - x, cz - z
	local along = px * dx + pz * dz
	local closestSquared = px * px + pz * pz - along * along
	local reachSquared = reach * reach
	if closestSquared > reachSquared then
		return nil
	end
	local entry = along - math.sqrt(reachSquared - closestSquared)
	if entry > length then
		return nil
	end
	if entry < 0 then
		-- the start is already inside: only counts if the circle lies ahead or around it
		return if px * px + pz * pz <= reachSquared then 0 else nil
	end
	return entry
end

-- Advances every shot by dt against the targets (x/z of living players). Afterwards self.hits[1 .. 2 * hitCount]
-- holds the hits (target index, damage) and self.ended[1 .. 2 * endedCount] the shots that ended early or hit
-- (id, distance flown). Shots that reach their range just vanish (clients fade them out there themselves).
function Volleys.step(self: Volleys, dt: number, targetXs: { number }, targetZs: { number }, targetCount: number)
	local p = self.params
	local hits, ended = self.hits, self.ended
	local hitCount, endedCount = 0, 0
	local shots = self.shots
	local index = 1
	while index <= #shots do
		local shot = shots[index]
		local x, z = shot.x + shot.dx * shot.flown, shot.z + shot.dz * shot.flown
		local length = math.min(shot.speed * dt, shot.range - shot.flown)
		local stopAt: number? = nil
		local target = 0
		for t = 1, targetCount do
			local entry =
				entryDistance(x, z, shot.dx, shot.dz, length, targetXs[t], targetZs[t], p.playerRadius + shot.radius)
			if entry and entry < (stopAt or math.huge) then
				stopAt, target = entry, t
			end
		end
		for _, obstacle in p.obstacles do
			local entry = entryDistance(x, z, shot.dx, shot.dz, length, obstacle.x, obstacle.z, obstacle.radius)
			if entry and entry < (stopAt or math.huge) then
				stopAt, target = entry, 0
			end
		end
		local endX, endZ = x + shot.dx * length, z + shot.dz * length
		if not stopAt and (endX < p.minX or endX > p.maxX or endZ < p.minZ or endZ > p.maxZ) then
			stopAt = length
		end
		if stopAt then
			if target > 0 then
				hits[hitCount * 2 + 1], hits[hitCount * 2 + 2] = target, shot.damage
				hitCount += 1
			end
			ended[endedCount * 2 + 1], ended[endedCount * 2 + 2] = shot.id, shot.flown + stopAt
			endedCount += 1
			table.remove(shots, index)
			continue
		end
		shot.flown += length
		if shot.flown >= shot.range - EPSILON then
			table.remove(shots, index)
			continue
		end
		index += 1
	end
	for k = hitCount * 2 + 1, self.hitCount * 2 do
		hits[k] = nil
	end
	for k = endedCount * 2 + 1, self.endedCount * 2 do
		ended[k] = nil
	end
	self.hitCount, self.endedCount = hitCount, endedCount
end

return Volleys
