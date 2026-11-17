--!strict
-- Source PatrolEdgesOfMap target selection with retained goals; called by World for source-bound Dimetrodon and Sea Pig actors.
local Patrol = {}
export type Rule = {
	edgeDistancePoints: number,
	edgeRandomizationPoints: number,
	minimumInsetPoints: number,
	cornerThreshold: number,
	noneDirectionOrder: { string },
	pixel: number,
}
export type State = { edge: number, targetX: number, targetZ: number }
function Patrol.new(rule: Rule, random: () -> number): State
	return {
		edge = math.floor(rule.edgeDistancePoints + (random() * 2 - 1) * rule.edgeRandomizationPoints) * rule.pixel,
		targetX = 0,
		targetZ = 0,
	}
end
local function sideDirection(
	side: string,
	z: number,
	minZ: number,
	maxZ: number,
	edge: number,
	threshold: number,
	random: () -> number
): string
	if z <= minZ + edge then
		return if random() > threshold then "Top" else side
	end
	if z >= maxZ - edge then
		return if random() > threshold then "Bottom" else side
	end
	return side
end
function Patrol.goal(
	rule: Rule,
	state: State,
	x: number,
	z: number,
	precision: number,
	bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
	random: () -> number
): (number, number)
	if
		(state.targetX ~= 0 or state.targetZ ~= 0) and (state.targetX - x) ^ 2 + (state.targetZ - z) ^ 2 > precision ^ 2
	then
		return state.targetX, state.targetZ
	end
	local minX, maxX, minZ, maxZ = bounds.minX, bounds.maxX, bounds.minZ, bounds.maxZ
	local edge = state.edge
	local direction: string? = nil
	if x <= minX + edge then
		direction = sideDirection("Left", z, minZ, maxZ, edge, rule.cornerThreshold, random)
	elseif x >= maxX - edge then
		direction = sideDirection("Right", z, minZ, maxZ, edge, rule.cornerThreshold, random)
	elseif z <= minZ + edge then
		direction = "Top"
	elseif z >= maxZ - edge then
		direction = "Bottom"
	end
	if not direction then
		direction = rule.noneDirectionOrder[math.min(
			#rule.noneDirectionOrder,
			math.floor(random() * #rule.noneDirectionOrder) + 1
		)]
	end
	local inset = rule.minimumInsetPoints * rule.pixel
	local function draw(a: number, b: number): number
		return a + random() * (b - a)
	end
	local gx, gz
	if direction == "Top" then
		gx, gz = draw(minX + inset, maxX - inset), draw(minZ + inset, minZ + edge)
	elseif direction == "Bottom" then
		gx, gz = draw(minX + inset, maxX - inset), draw(maxZ - inset, maxZ - edge)
	elseif direction == "Right" then
		gx, gz = draw(maxX - edge, maxX - inset), draw(minZ + inset, maxZ - inset)
	else
		gx, gz = draw(minX + inset, minX + edge), draw(minZ + inset, maxZ - inset)
	end
	-- The source replaces both coordinates after its normalized max_target_distance calculation.
	state.targetX, state.targetZ = math.clamp(gx, minX, maxX), math.clamp(gz, minZ, maxZ)
	return state.targetX, state.targetZ
end
return Patrol
