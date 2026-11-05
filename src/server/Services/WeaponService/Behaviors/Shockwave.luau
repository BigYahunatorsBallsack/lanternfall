--!strict
-- Shockwave (DESIGN.md section 6): hits the nearest enemy with the hammer, then sends a weaker pulse from impact.
-- Arsenal owns all damage; WeaponRenderer moves the hammer and draws the impact-centered pulse.

local Arsenal = require(script.Parent.Parent.Arsenal)

local targets: { number } = {}
local found: { number } = {}

local Shockwave = {}

function Shockwave.fire(weapon: Arsenal.Weapon, ctx: Arsenal.Context): boolean
	local stats = weapon.stats
	if ctx:nearestEnemies(ctx.x, ctx.z, stats.range, 1, targets) == 0 then
		return false
	end
	local target = targets[1]
	local x, z = ctx:enemyPosition(target)
	if not x or not z then
		return false
	end
	local dx, dz = x - ctx.x, z - ctx.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 1e-6 then
		dx, dz, distance = 1, 0, 1
	end
	dx, dz = dx / distance, dz / distance
	ctx:emit(weapon, {
		kind = "Pulse",
		uid = weapon.uid,
		x = x,
		z = z,
		dx = dx,
		dz = dz,
		targetDistance = distance,
		radius = stats.explosionRadius,
	})
	ctx:hit(weapon, target)
	local count = ctx:queryCircle(x, z, stats.explosionRadius, found)
	for i = 1, count do
		local id = found[i]
		if id ~= target then
			local killed = ctx:hit(weapon, id, stats.explosionDamage, "Explosion")
			if not killed then
				local ex, ez = ctx:enemyPosition(id)
				if ex and ez then
					local pushX, pushZ = ex - x, ez - z
					local length = math.sqrt(pushX * pushX + pushZ * pushZ)
					if length < 1e-6 then
						pushX, pushZ, length = dx, dz, 1
					end
					local push = stats.knockback * stats.waveKnockbackShare
					ctx:push(id, pushX / length * push, pushZ / length * push)
				end
			end
		end
	end
	return true
end

return Shockwave
