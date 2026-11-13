--!strict
-- Native Jungle movement policies separate sprite-inset goal rectangles, physical origin borders and target body masks; World owns state.
local Shared = game:GetService("ReplicatedStorage").Shared
local Enemies = require(Shared.Config.Enemies)
local Zone = require(Shared.Util.NativeZoneSampling)
local Movement = {}
function Movement.borderMargin(kind: Enemies.Enemy): number?
	local native = kind.nativeMovement
	return if native then (if native.borderClamp then 0 else nil) else kind.radius
end
function Movement.clampPosition(bounds: Zone.Rect, kind: Enemies.Enemy, x: number, z: number): (number, number)
	local margin = Movement.borderMargin(kind)
	if not margin then
		return x, z
	end
	return math.clamp(x, bounds.minX + margin, bounds.maxX - margin),
		math.clamp(z, bounds.minZ + margin, bounds.maxZ - margin)
end
function Movement.collidesTargets(global: boolean?, kind: Enemies.Enemy): boolean
	local native = kind.nativeMovement
	return global ~= false and (not native or native.collidePlayers)
end
function Movement.goal(
	bounds: Zone.Rect,
	kind: Enemies.Enemy,
	wander: Enemies.Wander,
	range: number,
	tx: number,
	tz: number,
	circles: { Zone.Circle }?,
	random: () -> number
): (number, number)
	local native = assert(kind.nativeMovement, "Native movement requires source geometry")
	local minX, maxX = bounds.minX + native.goalInsetX, bounds.maxX - native.goalInsetX
	local minZ, maxZ = bounds.minZ + native.goalInsetZ, bounds.maxZ - native.goalInsetZ
	local function draw(): (number, number)
		if wander.around == "Target" then
			return math.clamp(tx + (random() * 2 - 1) * range, minX, maxX),
				math.clamp(tz + (random() * 2 - 1) * range, minZ, maxZ)
		end
		return minX + random() * (maxX - minX), minZ + random() * (maxZ - minZ)
	end
	return Zone.goal(draw, circles)
end
return Movement
