--!strict
-- Shared native area-entry guards for ranged projectiles and Boomerang; WeaponService supplies live enemy callbacks.
export type Adapter = {
	active: (number) -> (boolean, boolean?), -- active now, capable of reflecting on a later entry
	target: (number, () -> number) -> (number?, number?),
	overlaps: (number, number, number, number) -> boolean,
}
type State = { hit: { [number]: boolean }, defenseOverlaps: { [number]: boolean }? }
local adapter: Adapter? = nil
local Defense = {}
function Defense.configure(callbacks: Adapter)
	adapter = callbacks
end
function Defense.refresh(state: State, x: number, z: number, radius: number)
	if adapter and state.defenseOverlaps then
		for id in state.defenseOverlaps do
			if not adapter.overlaps(id, x, z, radius) then
				state.defenseOverlaps[id] = nil
			end
		end
	end
end
function Defense.candidate(state: State, id: number, kind: string, petOrigin: number?): (boolean, boolean)
	local capable = false
	if adapter and (kind == "Ranged" or (kind == "Pet" and petOrigin == 1)) then
		local active, potential = adapter.active(id)
		capable = active or potential == true
	end
	return (not state.hit[id] or capable) and not (state.defenseOverlaps and state.defenseOverlaps[id]) or false,
		capable
end
-- Call immediately before resolving the hit: an earlier hit in this sweep may have killed the defender.
function Defense.enter(state: State, id: number, capable: boolean): boolean
	if not capable then
		return false
	end
	state.defenseOverlaps = state.defenseOverlaps or {}
	state.defenseOverlaps[id] = true
	return if adapter then adapter.active(id) else false
end
function Defense.direction(id: number, x: number, z: number, random: () -> number): number
	local tx, tz = assert(adapter, "Projectile defense adapter required").target(id, random)
	return if tx and tz then math.atan2(tz - z, tx - x) else (random() * 2 - 1) * math.pi
end
return Defense
