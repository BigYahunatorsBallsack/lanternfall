--!strict
-- Native crossing warning, fixed path and no-kill exit; EnemySim adapters own clocks, position and removal.
local Facts = require(game:GetService("ReplicatedStorage").Shared.Config.NativeCrossingPaths)
local Crossing = {}
export type Rule = { warningSeconds: number, maxYDiff: number }
export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }
export type State = {
	phase: "Dormant" | "Warning" | "Ready" | "Moving" | "Removed",
	warningClock: number,
	dx: number,
	dz: number,
	targetX: number,
	targetZ: number,
	rotation: number,
}
function Crossing.new(): State
	return { phase = "Dormant", warningClock = 0, dx = 0, dz = 0, targetX = 0, targetZ = 0, rotation = 0 }
end
-- Movement-component reveal state, not a global contact predicate: inherited Enemy physics
-- can enable the Hitbox during Warning. Timeout itself enables visibility, hurt, hit AND body.
function Crossing.active(state: State): boolean
	return state.phase == "Ready" or state.phase == "Moving"
end
function Crossing.advanceWarning(state: State, rule: Rule, dt: number)
	if state.phase == "Warning" then
		state.warningClock += dt
		if state.warningClock >= rule.warningSeconds then
			state.phase = "Ready"
		end
	end
end
-- Return corrected position and the unnormalized saved vector, matching get_movement.
-- The caller applies speed and delta, then calls again with the actual post-collision position.
function Crossing.movement(
	state: State,
	rule: Rule,
	bounds: Bounds,
	x: number,
	z: number,
	rng: () -> number
): (number, number, number, number)
	if state.phase == "Dormant" then
		state.phase = "Warning"
	end
	if state.phase == "Warning" or state.phase == "Removed" then
		return x, z, 0, 0
	end
	if state.phase == "Ready" then
		z += (rng() * 2 - 1) * Facts.rules.initialJitterStuds
		local width = bounds.maxX - bounds.minX
		state.targetX = x + (if x < (bounds.minX + bounds.maxX) / 2 then width else -width)
		state.targetZ = z + (rng() * 2 - 1) * (bounds.maxZ - bounds.minZ) / 2 / rule.maxYDiff
		state.dx, state.dz = state.targetX - x, state.targetZ - z
		state.rotation = math.atan2(state.dz, state.dx) + (if state.dx < 0 then math.pi else 0)
		state.phase = "Moving"
	end
	local margin = Facts.rules.exitOvershootStuds
	if (state.dx < 0 and x < state.targetX - margin) or (state.dx >= 0 and x > state.targetX + margin) then
		state.phase = "Removed"
		state.dx, state.dz, state.targetX, state.targetZ = 0, 0, 0, 0
	end
	return x, z, state.dx, state.dz
end
return Crossing
