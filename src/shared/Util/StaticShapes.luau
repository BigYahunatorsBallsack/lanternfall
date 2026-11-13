--!strict
--!native
-- Exact circles and capsules for static enemy obstacles; World uses these for hole-compatible push-outs and swept rushes.
local Circle = require(script.Parent.SegmentCircle)
local Shapes = {}
export type Shape = { x: number, z: number, radius: number, halfLength: number?, axisX: number?, axisZ: number? }
-- Capsule axes are unit vectors; halfLength is half the center segment, not half the complete outer length.
function Shapes.closest(x: number, z: number, shape: Shape): (number, number)
	local h = shape.halfLength or 0
	if h <= 0 then
		return shape.x, shape.z
	end
	local ux, uz = shape.axisX or 1, shape.axisZ or 0
	local t = math.clamp((x - shape.x) * ux + (z - shape.z) * uz, -h, h)
	return shape.x + t * ux, shape.z + t * uz
end
function Shapes.contains(x: number, z: number, shape: Shape, bodyRadius: number?): boolean
	local cx, cz = Shapes.closest(x, z, shape)
	local reach = shape.radius + (bodyRadius or 0)
	return (x - cx) ^ 2 + (z - cz) ^ 2 <= reach * reach
end
function Shapes.pushOut(x: number, z: number, shape: Shape, bodyRadius: number, side: number): (number, number)
	local cx, cz = Shapes.closest(x, z, shape)
	local dx, dz = x - cx, z - cz
	local squared = dx * dx + dz * dz
	local reach = shape.radius + bodyRadius
	if squared >= reach * reach then
		return x, z
	end
	if squared <= 1e-12 then
		-- A capsule center-line start must leave perpendicular to the line, rather than along its interior.
		local sign = if side % 2 == 0 then 1 else -1
		dx, dz = -(shape.axisZ or 0) * sign, (shape.axisX or 1) * sign
	else
		local distance = math.sqrt(squared)
		dx, dz = dx / distance, dz / distance
	end
	return cx + dx * reach, cz + dz * reach
end
function Shapes.entry(
	x: number,
	z: number,
	dx: number,
	dz: number,
	length: number,
	shape: Shape,
	bodyRadius: number
): number?
	local h = shape.halfLength or 0
	local reach = shape.radius + bodyRadius
	if h <= 0 then
		return Circle.entry(x, z, dx, dz, length, shape.x, shape.z, reach)
	end
	if Shapes.contains(x, z, shape, bodyRadius) then
		return 0
	end
	local ux, uz = shape.axisX or 1, shape.axisZ or 0
	local first = Circle.entry(x, z, dx, dz, length, shape.x - h * ux, shape.z - h * uz, reach)
	local second = Circle.entry(x, z, dx, dz, length, shape.x + h * ux, shape.z + h * uz, reach)
	local best = if first and second then math.min(first, second) else first or second
	local across = -(x - shape.x) * uz + (z - shape.z) * ux
	local along = (x - shape.x) * ux + (z - shape.z) * uz
	local crossDirection = -dx * uz + dz * ux
	local alongDirection = dx * ux + dz * uz
	if math.abs(crossDirection) > 1e-9 then
		for _, side in { -1, 1 } do
			local at = (side * reach - across) / crossDirection
			if at >= 0 and at <= length and math.abs(along + alongDirection * at) <= h then
				best = if best then math.min(best, at) else at
			end
		end
	end
	return best
end
return table.freeze(Shapes)
