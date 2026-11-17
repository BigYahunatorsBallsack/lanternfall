--!strict
-- Source JumpAttackBehavior timers and screen-plane trajectory; called by World; motion math is shared with client presentation.
local Motion = require(game:GetService("ReplicatedStorage").Shared.Util.NativeJumpMotion)
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
		state.x, state.z, state.height =
			Motion.sample(rule, state.startX, state.startZ, state.targetX, state.targetZ, state.jumpAge)
		state.groundX, state.groundZ = state.x, state.z + state.height
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
