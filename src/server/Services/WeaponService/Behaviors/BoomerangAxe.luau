--!strict
-- Boomerang Axe (DESIGN.md section 6): every cooldown it throws `count` axes at the nearest enemies in range, one
-- target each; axes without a target of their own fan out around the nearest by spreadDegrees. An axe flies straight
-- out for `range` studs, then turns and flies back to wherever the owner is now, at the same speed. It pierces
-- everything (pierce -1), hits each enemy once on the way out and once on the way back and knocks survivors away
-- from the owner (Arsenal, since B5; before along its flight). A weapon with a limited pierce would lose
-- pierceDamage per enemy on each way (the axe has no falloff). It is gone once it is within
-- catchRadius of the owner or after maxFlightSeconds. Effects: "Fire" when an axe is thrown, "End" when it is gone.
-- Behavior for WeaponService/Arsenal; drawn by WeaponRenderer/Visuals/BoomerangAxe.

local Arsenal = require(script.Parent.Parent.Arsenal)

type Axe = {
	id: number,
	x: number,
	z: number,
	dx: number, -- unit direction on the way out
	dz: number,
	flown: number, -- studs on the way out
	range: number,
	speed: number,
	radius: number,
	returning: boolean,
	expiresAt: number, -- server time
	hitsLeft: number,
	share: number, -- of the weapon's damage the next hit deals on this way (pierce falloff)
	hit: { [number]: boolean }, -- enemy ids hit on the current way
}

local EPSILON = 1e-6

local targets: { number } = {}
local found: { number } = {}

local BoomerangAxe = {}

local function axesOf(weapon: Arsenal.Weapon): { Axe }
	local axes = weapon.state.axes
	if not axes then
		axes = {}
		weapon.state.axes = axes
	end
	return axes
end

local function rotate(dx: number, dz: number, angle: number): (number, number)
	local c, s = math.cos(angle), math.sin(angle)
	return dx * c - dz * s, dx * s + dz * c
end

function BoomerangAxe.fire(weapon: Arsenal.Weapon, ctx: Arsenal.Context): boolean
	local stats = weapon.stats
	local count = math.max(1, math.floor(stats.count))
	local targetCount = ctx:nearestEnemies(ctx.x, ctx.z, stats.range, count, targets)
	if targetCount == 0 then
		return false
	end
	local axes = axesOf(weapon)
	local hitsPerWay = if stats.pierce < 0 then math.huge else stats.pierce + 1
	for k = 1, count do
		local tx, tz = ctx:enemyPosition(targets[math.min(k, targetCount)])
		local dx, dz = (tx or ctx.x + 1) - ctx.x, (tz or ctx.z) - ctx.z
		local length = math.sqrt(dx * dx + dz * dz)
		if length < EPSILON then
			dx, dz, length = 1, 0, 1
		end
		dx, dz = dx / length, dz / length
		if k > targetCount then
			-- no target left for this axe: alternate left and right of the nearest, further out each pair
			local extra = k - targetCount
			local side = if extra % 2 == 1 then 1 else -1
			dx, dz = rotate(dx, dz, math.rad(stats.spreadDegrees) * side * math.ceil(extra / 2))
		end
		local axe: Axe = {
			id = ctx:nextId(),
			x = ctx.x,
			z = ctx.z,
			dx = dx,
			dz = dz,
			flown = 0,
			range = stats.range,
			speed = stats.projectileSpeed,
			radius = stats.projectileRadius,
			returning = false,
			expiresAt = ctx.now + stats.maxFlightSeconds,
			hitsLeft = hitsPerWay,
			share = 1,
			hit = {},
		}
		table.insert(axes, axe)
		ctx:emit(weapon, {
			kind = "Fire",
			id = axe.id,
			x = axe.x,
			z = axe.z,
			dx = dx,
			dz = dz,
			speed = axe.speed,
			range = axe.range,
		})
	end
	return true
end

local function hitSegment(weapon: Arsenal.Weapon, ctx: Arsenal.Context, axe: Axe, x1: number, z1: number)
	if axe.hitsLeft <= 0 then
		return
	end
	local hits = ctx:querySegment(axe.x, axe.z, x1, z1, axe.radius, found)
	for i = 1, hits do
		local id = found[i]
		if not axe.hit[id] then
			axe.hit[id] = true
			ctx:hit(weapon, id, axe.share)
			axe.hitsLeft -= 1
			if axe.hitsLeft <= 0 then
				return
			end
			axe.share *= weapon.stats.pierceDamage or 1
		end
	end
end

-- Moves the axe by one step and hits what it passes. Returns true once the owner caught it.
local function move(weapon: Arsenal.Weapon, ctx: Arsenal.Context, axe: Axe, dt: number): boolean
	local distance = axe.speed * dt
	if not axe.returning then
		local out = math.min(distance, axe.range - axe.flown)
		local x1, z1 = axe.x + axe.dx * out, axe.z + axe.dz * out
		hitSegment(weapon, ctx, axe, x1, z1)
		axe.x, axe.z = x1, z1
		axe.flown += out
		distance -= out
		if axe.flown < axe.range - EPSILON then
			return false
		end
		axe.returning = true
		axe.hitsLeft = if weapon.stats.pierce < 0 then math.huge else weapon.stats.pierce + 1
		axe.share = 1
		table.clear(axe.hit)
	end
	local catch = weapon.stats.catchRadius
	local tx, tz = ctx.x - axe.x, ctx.z - axe.z
	local length = math.sqrt(tx * tx + tz * tz)
	if length <= catch then
		return true
	end
	local back = math.min(distance, length)
	local x1, z1 = axe.x + tx / length * back, axe.z + tz / length * back
	hitSegment(weapon, ctx, axe, x1, z1)
	axe.x, axe.z = x1, z1
	return length - back <= catch
end

function BoomerangAxe.step(weapon: Arsenal.Weapon, ctx: Arsenal.Context, dt: number)
	local axes = weapon.state.axes :: { Axe }?
	if not axes then
		return
	end
	for index = #axes, 1, -1 do
		local axe = axes[index]
		-- an axe of a downed owner still flies out and back to where they lie
		if move(weapon, ctx, axe, dt) or ctx.now >= axe.expiresAt then
			ctx:emit(weapon, { kind = "End", id = axe.id, x = axe.x, z = axe.z })
			table.remove(axes, index)
		end
	end
end

return BoomerangAxe
