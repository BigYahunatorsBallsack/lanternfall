--!strict
-- Physical enemy body centers and conservative origin-based hash extents; EnemySim.World keeps actor origins unchanged.
local Body = {}
export type Kind = { radius: number, nativeBodyOffsetX: number?, nativeBodyOffsetZ: number? }
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
