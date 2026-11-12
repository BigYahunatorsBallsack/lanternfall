--!strict
-- Native shooting cooldown and animation-method timing; World stores one clock per opted-in shooter, including across Charm transfers.
local Clock = {}
export type Rule = {
	fireInterval: number,
	cooldownRandomSeconds: number,
	initialSeconds: number,
	fireAt: number,
	animationSeconds: number,
}
export type State = { initial: number, remaining: number, stage: string, age: number, fired: boolean }
local function cooldown(rule: Rule, random: () -> number): number
	return rule.fireInterval + (random() * 2 - 1) * rule.cooldownRandomSeconds
end
function Clock.new(rule: Rule, random: () -> number): State
	return { initial = rule.initialSeconds, remaining = cooldown(rule, random), stage = "Cooldown", age = 0, fired = false }
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
			fired = true
		end
		if state.age < rule.animationSeconds - 1e-9 then
			return fired
		end
		state.stage = "Cooldown"
		state.remaining = cooldown(rule, random)
		if dt <= 1e-9 then
			return fired
		end
	end
end
return Clock
