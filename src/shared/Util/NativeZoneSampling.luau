--!strict
-- Native ZoneService point/area sampling over forbidden circles; NativeSummons uses area placement, terrain owns grid lifetime.
local Shared = script.Parent.Parent
local C = require(Shared.Config.JungleHoles).sampling
local Pixel = require(Shared.Config.Stats).range.studsPerPoint
local Zone = {}
Zone.__index = Zone
export type Circle = { x: number, z: number, radius: number }
export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }
type Cell = { x: number, z: number }
local EMPTY: { Circle } = table.freeze({})
export type Sampler = typeof(setmetatable({} :: { bounds: Rect, circles: { Circle }, cells: { Cell }? }, Zone))
function Zone.inForbidden(x: number, z: number, circles: { Circle }?): boolean
	for _, circle in circles or EMPTY do
		if (x - circle.x) ^ 2 + (z - circle.z) ^ 2 <= circle.radius ^ 2 then
			return true
		end
	end
	return false
end
function Zone.pushOut(x: number, z: number, circles: { Circle }?): (number, number)
	for _, circle in circles or EMPTY do
		local dx, dz = x - circle.x, z - circle.z
		local squared = dx * dx + dz * dz
		if squared <= circle.radius ^ 2 then
			if squared < C.pushOutEpsilonSquaredPoints * Pixel ^ 2 then
				dx, dz, squared = 1, 0, 1
			end
			local reach = circle.radius + C.pushOutPaddingPoints * Pixel
			x, z = circle.x + dx / math.sqrt(squared) * reach, circle.z + dz / math.sqrt(squared) * reach
		end
	end
	return x, z
end
-- TargetRandPos checks eight candidates, draws after each failure, then pushes out the final ninth candidate.
function Zone.goal(draw: () -> (number, number), circles: { Circle }?): (number, number)
	local x, z = draw()
	for _ = 1, C.goalTries do
		if not Zone.inForbidden(x, z, circles) then
			return x, z
		end
		x, z = draw()
	end
	return Zone.pushOut(x, z, circles)
end
local function clamp(value: number, low: number, high: number): number
	-- Godot CLAMP checks the lower limit first, including reversed limits.
	return if value < low then low elseif value > high then high else value
end
function Zone.inArea(
	random: () -> number,
	bounds: Rect,
	x: number,
	z: number,
	area: number,
	circles: { Circle }?
): (number, number)
	local smallerPoints = math.min(bounds.maxX - bounds.minX, bounds.maxZ - bounds.minZ) / Pixel
	local edge = if C.edgePoints > smallerPoints * C.maxEdgeShare
		then math.floor(smallerPoints * C.maxEdgeShare) * Pixel
		else C.edgePoints * Pixel
	local half = area / 2
	local cx = clamp(x, bounds.minX + edge + half, bounds.maxX - edge - half)
	local cz = clamp(z, bounds.minZ + edge + half, bounds.maxZ - edge - half)
	for _ = 1, C.areaTries do
		local sx, sz = cx + (random() - 0.5) * area, cz + (random() - 0.5) * area
		if not Zone.inForbidden(sx, sz, circles) then
			return sx, sz
		end
	end
	return Zone.pushOut(cx, cz, circles)
end
function Zone.new(bounds: Rect, circles: { Circle }?): Sampler
	return setmetatable({ bounds = table.clone(bounds), circles = circles or EMPTY, cells = nil }, Zone)
end
function Zone.setCircles(self: Sampler, circles: { Circle })
	self.circles = circles
	self.cells = nil
end
function Zone.sample(self: Sampler, random: () -> number, pickIndex: (number) -> number): (number, number)
	local bounds = self.bounds
	local size = C.cellSizePoints * Pixel
	local cells = self.cells
	if not cells then
		local candidates: { Cell } = {}
		-- Recover the original integer-pixel rectangle before counting cells; translated stud bounds may gain tiny errors.
		for col = 0, math.ceil(math.round((bounds.maxX - bounds.minX) / Pixel) / C.cellSizePoints) - 1 do
			for row = 0, math.ceil(math.round((bounds.maxZ - bounds.minZ) / Pixel) / C.cellSizePoints) - 1 do
				local x, z = bounds.minX + col * size, bounds.minZ + row * size
				if not Zone.inForbidden(x + size / 2, z + size / 2, self.circles) then
					table.insert(candidates, { x = x, z = z })
				end
			end
		end
		cells = candidates
		self.cells = candidates
	end
	if #cells == 0 then
		return (bounds.minX + bounds.maxX) / 2, (bounds.minZ + bounds.maxZ) / 2
	end
	local cell = cells[pickIndex(#cells)]
	local x, z = cell.x + random() * size, cell.z + random() * size
	if not Zone.inForbidden(x, z, self.circles) then
		return x, z
	end
	for _ = 1, C.cellRetries do
		x, z = cell.x + random() * size, cell.z + random() * size
		if not Zone.inForbidden(x, z, self.circles) then
			return x, z
		end
	end
	return cell.x + size / 2, cell.z + size / 2
end
return Zone
