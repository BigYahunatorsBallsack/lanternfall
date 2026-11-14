--!strict
-- Native neutral charge timers and sampled directions; World owns motion, collision and faction transfer.
local Enemies = require(game:GetService("ReplicatedStorage").Shared.Config.Enemies)
local Target = require(script.Parent.NativeChargeTarget)
local Charge = {}
export type State = {
	stage: string,
	remaining: number,
	left: number,
	direction: number,
	directionZ: number,
	originalMass: number,
	bonus: number,
	walkDt: number,
	rushDt: number,
	deflecting: boolean,
	shotsTaken: number,
}
local EPSILON = 1e-9
local function cooldown(rule: Enemies.NativeCharge, random: () -> number): number
	local low = math.max(rule.minimumCooldown, rule.cooldown - rule.jitter)
	return low + random() * (rule.cooldown + rule.jitter - low)
end
function Charge.new(rule: Enemies.NativeCharge, mass: number, random: () -> number): State
	return {
		stage = "Walk",
		remaining = cooldown(rule, random),
		left = 0,
		direction = 1,
		directionZ = 0,
		originalMass = math.floor(mass),
		bonus = 0,
		walkDt = 0,
		rushDt = 0,
		deflecting = false,
		shotsTaken = 0,
	}
end
local function advanceCooldown(state: State, rule: Enemies.NativeCharge, dt: number)
	state.remaining = math.max(0, state.remaining - dt)
	if rule.deflectStopBeforeCooldown and state.remaining <= rule.deflectStopBeforeCooldown then
		state.deflecting = false
	end
end
-- Timers continue without a target. Leftover time crosses phase boundaries rather than lengthening each phase by a server tick.
function Charge.step(
	state: State,
	rule: Enemies.NativeCharge,
	dt: number,
	dx: number,
	dz: number,
	hasTarget: boolean,
	random: () -> number,
	accessibility: number,
	inputX: number?,
	inputZ: number?
): boolean
	state.walkDt, state.rushDt = 0, 0
	local bonusChanged = false
	while true do
		if state.stage == "Walk" then
			if not hasTarget or not Target.inRange(rule, dx, dz) then
				advanceCooldown(state, rule, dt)
				state.walkDt += dt
				return bonusChanged
			end
			local used = math.min(dt, state.remaining)
			state.walkDt += used
			advanceCooldown(state, rule, used)
			dt -= used
			if state.remaining > EPSILON then
				return bonusChanged
			end
			state.stage, state.left = "Windup", rule.fireAt
			if not rule.target or not rule.target.atShoot then
				state.direction, state.directionZ = Target.direction(rule, dx, dz, inputX or 0, inputZ or 0, random)
			end
		else
			local used = math.min(dt, state.left)
			state.left = math.max(0, state.left - used)
			advanceCooldown(state, rule, used)
			dt -= used
			if state.stage == "Rush" then
				state.rushDt += used
			end
			if state.left > EPSILON then
				return bonusChanged
			end
			if state.stage == "Windup" then
				if rule.target and rule.target.atShoot and hasTarget then
					state.direction, state.directionZ = Target.direction(rule, dx, dz, inputX or 0, inputZ or 0, random)
				end
				state.stage, state.left = "Rush", rule.duration
				state.shotsTaken += 1
				if rule.longEvery and rule.longEvery > 0 and state.shotsTaken >= rule.longEvery then
					state.shotsTaken = 0
					state.remaining = assert(rule.longCooldown, "Long charge cooldown required") + rule.duration
				else
					state.remaining = cooldown(rule, random) + rule.duration
				end
				state.deflecting = rule.deflectStopBeforeCooldown ~= nil
				state.bonus = rule.speed * accessibility
				bonusChanged = true
			elseif state.stage == "Rush" then
				state.stage, state.left = "Recover", rule.recovery
				bonusChanged = true
			else
				state.stage = "Walk"
			end
		end
		if dt <= EPSILON then
			return bonusChanged
		end
	end
end
return Charge
