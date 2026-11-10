--!strict
-- ZoneService upgraded-bait group facts; SpawnDirector appends these repeating native groups every wave.
local C = require(game:GetService("ReplicatedStorage").Shared.Config.CharacterMechanics).fisherman
local Fishing = {}
function Fishing.groups(count: number, random: () -> number): { any }
	local groups = {}
	if count <= 0 then
		return groups
	end
	local number = math.max(1, math.floor(count / C.groupEvery))
	local bonus = math.max(0, math.floor(count / C.bonusEvery))
	for i = 0, number - 1 do
		local edge = random() > C.randomSplit
		local globalArea = random() > C.randomSplit
		local area = if globalArea then -1 else math.floor(C.areaMinimum + random() * (C.areaMaximum - C.areaMinimum))
		local interval = math.round(C.repeatMinimum + random() * (C.repeatMaximum - C.repeatMinimum))
		local minimum = C.baseCount + bonus
		local maximum = math.round(minimum + random()) + bonus
		table.insert(groups, {
			timing = math.max(C.minimumTiming, math.floor(i * C.timingSpan / number + 1)),
			repeating = C.repeats,
			interval = interval,
			reduceInterval = 0,
			minInterval = 1,
			area = area,
			edgeMargin = 0,
			edge = edge,
			chance = 1,
			loot = false,
			neutral = false,
			boss = false,
			preventIfElite = false,
			preventIfHorde = false,
			minDanger = 0,
			maxDanger = C.maximumDanger,
			minWave = 0,
			maxWave = C.maximumWave,
			units = {
				{ enemy = C.enemy, min = minimum, max = maximum, chance = 1, neutral = false, extraDistance = 0 },
			},
		})
	end
	return groups
end
return Fishing
