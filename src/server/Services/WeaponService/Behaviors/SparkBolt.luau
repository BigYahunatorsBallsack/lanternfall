--!strict
-- Spark Bolt (DESIGN.md section 6): every cooldown it shoots `count` bolts at the nearest enemies in range, one
-- target each; bolts without a target of their own fan out around the nearest by spreadDegrees. A bolt flies
-- straight, hits up to pierce + 1 enemies (closest along its path first, never the same one twice) and vanishes
-- after `range` studs. Effects: "Fire" when a bolt starts, "End" when an enemy stops it before its range.
-- Behavior for WeaponService/Arsenal; drawn by WeaponRenderer/Visuals/SparkBolt.

local Arsenal = require(script.Parent.Parent.Arsenal)

type Bolt = {
	id: number,
	x: number,
	z: number,
	dx: number, -- unit direction
	dz: number,
	flown: number, -- studs so far
	range: number,
	speed: number,
	radius: number,
	hitsLeft: number,
	hit: { [number]: boolean }, -- enemy ids this bolt already hit
}

local EPSILON = 1e-6

local targets: { number } = {}
local found: { number } = {}
local order: { number } = {} -- new hits of one step, sorted by distance along the path
local along: { [number]: number } = {}

local SparkBolt = {}

local function boltsOf(weapon: Arsenal.Weapon): { Bolt }
	local bolts = weapon.state.bolts
	if not bolts then
		bolts = {}
		weapon.state.bolts = bolts
	end
	return bolts
end

local function rotate(dx: number, dz: number, angle: number): (number, number)
	local c, s = math.cos(angle), math.sin(angle)
	return dx * c - dz * s, dx * s + dz * c
end

function SparkBolt.fire(weapon: Arsenal.Weapon, ctx: Arsenal.Context): boolean
	local stats = weapon.stats
	local count = math.max(1, math.floor(stats.count))
	local targetCount = ctx:nearestEnemies(ctx.x, ctx.z, stats.range, count, targets)
	if targetCount == 0 then
		return false
	end
	local bolts = boltsOf(weapon)
	local hitsPerBolt = if stats.pierce < 0 then math.huge else stats.pierce + 1
	for k = 1, count do
		local tx, tz = ctx:enemyPosition(targets[math.min(k, targetCount)])
		local dx, dz = (tx or ctx.x + 1) - ctx.x, (tz or ctx.z) - ctx.z
		local length = math.sqrt(dx * dx + dz * dz)
		if length < EPSILON then
			dx, dz, length = 1, 0, 1
		end
		dx, dz = dx / length, dz / length
		if k > targetCount then
			-- no target left for this bolt: alternate left and right of the nearest, further out each pair
			local extra = k - targetCount
			local side = if extra % 2 == 1 then 1 else -1
			dx, dz = rotate(dx, dz, math.rad(stats.spreadDegrees) * side * math.ceil(extra / 2))
		end
		local bolt: Bolt = {
			id = ctx:nextId(),
			x = ctx.x,
			z = ctx.z,
			dx = dx,
			dz = dz,
			flown = 0,
			range = stats.range,
			speed = stats.projectileSpeed,
			radius = stats.projectileRadius,
			hitsLeft = hitsPerBolt,
			hit = {},
		}
		table.insert(bolts, bolt)
		ctx:emit(weapon, {
			kind = "Fire",
			id = bolt.id,
			x = bolt.x,
			z = bolt.z,
			dx = dx,
			dz = dz,
			speed = bolt.speed,
			range = bolt.range,
		})
	end
	return true
end

-- Hits the enemies on the bolt's path of this step in order. Returns how far along the path it stopped, or nil
-- if it flies on.
local function hitAlong(weapon: Arsenal.Weapon, ctx: Arsenal.Context, bolt: Bolt, move: number, hits: number): number?
	local n = 0
	for i = 1, hits do
		local id = found[i]
		if not bolt.hit[id] then
			local ex, ez = ctx:enemyPosition(id)
			if ex and ez then
				n += 1
				order[n] = id
				along[id] = (ex - bolt.x) * bolt.dx + (ez - bolt.z) * bolt.dz
			end
		end
	end
	for i = 2, n do -- insertion sort: only a few enemies per step
		local id = order[i]
		local t = along[id]
		local j = i - 1
		while j >= 1 and along[order[j]] > t do
			order[j + 1] = order[j]
			j -= 1
		end
		order[j + 1] = id
	end
	local stopAt: number? = nil
	for i = 1, n do
		local id = order[i]
		bolt.hit[id] = true
		ctx:hit(weapon, id)
		bolt.hitsLeft -= 1
		if bolt.hitsLeft <= 0 then
			stopAt = math.clamp(along[id], 0, move)
			break
		end
	end
	table.clear(along)
	return stopAt
end

function SparkBolt.step(weapon: Arsenal.Weapon, ctx: Arsenal.Context, dt: number)
	local bolts = weapon.state.bolts :: { Bolt }?
	if not bolts then
		return
	end
	for index = #bolts, 1, -1 do
		local bolt = bolts[index]
		local move = math.min(bolt.speed * dt, bolt.range - bolt.flown)
		local x1, z1 = bolt.x + bolt.dx * move, bolt.z + bolt.dz * move
		local hits = ctx:querySegment(bolt.x, bolt.z, x1, z1, bolt.radius, found)
		local stopAt = if hits > 0 then hitAlong(weapon, ctx, bolt, move, hits) else nil
		if stopAt then
			bolt.flown += stopAt
			ctx:emit(weapon, {
				kind = "End",
				id = bolt.id,
				x = bolt.x + bolt.dx * stopAt,
				z = bolt.z + bolt.dz * stopAt,
				distance = bolt.flown,
			})
			table.remove(bolts, index)
		else
			bolt.x, bolt.z = x1, z1
			bolt.flown += move
			if bolt.flown >= bolt.range - EPSILON then
				table.remove(bolts, index) -- clients stop drawing at the range on their own
			end
		end
	end
end

return SparkBolt
