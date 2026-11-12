--!strict
-- Native environmental projectile collision/lifetime; Volleys delegates only marked environmental shots here.
local Shared = game:GetService("ReplicatedStorage").Shared
local Motion = require(Shared.Util.NativeBulletMotion)
local entryDistance = require(Shared.Util.SegmentCircle).entry
local C = require(Shared.Config.NativeBulletHell).rules
local PIXELS = require(Shared.Config.Stats).range.studsPerPoint
local Types = require(Shared.Net.Types)
local EnvironmentShot = {}
-- Return target index (zero for directional exit), and nominal distance on the base velocity, or nil while alive.
function EnvironmentShot.step(
	shot: any,
	dt: number,
	params: any,
	xs: { number },
	zs: { number },
	count: number,
	radii: { number }?
): (number?, number?)
	local motion: Types.EnemyShotMotion = shot.motion
	local start = shot.flown / shot.speed
	local finish = math.min(start + dt, shot.range / shot.speed)
	local at = start
	local margin = C.exitMarginPixels * PIXELS
	while at < finish - 1e-9 do
		local nextFrame = (math.floor(at * C.physicsRate + 1e-7) + 1) / C.physicsRate
		local after = math.min(finish, nextFrame)
		local ox, oz = Motion.offset(at, shot.dx, shot.dz, shot.speed, motion)
		local nx, nz = Motion.offset(after, shot.dx, shot.dz, shot.speed, motion)
		local x, z = shot.x + ox, shot.z + oz
		local vx, vz = nx - ox, nz - oz
		local length = math.sqrt(vx * vx + vz * vz)
		local nearest: number? = nil
		local target = 0
		if length > 0 then
			for index = 1, count do
				local entry = entryDistance(
					x,
					z,
					vx / length,
					vz / length,
					length,
					xs[index],
					zs[index],
					(if radii then radii[index] else params.playerRadius) + shot.radius
				)
				if entry and entry < (nearest or math.huge) then
					nearest, target = entry, index
				end
			end
		end
		if nearest then
			return target, (at + (after - at) * nearest / length) * shot.speed
		end
		local endX, endZ = shot.x + nx, shot.z + nz
		if
			(shot.dx > 0 and endX > params.maxX + margin)
			or (shot.dx < 0 and endX < params.minX - margin)
			or (shot.dz > 0 and endZ > params.maxZ + margin)
			or (shot.dz < 0 and endZ < params.minZ - margin)
		then
			return 0, after * shot.speed
		end
		at = after
	end
	return nil, nil
end
return EnvironmentShot
