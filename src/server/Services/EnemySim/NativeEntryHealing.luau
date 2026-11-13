--!strict
-- Source enemy-mask entry healing for hostile or charmed Stintaosaurus; World and EnemySim supply the hostile body world.
local Enemies = require(game:GetService("ReplicatedStorage").Shared.Config.Enemies)
local Healing = {}
function Healing.step(
	world: any,
	sourceId: number,
	wave: number,
	x: number,
	z: number,
	rule: Enemies.Pulse,
	previous: { [number]: boolean }?
): ({ [number]: boolean }, boolean)
	local inside: { [number]: boolean } = {}
	local found = world.hash:query(x, z, rule.radius + world.maxRadius, world.scratch)
	local healed = false
	for slot = 1, found do
		local i = world.scratch[slot]
		local id = world.ids[i]
		local kind = world.kinds[i]
		if id == sourceId or world.hp[i] <= 0 or kind.id == "Tree" then
			continue
		end
		local reach = rule.radius + kind.radius
		if (world.xs[i] - x) ^ 2 + (world.zs[i] - z) ^ 2 > reach * reach then
			continue
		end
		inside[id] = true
		if (not previous or not previous[id]) and world.hp[i] < world.maxHp[i] then
			world.hp[i] =
				math.min(world.maxHp[i], world.hp[i] + (rule.healFlat or 0) + (rule.healPerWave or 0) * (wave - 1))
			healed = true
		end
	end
	return inside, healed
end
return Healing
