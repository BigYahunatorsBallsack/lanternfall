--!strict
-- Source DetectTargetMovementBehavior one-time speed bonus and movement latch; World owns targets and faction transfer.
local Enemies = require(game:GetService("ReplicatedStorage").Shared.Config.Enemies)
local Detection = {}
export type State = { detected: boolean }
function Detection.new(): State
	return { detected = false }
end
function Detection.step(
	state: State,
	rule: Enemies.NativeDetection,
	distanceSquared: number,
	accessibility: number
): number
	if not state.detected and distanceSquared <= rule.radius * rule.radius then
		state.detected = true
		return rule.speedBonus * accessibility
	end
	return 0
end
return Detection
