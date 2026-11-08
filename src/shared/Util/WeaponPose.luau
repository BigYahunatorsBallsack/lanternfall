--!strict
-- Stable held-weapon positions shared by server shot origins and client weapon sprites.

local Shared = script.Parent.Parent
local Visuals = require(Shared.Config.WeaponVisuals)

local TAU = 2 * math.pi

local WeaponPose = {}

-- The weapon in `slot` (1-based, loadout order) of `count` held weapons: evenly spaced around the figure, so the
-- gaps stay equal whatever uids the copies have. Angle 0 is screen right; +z is down the screen.
function WeaponPose.direction(slot: number, count: number): (number, number)
	local angle = math.rad(Visuals.holdStartDegrees) + TAU * (slot - 1) / math.max(count, 1)
	return math.cos(angle), math.sin(angle)
end

function WeaponPose.radius(id: string): number
	return Visuals.holdRadiusById[id] or Visuals.holdRadius
end

function WeaponPose.anchor(x: number, z: number, slot: number, count: number, id: string): (number, number)
	local dx, dz = WeaponPose.direction(slot, count)
	local radius = WeaponPose.radius(id)
	return x + dx * radius, z + dz * radius
end

function WeaponPose.muzzle(
	x: number,
	z: number,
	slot: number,
	count: number,
	id: string,
	dx: number,
	dz: number,
	targetDistance: number?
): (number, number)
	local hx, hz = WeaponPose.anchor(x, z, slot, count, id)
	local muzzleDistance = (Visuals.spriteStuds[id] or 4) * (Visuals.muzzleFractionById[id] or Visuals.muzzleFraction)
	local distance = math.min(muzzleDistance, math.max(0, (targetDistance or math.huge) - Visuals.muzzleClearance))
	return hx + dx * distance, hz + dz * distance
end

return WeaponPose
