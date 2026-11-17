--!strict
-- Original Boss timer callback selection; future native boss controllers supply actual timeout events and synchronous phase side effects.
local C = require(game:GetService("ReplicatedStorage").Shared.Config.NativeBossPhases)
local Phases = {}
export type Phase = { hpStart: number, timerStart: number }
export type Binding = { usesBasePhaseTimer: boolean, states: { Phase } }
export type State = { current: number, elapsed: number, binding: Binding }

function Phases.new(binding: Binding): State
	assert(binding.usesBasePhaseTimer, "Boss has a custom phase timer; a dedicated controller is required")
	return { current = C.initialState, elapsed = 0, binding = binding }
end

-- This is one real Timer.timeout, not a frame/delta catch-up loop. Source state indices start at zero.
function Phases.onTimeout(
	state: State,
	hpFraction: number | (() -> number),
	changed: ((number, Phase) -> ())?
): { number }
	state.elapsed += C.elapsedPerTimeout
	local changes = {}
	for position, phase in state.binding.states do
		local index = position - 1
		if state.current < index then
			local health = if type(hpFraction) == "function" then hpFraction() else hpFraction
			if health <= phase.hpStart or state.elapsed >= phase.timerStart then
				state.current = index
				table.insert(changes, index)
				if changed then
					changed(index, phase)
				end
			end
		end
	end
	return changes
end

return Phases
