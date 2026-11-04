--!strict
-- Stable held-weapon positions shared by server shot origins and client weapon sprites.

local Shared = script.Parent.Parent
local Visuals = require(Shared.Config.WeaponVisuals)

local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))

local WeaponPose = {}

function WeaponPose.direction(uid: number): (number, number)
	local angle = uid * GOLDEN_ANGLE
	return math.cos(angle), math.sin(angle)
end

function WeaponPose.anchor(x: number, z: number, uid: number): (number, number)
	local dx, dz = WeaponPose.direction(uid)
	return x + dx * Visuals.holdRadius, z + dz * Visuals.holdRadius
end

function WeaponPose.muzzle(
	x: number,
	z: number,
	uid: number,
	dx: number,
	dz: number,
	targetDistance: number?
): (number, number)
	local hx, hz = WeaponPose.anchor(x, z, uid)
	local distance =
		math.min(Visuals.muzzleDistance, math.max(0, (targetDistance or math.huge) - Visuals.muzzleClearance))
	return hx + dx * distance, hz + dz * distance
end

return WeaponPose
