--!strict
-- Kept per-weapon targets for the original weapon behaviors (BrotatoProjectile, BrotatoMelee, BrotatoWhip): a weapon
-- stays on its enemy until that one leaves range or another is clearly closer, instead of jumping every attack.
local Arsenal = require(script.Parent.Arsenal)
local Rules = require(game:GetService("ReplicatedStorage").Shared.Config.Combat).originalWeapons

local WeaponTarget = {}

local function squaredDistance(ctx: Arsenal.Context, id: number): number?
	local x, z = ctx:enemyPosition(id)
	if not x or not z then
		return nil
	end
	return (x - ctx.x) ^ 2 + (z - ctx.z) ^ 2
end

-- Fills `out` like ctx:nearestEnemies around the owner (closest first, at most maxCount) and returns the count, but
-- puts the weapon's kept target first while it is in range and no enemy is under targetSwitchRatio of its distance.
function WeaponTarget.pick(
	weapon: Arsenal.Weapon,
	ctx: Arsenal.Context,
	range: number,
	maxCount: number,
	out: { number }
): number
	local found = ctx:nearestEnemies(ctx.x, ctx.z, range, math.max(maxCount, Rules.targetCandidates), out)
	if found == 0 then
		weapon.state.targetId = nil
		return 0
	end
	local kept = weapon.state.targetId
	if kept and out[1] ~= kept then
		for index = 2, found do
			if out[index] == kept then
				local keptDistance = squaredDistance(ctx, kept)
				local nearestDistance = squaredDistance(ctx, out[1])
				if
					keptDistance
					and nearestDistance
					and nearestDistance >= keptDistance * Rules.targetSwitchRatio ^ 2
				then
					for shift = index, 2, -1 do
						out[shift] = out[shift - 1]
					end
					out[1] = kept
				end
				break
			end
		end
	end
	weapon.state.targetId = out[1]
	return math.min(found, maxCount)
end

return WeaponTarget
