--!strict
-- Angle math for spinning weapons, shared by the server behavior (hits, WeaponService/Behaviors/OrbitBlades) and
-- the client visual (drawing, WeaponRenderer/Visuals/OrbitBlades), so both put the blades in the same place.
-- Angles follow server time (workspace:GetServerTimeNow()) instead of being sent every frame.

local Orbit = {}

local TAU = 2 * math.pi

-- Angle in radians of blade `index` (1-based) of `count` evenly spread blades, spinning at `degreesPerSecond`
-- since server time `startedAt`. 0 points along +X; growing angles turn from +X towards +Z.
function Orbit.bladeAngle(
	degreesPerSecond: number,
	startedAt: number,
	now: number,
	index: number,
	count: number
): number
	return math.rad(degreesPerSecond) * (now - startedAt) + TAU * (index - 1) / math.max(count, 1)
end

return Orbit
