--!strict
-- Enemy outgoing hit-circle centers and conservative origin extents; World checks ordinary and swept contacts independently of hurt/body circles.
local Hit = {}
export type Kind = { radius: number, hitRadius: number?, nativeHitOffsetX: number?, nativeHitOffsetZ: number? }
function Hit.center(kind: Kind, x: number, z: number): (number, number)
	return x + (kind.nativeHitOffsetX or 0), z + (kind.nativeHitOffsetZ or 0)
end
function Hit.extent(kind: Kind): number
	local x, z = kind.nativeHitOffsetX or 0, kind.nativeHitOffsetZ or 0
	local radius = kind.hitRadius or kind.radius
	return if x == 0 and z == 0 then radius else radius + math.sqrt(x * x + z * z)
end
return Hit
