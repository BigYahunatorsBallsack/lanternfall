--!strict
-- Engineer's native per-second common spawn square; StructureService supplies sources, bounds and its random stream.
local C = require(game:GetService("ReplicatedStorage").Shared.Config.Structures).nativeGrouping
local Placement = {}
function Placement.inArea(base: Vector3, area: number, bounds: any, obstacles: { any }, random: () -> number): Vector3
	local edge = math.min(C.edge, math.min(bounds.halfX, bounds.halfZ) * 2 * C.edgeLimitShare)
	local half = area / 2
	local x =
		math.clamp(base.X, bounds.center.X - bounds.halfX + edge + half, bounds.center.X + bounds.halfX - edge - half)
	local z =
		math.clamp(base.Z, bounds.center.Z - bounds.halfZ + edge + half, bounds.center.Z + bounds.halfZ - edge - half)
	for _ = 1, C.placementTries do
		local nx, nz = x + (random() * 2 - 1) * half, z + (random() * 2 - 1) * half
		local valid = true
		for _, o in obstacles do
			if (nx - o.x) ^ 2 + (nz - o.z) ^ 2 <= o.radius ^ 2 then
				valid = false
				break
			end
		end
		if valid then
			return Vector3.new(nx, bounds.center.Y, nz)
		end
	end
	-- ZoneService.push_out_of_forbidden retains the square center after five rejected candidates.
	for _, o in obstacles do
		local dx, dz = x - o.x, z - o.z
		local length = math.sqrt(dx * dx + dz * dz)
		if length <= o.radius then
			if length < 0.001 then
				dx, dz, length = 1, 0, 1
			end
			x, z = o.x + dx / length * (o.radius + C.forbiddenPush), o.z + dz / length * (o.radius + C.forbiddenPush)
		end
	end
	return Vector3.new(x, bounds.center.Y, z)
end
function Placement.base(bounds: any, obstacles: { any }, random: () -> number): Vector3
	local area = math.floor(bounds.halfX * 2 / C.baseAreaDivisor * 10) / 10
	return Placement.inArea(bounds.center, area, bounds, obstacles, random)
end
function Placement.area(count: number): number
	return math.min(C.maximumArea, C.baseArea + count * C.perSourceArea)
end
return Placement
