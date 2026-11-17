--!strict
-- Source Dimetrodon hurt-origin flag and strict death-time gate; called by World and EnemySim before death emission.
local Death = {}
export type State = { enabled: boolean }
function Death.new(): State
	return { enabled = true }
end
function Death.hurt(state: State, kind: string, petShoots: number?)
	if kind == "Ranged" then
		state.enabled = true
	elseif kind == "Melee" then
		state.enabled = false
	elseif kind == "Pet" then
		state.enabled = petShoots == 1
	end
end
function Death.allowed(state: State, remaining: number, cleanup: boolean, cutoff: number): boolean
	return state.enabled and not cleanup and remaining > cutoff
end
return Death
