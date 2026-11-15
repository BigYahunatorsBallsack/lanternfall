--!strict
-- Source JumpAttackBehavior timers and screen-plane trajectory; tested component, awaiting World collision/attack/render integration.
local Jump = {}
export type Rule = {
	cooldown: number,
	duration: number,
	height: number,
	delay: number,
	landingCooldown: number,
	freshCooldown: number,
	freshLandingCooldown: number,
	riseShare: number,
	fallEasePower: number,
}
export type State = {
	timer: number,
	landingLeft: number,
	jumpAge: number,
	jumping: boolean,
	landed: boolean,
	locked: boolean,
	x: number,
	z: number,
	groundX: number,
	groundZ: number,
	height: number,
	startX: number,
	startZ: number,
	targetX: number,
	targetZ: number,
}
function Jump.new(rule: Rule): State
	return {
		timer = rule.freshCooldown,
		landingLeft = rule.freshLandingCooldown,
		jumpAge = 0,
		jumping = false,
		landed = false,
		locked = false,
		x = 0,
		z = 0,
		groundX = 0,
		groundZ = 0,
		height = 0,
		startX = 0,
		startZ = 0,
		targetX = 0,
		targetZ = 0,
	}
end
function Jump.reset(rule: Rule, state: State)
	state.timer, state.landingLeft, state.jumpAge = rule.cooldown, rule.landingCooldown, 0
	state.jumping, state.landed, state.locked = false, false, false
	state.height = 0
end
-- Godot3.5 Math.ease(t,-power): its negative-curve branch is an in/out power curve.
local function easeInOut(t: number, power: number): number
	return if t < 0.5 then (t * 2) ^ power * 0.5 else (1 - (1 - (t - 0.5) * 2) ^ power) * 0.5 + 0.5
end
function Jump.step(
	rule: Rule,
	state: State,
	dt: number,
	x: number,
	z: number,
	tx: number?,
	tz: number?
): (boolean, boolean)
	if state.jumping then
		state.jumpAge += dt
		if state.jumpAge < rule.delay then
			return false, false
		end
		local progress = (state.jumpAge - rule.delay) / rule.duration
		if progress >= 1 then
			state.x, state.z = state.targetX, state.targetZ
			state.groundX, state.groundZ, state.height = state.targetX, state.targetZ, 0
			state.jumping, state.landed, state.locked = false, true, true
			state.timer = rule.cooldown
			return false, true
		end
		local vertical = if progress < rule.riseShare
			then progress
			else rule.riseShare
				+ easeInOut((progress - rule.riseShare) / (1 - rule.riseShare), rule.fallEasePower)
					* (1 - rule.riseShare)
		state.height = math.sin(vertical * math.pi) * rule.height
		state.groundX = state.startX + (state.targetX - state.startX) * progress
		state.groundZ = state.startZ + (state.targetZ - state.startZ) * progress
		state.x, state.z = state.groundX, state.groundZ - state.height
		return false, false
	end
	state.x, state.z, state.groundX, state.groundZ, state.height = x, z, x, z, 0
	state.timer -= dt
	if state.landed then
		state.landingLeft -= dt
		if state.landingLeft <= 0 then
			state.locked, state.landed = false, false
			state.landingLeft = rule.landingCooldown
		end
	end
	if state.timer <= 0 then
		state.landed = false
		if tx == nil or tz == nil then
			return false, false
		end
		state.startX, state.startZ, state.targetX, state.targetZ = x, z, tx, tz
		state.jumping, state.locked, state.jumpAge = true, true, 0
		return true, false
	end
	return false, false
end
return Jump
