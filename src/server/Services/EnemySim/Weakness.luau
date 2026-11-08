--!strict
-- Native percent-damage-taken groups used by EnemySim; weapon source ids share stacks across players and tiers.
type Group = { percent: number, duration: number, remaining: number, stacks: number, maximum: number }
local Weakness = {}
Weakness.__index = Weakness
export type Weakness = typeof(setmetatable({} :: { targets: { [number]: { [string]: Group } } }, Weakness))
function Weakness.new(): Weakness
	return setmetatable({ targets = {} }, Weakness)
end
function Weakness.apply(self: Weakness, id: number, source: string, percent: number, duration: number, maximum: number)
	local groups = self.targets[id]
	if not groups then
		groups = {}
		self.targets[id] = groups
	end
	local group = groups[source]
	if group then
		group.percent = math.max(group.percent, percent)
		group.maximum = math.max(group.maximum, maximum)
		group.duration = math.max(group.duration, duration)
		group.remaining = group.duration
		group.stacks = math.min(group.maximum, group.stacks + 1)
	else
		groups[source] = { percent = percent, duration = duration, remaining = duration, stacks = 1, maximum = maximum }
	end
end
function Weakness.bonus(self: Weakness, id: number): number
	local groups = self.targets[id]
	if not groups then
		return 0
	end
	local total = 0
	for _, group in groups do
		total += group.percent * group.stacks
	end
	return total
end
function Weakness.step(self: Weakness, dt: number)
	for id, groups in self.targets do
		for source, group in groups do
			group.remaining -= dt
			if group.remaining <= 0 then
				groups[source] = nil
			end
		end
		if next(groups) == nil then
			self.targets[id] = nil
		end
	end
end
function Weakness.remove(self: Weakness, id: number)
	self.targets[id] = nil
end
function Weakness.clear(self: Weakness)
	table.clear(self.targets)
end
return Weakness
