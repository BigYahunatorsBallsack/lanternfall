--!strict
-- Source-backed Baby T-Rex boost state and independent collision growth; World owns timer stepping and faction transfer.
local Enemies = require(game:GetService("ReplicatedStorage").Shared.Config.Enemies)
local Pursuer = {}
export type State = { stage: number, clock: number, baseDamage: number, referenceSpeed: number? }
function Pursuer.new(damage: number): State
	return { stage = 0, clock = 0, baseDamage = damage, referenceSpeed = nil }
end
function Pursuer.step(
	rule: Enemies.Pursuer,
	state: State,
	kind: Enemies.Enemy,
	dt: number
): (Enemies.Enemy?, number, number?)
	if state.stage >= rule.maxSteps then
		return nil, 0, nil
	end
	state.clock += dt
	local count = math.min(rule.maxSteps - state.stage, math.floor(state.clock / rule.everySeconds))
	if count <= 0 then
		return nil, 0, nil
	end
	state.clock -= count * rule.everySeconds
	local previous = state.stage
	state.stage += count
	local speed = count * rule.speedPerStep
	if previous < rule.changeAt and state.stage >= rule.changeAt then
		speed += rule.changeSpeed
	end
	local before = 1 + previous * rule.sizePerStep * rule.collisionScalingShare
	local after = 1 + state.stage * rule.sizePerStep * rule.collisionScalingShare
	local grown = table.clone(kind)
	grown.radius = kind.radius * after / before
	grown.hurtRadius = (kind.hurtRadius or kind.radius) * after / before
	grown.hitRadius = (kind.hitRadius or kind.radius) * after / before
	return grown, speed, math.round(state.baseDamage * (1 + rule.damagePercentPerStep * state.stage / 100))
end
function Pursuer.cap(rule: Enemies.Pursuer, state: State, speed: number): number
	local reference = state.referenceSpeed
	return if reference and reference >= 0 then math.min(speed, reference * rule.playerSpeedShare) else speed
end
return Pursuer
