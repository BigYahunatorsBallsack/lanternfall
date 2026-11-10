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
		hitSources: { number },
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
		hitSources = {},
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

-- The arena's walls moved (map-size effect at run start).
function Volleys.setBounds(self: Volleys, minX: number, maxX: number, minZ: number, maxZ: number)
	local p = self.params
	p.minX, p.maxX, p.minZ, p.maxZ = minX, maxX, minZ, maxZ
end

function Volleys.clear(self: Volleys)
	table.clear(self.shots)
	table.clear(self.hits)
	table.clear(self.hitSources)
	table.clear(self.ended)
	self.hitCount = 0
	self.endedCount = 0
end

function Volleys.getCount(self: Volleys): number
	return #self.shots
end

local entryDistance = require(game:GetService("ReplicatedStorage").Shared.Util.SegmentCircle).entry

-- Advances every shot by dt against the targets (x/z of living players). Afterwards self.hits[1 .. 2 * hitCount]
-- holds the hits (target index, damage) and self.ended[1 .. 2 * endedCount] the shots that ended early or hit
-- (id, distance flown). Shots that reach their range just vanish (clients fade them out there themselves).
function Volleys.step(
	self: Volleys,
	dt: number,
	targetXs: { number },
	targetZs: { number },
	targetCount: number,
	targetRadii: { number }?
)
	local p = self.params
	local hits, ended = self.hits, self.ended
	table.clear(self.hitSources)
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
			local entry = entryDistance(
				x,
				z,
				shot.dx,
				shot.dz,
				length,
				targetXs[t],
				targetZs[t],
				(if targetRadii then targetRadii[t] else p.playerRadius) + shot.radius
			)
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
				self.hitSources[hitCount] = shot.id
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
