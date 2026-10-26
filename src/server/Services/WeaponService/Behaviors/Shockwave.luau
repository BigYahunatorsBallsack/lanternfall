--!strict
-- Shockwave (DESIGN.md section 6): once the cooldown is over and an enemy is within `radius`, a blast hits every
-- enemy in the radius and pushes the survivors `knockback` studs away from the owner (heavy enemies less, see
-- EnemySim/World.push). Effect: "Pulse" with the center and radius. Behavior for WeaponService/Arsenal; drawn by
-- WeaponRenderer/Visuals/Shockwave.

local Arsenal = require(script.Parent.Parent.Arsenal)

local EPSILON = 1e-3

local found: { number } = {}

local Shockwave = {}

function Shockwave.fire(weapon: Arsenal.Weapon, ctx: Arsenal.Context): boolean
	local stats = weapon.stats
	local count = ctx:queryCircle(ctx.x, ctx.z, stats.radius, found)
	if count == 0 then
		return false
	end
	ctx:emit(weapon, { kind = "Pulse", x = ctx.x, z = ctx.z, radius = stats.radius })
	local knockback = stats.knockback or 0
	for i = 1, count do
		local id = found[i]
		local killed = ctx:hit(weapon, id)
		if not killed and knockback > 0 then
			local ex, ez = ctx:enemyPosition(id)
			if ex and ez then
				local dx, dz = ex - ctx.x, ez - ctx.z
				local length = math.sqrt(dx * dx + dz * dz)
				if length < EPSILON then
					local angle = ctx:random() * 2 * math.pi
					dx, dz, length = math.cos(angle), math.sin(angle), 1
				end
				ctx:push(id, dx / length * knockback, dz / length * knockback)
			end
		end
	end
	return true
end

return Shockwave
