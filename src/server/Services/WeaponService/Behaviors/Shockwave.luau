--!strict
-- Shockwave (DESIGN.md section 6): once the cooldown is over and an enemy is within `radius`, a blast hits every
-- enemy in the radius; the hits knock the survivors away from the owner (Arsenal, since B5 with the Knockback stat;
-- resistant enemies less, see EnemySim/World.push). Effect: "Pulse" with the center and radius. Behavior for WeaponService/Arsenal; drawn by
-- WeaponRenderer/Visuals/Shockwave.

local Arsenal = require(script.Parent.Parent.Arsenal)

local found: { number } = {}

local Shockwave = {}

function Shockwave.fire(weapon: Arsenal.Weapon, ctx: Arsenal.Context): boolean
	local stats = weapon.stats
	local count = ctx:queryCircle(ctx.x, ctx.z, stats.radius, found)
	if count == 0 then
		return false
	end
	ctx:emit(weapon, { kind = "Pulse", x = ctx.x, z = ctx.z, radius = stats.radius })
	for i = 1, count do
		ctx:hit(weapon, found[i])
	end
	return true
end

return Shockwave
