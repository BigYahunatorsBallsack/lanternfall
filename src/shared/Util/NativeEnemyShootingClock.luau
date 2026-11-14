--!strict
-- Native shooting cooldown and animation-method timing; World stores one clock per opted-in shooter, including across Charm transfers.
local Clock = {}
export type Rule = {
	fireInterval: number,
	cooldownRandomSeconds: number,
	initialSeconds: number,
	fireAt: number,
	animationSeconds: number,
	longEvery: number?,
	longSeconds: number?,
	minimumCooldownSeconds: number?,
}
export type State = { initial: number, remaining: number, stage: string, age: number, fired: boolean, shots: number }
local function cooldown(state: State?, rule: Rule, random: () -> number): number
	if state and rule.longEvery and rule.longEvery > 0 and state.shots >= rule.longEvery then
		state.shots = 0
		return rule.longSeconds or 0
	end
	local low = rule.fireInterval - rule.cooldownRandomSeconds
	if rule.minimumCooldownSeconds then
		low = math.max(rule.minimumCooldownSeconds, low)
	end
	return low + random() * (rule.fireInterval + rule.cooldownRandomSeconds - low)
end
function Clock.new(rule: Rule, random: () -> number): State
	return {
		initial = rule.initialSeconds,
		remaining = cooldown(nil, rule, random),
		stage = "Cooldown",
		age = 0,
		fired = false,
		shots = 0,
	}
end
function Clock.step(state: State, rule: Rule, dt: number, inRange: boolean, random: () -> number): boolean
	if state.initial > 0 then
		local used = math.min(dt, state.initial)
		state.initial -= used
		dt -= used
		if dt <= 1e-9 then
			return false
		end
	end
	local fired = false
	while true do
		if state.stage == "Cooldown" then
			local used = math.min(dt, state.remaining)
			state.remaining = math.max(0, state.remaining - used)
			dt -= used
			if state.remaining > 1e-9 or not inRange then
				return fired
			end
			state.stage = "Animation"
			state.age = 0
			state.fired = false
		end
		local used = math.min(dt, rule.animationSeconds - state.age)
		state.age += used
		dt -= used
		if not state.fired and state.age >= rule.fireAt - 1e-9 then
			state.fired = true
			state.shots += 1
			fired = true
		end
		if state.age < rule.animationSeconds - 1e-9 then
			return fired
		end
		state.stage = "Cooldown"
		state.remaining = cooldown(state, rule, random)
		if dt <= 1e-9 then
			return fired
		end
	end
end
return Clock
