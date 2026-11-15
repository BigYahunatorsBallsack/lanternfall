--!strict
-- Source EvilMob pickup evolution and TargetRandGoldPos position retention; World owns actor state and ExperienceService owns material contacts.
local Eater = {}
export type Rule = {
	thresholds: { number },
	healthPerStage: number,
	resistanceBase: number,
	resistancePerStage: number,
	speedDecrease: number,
}
export type State = { gold: number, stage: number, targetX: number, targetZ: number }
function Eater.new(): State
	return { gold = 0, stage = 0, targetX = 0, targetZ = 0 }
end
function Eater.pickup(rule: Rule, state: State, value: number): (number, boolean)
	state.gold += value
	local nextThreshold = rule.thresholds[state.stage + 2]
	if nextThreshold and state.gold >= nextThreshold then
		state.stage += 1
		return math.floor(1 + rule.healthPerStage * state.stage), true
	end
	return 1, false
end
function Eater.value(state: State): number
	return state.gold * (state.stage + 1)
end
function Eater.resistance(rule: Rule, state: State): number
	return if state.stage == 0
		then rule.resistanceBase
		else math.floor(rule.resistanceBase + rule.resistancePerStage * state.stage)
end
function Eater.bonus(rule: Rule, state: State): number
	return -rule.speedDecrease * state.stage
end
function Eater.goal(
	state: State,
	x: number,
	z: number,
	precision: number,
	bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
	goldXs: { number },
	goldZs: { number },
	random: () -> number
): (number, number)
	if
		(state.targetX == 0 and state.targetZ == 0)
		or (state.targetX - x) ^ 2 + (state.targetZ - z) ^ 2 <= precision ^ 2
	then
		if #goldXs > 0 then
			local index = math.min(#goldXs, math.floor(random() * #goldXs) + 1)
			state.targetX, state.targetZ = goldXs[index], goldZs[index]
		else
			state.targetX = bounds.minX + random() * (bounds.maxX - bounds.minX)
			state.targetZ = bounds.minZ + random() * (bounds.maxZ - bounds.minZ)
		end
	end
	return state.targetX, state.targetZ
end
return Eater
