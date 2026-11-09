--!strict
-- Sticky Grenade flight, attachment and delayed explosion; BrotatoProjectile delegates this family here.
local Shared = game:GetService("ReplicatedStorage").Shared
local Arsenal = require(script.Parent.Arsenal)
local Combat = require(script.Parent.BrotatoCombat)
local Entry = require(Shared.Util.SegmentCircle).entry
type Shot = {
	id: number,
	x: number,
	z: number,
	dx: number,
	dz: number,
	flown: number,
	stats: { [string]: number },
	fuseUntil: number?,
	targetId: number?,
	offsetX: number?,
	offsetZ: number?,
}
local Sticky = {}
local candidates: { number } = {}
local function startFuse(weapon: Arsenal.Weapon, ctx: Arsenal.Context, shot: Shot, target: number?)
	shot.fuseUntil = ctx.now + shot.stats.stickyFuse
	shot.targetId = target
	if target then
		local x, z = ctx:enemyPosition(target)
		if x and z then
			shot.offsetX, shot.offsetZ = shot.x - x, shot.z - z
		end
	end
	ctx:emit(weapon, { kind = "End", id = shot.id, x = shot.x, z = shot.z, distance = shot.flown })
	ctx:emit(weapon, { kind = "Drop", id = shot.id, x = shot.x, z = shot.z, duration = shot.stats.stickyFuse })
end
function Sticky.step(weapon: Arsenal.Weapon, ctx: Arsenal.Context, shot: Shot, dt: number): boolean
	if shot.fuseUntil then
		if shot.targetId then
			local x, z = ctx:enemyPosition(shot.targetId)
			if x and z then
				local oldX, oldZ = shot.x, shot.z
				shot.x, shot.z = x + (shot.offsetX or 0), z + (shot.offsetZ or 0)
				if oldX ~= shot.x or oldZ ~= shot.z then
					ctx:emit(weapon, {
						kind = "Drop",
						id = shot.id,
						x = shot.x,
						z = shot.z,
						duration = math.max(0, shot.fuseUntil - ctx.now),
					})
				end
			else
				shot.targetId = nil
			end
		end
		if ctx.now >= shot.fuseUntil then
			Combat.explode(weapon, ctx, shot.x, shot.z, nil, nil, shot.stats)
			return true
		end
		return false
	end
	local stats = shot.stats
	local move = math.min(stats.projectileSpeed * dt, math.max(0, stats.range - shot.flown))
	local x, z = shot.x + shot.dx * move, shot.z + shot.dz * move
	local count = ctx:querySegment(shot.x, shot.z, x, z, stats.stickyDistance, candidates)
	local first: number? = nil
	local target: number? = nil
	for index = 1, count do
		local id = candidates[index]
		local tx, tz = ctx:enemyPosition(id)
		if tx and tz then
			local entry = Entry(shot.x, shot.z, shot.dx, shot.dz, move, tx, tz, stats.stickyDistance)
			if entry and (not first or entry < first) then
				first, target = entry, id
			end
		end
	end
	local distance = first or move
	shot.x, shot.z = shot.x + shot.dx * distance, shot.z + shot.dz * distance
	shot.flown += distance
	if target or shot.flown >= stats.range then
		startFuse(weapon, ctx, shot, target)
	end
	return false
end
return Sticky
