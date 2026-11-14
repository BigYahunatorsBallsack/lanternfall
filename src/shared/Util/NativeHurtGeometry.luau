--!strict
-- Enemy hurt-circle centers and conservative origin-hash extents; World and projectile services use live geometry independently of body/origin positions.
local Hurt = {}
export type Kind = { radius: number, hurtRadius: number?, nativeHurtOffsetX: number?, nativeHurtOffsetZ: number? }
function Hurt.center(kind: Kind, x: number, z: number): (number, number)
	return x + (kind.nativeHurtOffsetX or 0), z + (kind.nativeHurtOffsetZ or 0)
end
function Hurt.extent(kind: Kind): number
	local x, z = kind.nativeHurtOffsetX or 0, kind.nativeHurtOffsetZ or 0
	local radius = kind.hurtRadius or kind.radius
	return if x == 0 and z == 0 then radius else radius + math.sqrt(x * x + z * z)
end
return Hurt
