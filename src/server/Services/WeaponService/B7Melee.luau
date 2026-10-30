--!strict
-- Targeted thrust/sweep behaviors for Arsenal; geometry and timing come from Config.Weapons.
local Arsenal = require(script.Parent.Arsenal)
local Melee = {}
local targets: { number } = {}
local found: { number } = {}

function Melee.fire(weapon: Arsenal.Weapon, ctx: Arsenal.Context): boolean
	local stats = weapon.stats
	if ctx:nearestEnemies(ctx.x, ctx.z, stats.range, 1, targets) == 0 then
		return false
	end
	local tx, tz = ctx:enemyPosition(targets[1])
	if not tx or not tz then
		return false
	end
	local dx, dz = tx - ctx.x, tz - ctx.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-6 then
		dx, dz, length = 1, 0, 1
	end
	dx, dz = dx / length, dz / length
	local sweep = stats.meleeMode == 1 or (stats.meleeMode == 2 and weapon.state.sweep == true)
	weapon.state.sweep = not sweep
	local n = if sweep
		then ctx:queryCircle(ctx.x, ctx.z, stats.range, found)
		else ctx:querySegment(ctx.x, ctx.z, ctx.x + dx * stats.range, ctx.z + dz * stats.range, stats.width, found)
	local threshold = math.cos(math.rad(stats.sweepDegrees / 2))
	for i = 1, n do
		local id = found[i]
		local x, z = ctx:enemyPosition(id)
		if x and z then
			local ex, ez = x - ctx.x, z - ctx.z
			local distance = math.sqrt(ex * ex + ez * ez)
			if not sweep or distance < 1e-6 or (ex * dx + ez * dz) / distance >= threshold then
				ctx:hit(weapon, id)
			end
		end
	end
	ctx:emit(weapon, {
		kind = "Strike",
		x = ctx.x,
		z = ctx.z,
		dx = dx,
		dz = dz,
		range = stats.range,
		radius = stats.width,
		duration = stats.attackSeconds,
		angle = if sweep then stats.sweepDegrees else 0,
	})
	return true
end
return Melee
