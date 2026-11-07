--!strict
--!native
-- First circle entry along a unit-direction segment; shared by enemy shots, rushes and boss dashes.
local SegmentCircle = {}

function SegmentCircle.entry(
	x: number,
	z: number,
	dx: number,
	dz: number,
	length: number,
	cx: number,
	cz: number,
	reach: number
): number?
	local px, pz = cx - x, cz - z
	local squared = px * px + pz * pz
	local reachSquared = reach * reach
	if squared <= reachSquared then
		return 0
	end
	local along = px * dx + pz * dz
	local closestSquared = squared - along * along
	if closestSquared > reachSquared then
		return nil
	end
	local entry = along - math.sqrt(math.max(0, reachSquared - closestSquared))
	return if entry >= 0 and entry <= length then entry else nil
end

return table.freeze(SegmentCircle)
