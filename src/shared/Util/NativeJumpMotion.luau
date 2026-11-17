--!strict
-- Source JumpAttackBehavior screen-plane trajectory; shared by authoritative jump state and client shadow presentation.
local Motion = {}
export type Rule = { delay: number, duration: number, height: number, riseShare: number, fallEasePower: number }
local function easeInOut(t: number, power: number): number
	return if t < 0.5 then (t * 2) ^ power * 0.5 else (1 - (1 - (t - 0.5) * 2) ^ power) * 0.5 + 0.5
end
function Motion.sample(
	rule: Rule,
	sx: number,
	sz: number,
	tx: number,
	tz: number,
	age: number
): (number, number, number)
	local progress = math.clamp((age - rule.delay) / rule.duration, 0, 1)
	local vertical = if progress < rule.riseShare
		then progress
		else rule.riseShare
			+ easeInOut((progress - rule.riseShare) / (1 - rule.riseShare), rule.fallEasePower)
				* (1 - rule.riseShare)
	local height = if progress >= 1 then 0 else math.sin(vertical * math.pi) * rule.height
	return sx + (tx - sx) * progress, sz + (tz - sz) * progress - height, height
end
return Motion
