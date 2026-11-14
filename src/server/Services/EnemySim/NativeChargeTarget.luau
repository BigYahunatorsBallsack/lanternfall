--!strict
-- Native charge range gates and around-player targets; NativeStraightCharge samples these at the source animation method boundary.
local Enemies = require(game:GetService("ReplicatedStorage").Shared.Config.Enemies)
local PointScale = require(game:GetService("ReplicatedStorage").Shared.Config.Stats).range.studsPerPoint
local Target = {}
function Target.inRange(rule: Enemies.NativeCharge, dx: number, dz: number): boolean
	if rule.rangeX and rule.rangeX >= 0 then
		return math.abs(dx) < rule.rangeX
	elseif rule.rangeZ >= 0 then
		return math.abs(dz) < rule.rangeZ
	end
	-- Utils.is_between takes integer arguments: distance is truncated in original pixel units before comparison.
	local distance = math.floor(math.sqrt(dx * dx + dz * dz) / PointScale)
	return distance >= math.round(assert(rule.minRange, "Native radial charge requires minRange") / PointScale)
		and distance <= math.round(assert(rule.maxRange, "Native radial charge requires maxRange") / PointScale)
end
function Target.direction(
	rule: Enemies.NativeCharge,
	dx: number,
	dz: number,
	mx: number,
	mz: number,
	random: () -> number
): (number, number)
	local target = rule.target
	if not target then
		return if dx < 0 then -1 else 1, 0
	end
	local radius = target.radius
	-- The source consumes both square draws even when the movement-cone branch replaces their result.
	local rx, rz = (random() * 2 - 1) * radius, (random() * 2 - 1) * radius
	local moving = math.sqrt(mx * mx + mz * mz)
	if target.inMovementDirection and moving > 0 then
		local angle = (random() * 2 - 1) * target.coneHalfAngle
		local c, s = math.cos(angle), math.sin(angle)
		local distance = radius * (target.minimumRadiusShare + random() * (1 - target.minimumRadiusShare))
		rx, rz = (mx * c - mz * s) / moving * distance, (mx * s + mz * c) / moving * distance
	end
	local behind = math.sqrt(dx * dx + dz * dz)
	if behind > 0 then
		rx += dx / behind * radius
		rz += dz / behind * radius
	end
	dx, dz = dx + rx, dz + rz
	local length = math.sqrt(dx * dx + dz * dz)
	return if length > 0 then dx / length else 0, if length > 0 then dz / length else 0
end
return Target
