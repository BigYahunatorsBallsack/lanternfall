--!strict
-- Native additive enemy speed penalties; World composes these with its existing movement and snapshot paths.
local C = require(game:GetService("ReplicatedStorage").Shared.Config.Combat).nativeSlows
type State = { bonus: number, hold: number }
local Slow = {}
Slow.__index = Slow
export type Slow = typeof(setmetatable({} :: { targets: { [number]: State } }, Slow))
function Slow.new(): Slow
	return setmetatable({ targets = {} }, Slow)
end
function Slow.add(self: Slow, id: number, speed: number, value: number, hold: number)
	local state = self.targets[id]
	if not state then
		state = { bonus = 0, hold = 0 }
		self.targets[id] = state
	end
	value = math.modf(value)
	if value < 0 and hold > 0 then
		state.hold = math.max(state.hold, hold)
	end
	if state.bonus < -speed * C.stopAddingShare then
		return
	end
	if state.bonus < -speed * C.diminishAfterShare then
		value = math.modf(value / C.diminishDivisor)
	end
	value = math.modf(math.max(value, -speed * C.maximumAdditionShare))
	state.bonus += value
end
function Slow.factor(self: Slow, id: number, speed: number): number
	local state = self.targets[id]
	return if state and speed > 0 then math.max(0, 1 + state.bonus / speed) else 1
end
function Slow.active(self: Slow, id: number): boolean
	local state = self.targets[id]
	return state ~= nil and state.bonus < 0
end
function Slow.step(self: Slow, dt: number)
	for id, state in self.targets do
		if state.bonus < 0 then
			if state.hold > 0 then
				state.hold = math.max(0, state.hold - dt)
			else
				state.bonus = math.min(0, state.bonus + C.recoveryPointsPerSecond * dt)
			end
		end
		if state.bonus == 0 and state.hold == 0 then
			self.targets[id] = nil
		end
	end
end
function Slow.remove(self: Slow, id: number)
	self.targets[id] = nil
end
function Slow.clear(self: Slow)
	table.clear(self.targets)
end
return Slow
