--!strict
-- Physical enemy body centers and conservative origin-based hash extents; EnemySim.World keeps actor origins unchanged.
local Body = {}
local ContactRules = require(script.Parent.Parent.Config.NativeCrossingPaths).rules
export type OneWay = { axisX: number, axisZ: number, margin: number }
export type Kind = {
	radius: number,
	nativeBodyOffsetX: number?,
	nativeBodyOffsetZ: number?,
	nativeBodyLayer: number?,
	nativeBodyMask: number?,
	nativeBodyOneWay: OneWay?,
}
-- Normal points from the other shape to the moving body. Recovery depth is circle overlap.
-- Godot _shape_col_cbk accepts pointA-pointB along the other shape's transformed +Y axis.
function Body.blocks(
	other: { nativeBodyOneWay: OneWay? },
	nx: number,
	nz: number,
	depth: number,
	otherVx: number,
	otherVz: number,
	dt: number
): boolean
	local rule = other.nativeBodyOneWay
	if not rule then
		return true
	end
	local alignment = -(nx * rule.axisX + nz * rule.axisZ)
	local allowance = math.max(0, -(otherVx * rule.axisX + otherVz * rule.axisZ)) * dt
	return alignment >= ContactRules.oneWayContactEpsilon
		and depth <= math.max(rule.margin, ContactRules.bodyMotionMarginStuds) + allowance
end
-- Godot 3.5 CollisionObject2DSW::test_collision_mask uses OR, not mutual consent.
-- Unreviewed legacy records retain their existing collision policy until source masks are supplied.
function Body.collides(a: Kind, b: Kind): boolean
	if a.nativeBodyLayer == nil or a.nativeBodyMask == nil or b.nativeBodyLayer == nil or b.nativeBodyMask == nil then
		return true
	end
	return bit32.btest(a.nativeBodyLayer, b.nativeBodyMask) or bit32.btest(b.nativeBodyLayer, a.nativeBodyMask)
end
function Body.center(kind: Kind, x: number, z: number): (number, number)
	return x + (kind.nativeBodyOffsetX or 0), z + (kind.nativeBodyOffsetZ or 0)
end
function Body.origin(kind: Kind, x: number, z: number): (number, number)
	return x - (kind.nativeBodyOffsetX or 0), z - (kind.nativeBodyOffsetZ or 0)
end
function Body.extent(kind: Kind): number
	local x, z = kind.nativeBodyOffsetX or 0, kind.nativeBodyOffsetZ or 0
	return if x == 0 and z == 0 then kind.radius else kind.radius + math.sqrt(x * x + z * z)
end
return Body
