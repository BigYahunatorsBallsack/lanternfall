--!strict
-- B7 projectile family for Arsenal: B5 collision/bounces plus spread, magazines and explosion chance.
local Arsenal = require(script.Parent.Arsenal)

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
	bouncesLeft: number,
	share: number, -- of the weapon's damage the next hit deals (pierce and bounce falloff)
	bounced: boolean, -- no knockback after a bounce
	hit: { [number]: boolean }, -- enemy ids this bolt already hit, kept across bounces
}

local EPSILON = 1e-6

local targets: { number } = {}
local found: { number } = {}
local order: { number } = {} -- new hits of one step, sorted by distance along the path
local along: { [number]: number } = {}
local hitX: { [number]: number } = {}
local hitZ: { [number]: number } = {}

local Projectile = {}
local slowAura: ((number, number, number, number, number) -> ())? = nil
function Projectile.setSlowAura(callback: (number, number, number, number, number) -> ())
	slowAura = callback
end

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

-- Starts a bolt at (x, z) flying along (dx, dz) and tells the clients.
local function launch(
	weapon: Arsenal.Weapon,
	ctx: Arsenal.Context,
	x: number,
	z: number,
	dx: number,
	dz: number,
	hitsLeft: number,
	bouncesLeft: number,
	share: number,
	bounced: boolean,
	hit: { [number]: boolean }
): Bolt
	local stats = weapon.stats
	local bolt: Bolt = {
		id = ctx:nextId(),
		x = x,
		z = z,
		dx = dx,
		dz = dz,
		flown = 0,
		range = stats.range,
		speed = stats.projectileSpeed,
		radius = stats.projectileRadius,
		hitsLeft = hitsLeft,
		bouncesLeft = bouncesLeft,
		share = share,
		bounced = bounced,
		hit = hit,
	}
	table.insert(boltsOf(weapon), bolt)
	ctx:emit(weapon, {
		kind = "Fire",
		id = bolt.id,
		x = x,
		z = z,
		dx = dx,
		dz = dz,
		speed = bolt.speed,
		range = bolt.range,
	})
	return bolt
end

function Projectile.fire(weapon: Arsenal.Weapon, ctx: Arsenal.Context): boolean
	local stats = weapon.stats
	if (weapon.state.reloadLeft or 0) > 0 then
		return false
	end
	local count = math.max(1, math.floor(stats.count))
	local targetCount = ctx:nearestEnemies(ctx.x, ctx.z, stats.range, if stats.fan then 1 else count, targets)
	if targetCount == 0 then
		return false
	end
	local hitsPerBolt = if stats.pierce < 0 then math.huge else stats.pierce + 1
	for k = 1, count do
		local tx, tz = ctx:enemyPosition(targets[math.min(k, targetCount)])
		local dx, dz = (tx or ctx.x + 1) - ctx.x, (tz or ctx.z) - ctx.z
		local length = math.sqrt(dx * dx + dz * dz)
		if length < EPSILON then
			dx, dz, length = 1, 0, 1
		end
		dx, dz = dx / length, dz / length
		if stats.fan then
			dx, dz = rotate(dx, dz, math.rad(stats.spreadDegrees) * (k - (count + 1) / 2))
		elseif k > targetCount then
			-- no target left for this bolt: alternate left and right of the nearest, further out each pair
			local extra = k - targetCount
			local side = if extra % 2 == 1 then 1 else -1
			dx, dz = rotate(dx, dz, math.rad(stats.spreadDegrees) * side * math.ceil(extra / 2))
		end
		launch(weapon, ctx, ctx.x, ctx.z, dx, dz, hitsPerBolt, stats.bounce or 0, 1, false, {})
	end
	if stats.magazine then
		weapon.state.shots = (weapon.state.shots or 0) + 1
		if weapon.state.shots >= stats.magazine then
			weapon.state.shots = 0
			weapon.state.reloadLeft = stats.reloadSeconds
		end
	end
	return true
end

-- Hits the enemies on the bolt's path of this step in order. Returns how far along the path it stopped (nil if it
-- flies on) and, for a bounce, the enemy it bounces off and the next target.
local function hitAlong(
	weapon: Arsenal.Weapon,
	ctx: Arsenal.Context,
	bolt: Bolt,
	move: number,
	hits: number
): (number?, number?, number?)
	local n = 0
	for i = 1, hits do
		local id = found[i]
		if not bolt.hit[id] then
			local ex, ez = ctx:enemyPosition(id)
			if ex and ez then
				n += 1
				order[n] = id
				along[id] = (ex - bolt.x) * bolt.dx + (ez - bolt.z) * bolt.dz
				hitX[id], hitZ[id] = ex, ez
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
	local stats = weapon.stats
	local stopAt: number?, bounceFrom: number?, bounceTo: number? = nil, nil, nil
	for i = 1, n do
		local id = order[i]
		bolt.hit[id] = true
		ctx:hit(weapon, id, bolt.share, if bolt.bounced then "Bounce" else nil)
		if stats.explosionRadius and (not stats.explosionChance or ctx:random() < stats.explosionChance) then
			ctx:explode(weapon, hitX[id], hitZ[id], id, bolt.share)
		end
		if bolt.bouncesLeft > 0 then
			local target = ctx:bounceTarget(hitX[id], hitZ[id], bolt.hit)
			if target then
				stopAt, bounceFrom, bounceTo = math.clamp(along[id], 0, move), id, target
				break
			end
		end
		bolt.hitsLeft -= 1
		if bolt.hitsLeft <= 0 then
			stopAt = math.clamp(along[id], 0, move)
			break
		end
		bolt.share *= stats.pierceDamage or 1
	end
	table.clear(along)
	table.clear(hitX)
	table.clear(hitZ)
	return stopAt, bounceFrom, bounceTo
end

function Projectile.step(weapon: Arsenal.Weapon, ctx: Arsenal.Context, dt: number)
	weapon.state.reloadLeft = math.max(0, (weapon.state.reloadLeft or 0) - dt)
	local bolts = weapon.state.bolts :: { Bolt }?
	if not bolts then
		return
	end
	for index = #bolts, 1, -1 do
		local bolt = bolts[index]
		local move = math.min(bolt.speed * dt, bolt.range - bolt.flown)
		local x1, z1 = bolt.x + bolt.dx * move, bolt.z + bolt.dz * move
		if slowAura and weapon.stats.slowRadius then
			slowAura(x1, z1, weapon.stats.slowRadius, 1 - weapon.stats.slow, weapon.stats.slowSeconds)
		end
		local hits = ctx:querySegment(bolt.x, bolt.z, x1, z1, bolt.radius, found)
		local stopAt, bounceFrom, bounceTo
		if hits > 0 then
			stopAt, bounceFrom, bounceTo = hitAlong(weapon, ctx, bolt, move, hits)
		end
		if stopAt then
			bolt.flown += stopAt
			local endX, endZ = bolt.x + bolt.dx * stopAt, bolt.z + bolt.dz * stopAt
			ctx:emit(weapon, { kind = "End", id = bolt.id, x = endX, z = endZ, distance = bolt.flown })
			table.remove(bolts, index)
			local fromX, fromZ = ctx:enemyPosition(bounceFrom or 0)
			local toX, toZ = ctx:enemyPosition(bounceTo or 0)
			if fromX and fromZ and toX and toZ then
				local dx, dz = toX - fromX, toZ - fromZ
				local length = math.sqrt(dx * dx + dz * dz)
				if length < EPSILON then
					dx, dz, length = bolt.dx, bolt.dz, 1
				end
				launch(
					weapon,
					ctx,
					fromX,
					fromZ,
					dx / length,
					dz / length,
					bolt.hitsLeft,
					bolt.bouncesLeft - 1,
					bolt.share * (weapon.stats.bounceDamage or 1),
					true,
					bolt.hit
				)
			end
		else
			bolt.x, bolt.z = x1, z1
			bolt.flown += move
			if bolt.flown >= bolt.range - EPSILON then
				table.remove(bolts, index) -- clients stop drawing at the range on their own
			end
		end
	end
end

return Projectile
