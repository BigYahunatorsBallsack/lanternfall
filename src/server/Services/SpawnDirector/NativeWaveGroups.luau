--!strict
-- Source WaveManager integer-clock and repeat state machine; tested component for the pending native Jungle wave adapter.
local C = require(game:GetService("ReplicatedStorage").Shared.Config.NativeWaveGroups)
local Groups = {}
export type Group = {
	id: string,
	spawn_chance: number,
	spawn_timing: number,
	repeating: number,
	repeating_interval: number,
	reduce_repeating_interval: number,
	min_repeating_interval: number,
	is_boss: boolean,
	is_neutral: boolean,
	prevent_if_elite: boolean,
	prevent_if_horde: boolean,
	min_difficulty: number,
	max_difficulty: number,
}
export type Conditions = { difficulty: number, elite: boolean, horde: boolean, treesStart: boolean }
type Repeat = { group: Group, remaining: number, interval: number, reduction: number, minimum: number, nextAt: number }
export type State = { pending: { Group }, repeats: { Repeat }, duration: number, lastChecked: number }
function Groups.new(groups: { Group }, duration: number): State
	return { pending = table.clone(groups), repeats = {}, duration = duration, lastChecked = C.initialLastChecked }
end
function Groups.add(state: State, groups: { Group })
	for _, group in groups do
		table.insert(state.pending, group)
	end
end
function Groups.clear(state: State)
	table.clear(state.pending)
	table.clear(state.repeats)
end
function Groups.step(state: State, timeLeft: number, conditions: Conditions, chance: (number) -> boolean): { Group }
	local integer = math.modf(timeLeft) -- Godot `as int` truncates toward zero.
	local fired: { Group } = {}
	if integer == state.lastChecked then
		return fired
	end
	state.lastChecked = integer
	local elapsed = state.duration - timeLeft
	local pending: { Group } = {}
	for _, group in state.pending do
		local prevented = (group.prevent_if_horde and conditions.horde) or (group.prevent_if_elite and conditions.elite)
		local startEarly = group.is_boss
			or (group.is_neutral and conditions.treesStart and timeLeft >= state.duration - C.neutralStartWindowSeconds)
		if
			not prevented
			and conditions.difficulty >= group.min_difficulty
			and conditions.difficulty <= group.max_difficulty
			and (group.spawn_timing <= elapsed or startEarly)
		then
			if chance(group.spawn_chance) then
				table.insert(fired, group)
			end
			-- A failed first roll still installs the source repeat; repeats never roll spawn_chance again.
			if group.repeating > 0 then
				table.insert(state.repeats, {
					group = group,
					remaining = group.repeating,
					interval = group.repeating_interval,
					reduction = group.reduce_repeating_interval,
					minimum = group.min_repeating_interval,
					nextAt = state.duration - group.spawn_timing - group.repeating_interval,
				})
			end
		else
			table.insert(pending, group)
		end
	end
	state.pending = pending
	local repeats: { Repeat } = {}
	for _, entry in state.repeats do
		if timeLeft <= entry.nextAt then
			table.insert(fired, entry.group)
			entry.remaining -= 1
			entry.interval = math.max(entry.minimum, entry.interval - entry.reduction)
			entry.nextAt -= entry.interval
		end
		if entry.remaining > 0 then
			table.insert(repeats, entry)
		end
	end
	state.repeats = repeats
	return fired
end
return Groups
