--!strict
-- Chain Lightning (DESIGN.md section 6): once the cooldown is over and an enemy is within `range`, lightning strikes
-- the nearest one and jumps on to the nearest enemy not hit yet within jumpRange of the last, until it has hit
-- `jumps` enemies (since B5 plus the Bounce stat, WeaponStats) or finds no one left. Hits land at once. Effect: "Chain" with the owner and every hit enemy as
-- points. Behavior for WeaponService/Arsenal; drawn by WeaponRenderer/Visuals/ChainLightning.

local Arsenal = require(script.Parent.Parent.Arsenal)

local targets: { number } = {}
local found: { number } = {}

local ChainLightning = {}

-- The nearest enemy around (x, z) within `range` that is not in `skip`, or nil.
local function nearestNew(
	ctx: Arsenal.Context,
	x: number,
	z: number,
	range: number,
	skip: { [number]: boolean }
): number?
	local count = ctx:queryCircle(x, z, range, found)
	local best: number? = nil
	local bestSquared = math.huge
	for i = 1, count do
		local id = found[i]
		if not skip[id] then
			local ex, ez = ctx:enemyPosition(id)
			if ex and ez then
				local squared = (ex - x) ^ 2 + (ez - z) ^ 2
				if squared < bestSquared then
					best, bestSquared = id, squared
				end
			end
		end
	end
	return best
end

function ChainLightning.fire(weapon: Arsenal.Weapon, ctx: Arsenal.Context): boolean
	local stats = weapon.stats
	if ctx:nearestEnemies(ctx.x, ctx.z, stats.range, 1, targets) == 0 then
		return false
	end
	local points = { ctx.x, ctx.z }
	local hit: { [number]: boolean } = {}
	local id: number? = targets[1]
	local jumps = math.max(1, math.floor(stats.jumps))
	for _ = 1, jumps do
		local current = id :: number
		local ex, ez = ctx:enemyPosition(current)
		if not (ex and ez) then
			break
		end
		hit[current] = true
		table.insert(points, ex)
		table.insert(points, ez)
		ctx:hit(weapon, current)
		id = nearestNew(ctx, ex, ez, stats.jumpRange, hit)
		if not id then
			break
		end
	end
	ctx:emit(weapon, { kind = "Chain", points = points })
	return true
end

return ChainLightning
