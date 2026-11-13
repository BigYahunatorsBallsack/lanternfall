--!strict
-- Builds original Jungle hole descriptors without activating an area or rendering terrain; MapService owns descriptor lifetime.
local Shared = script.Parent.Parent
local C = require(Shared.Config.JungleHoles)
local Pixel = require(Shared.Config.Stats).range.studsPerPoint
local Shapes = require(script.Parent.StaticShapes)
local Sampling = require(script.Parent.NativeZoneSampling)
local Terrain = {}
export type Terrain = {
	layoutSource: string?,
	sourceMd5: string?,
	bodyShapes: { Shapes.Shape },
	forbiddenCircles: { Sampling.Circle },
}
local EMPTY: Terrain = table.freeze({ bodyShapes = table.freeze({}), forbiddenCircles = table.freeze({}) })
local waves: { [number]: boolean } = {}
for _, entry in C.waves do
	waves[entry.wave] = true
end
function Terrain.empty(): Terrain
	return EMPTY
end
-- nativeWave identifies the original wave resource, so future mapped-wave callers must pass that identity explicitly.
function Terrain.build(
	zoneId: number,
	nativeWave: number,
	mapSizePercent: number,
	bounds: Sampling.Rect,
	pickIndex: (number) -> number
): Terrain
	if zoneId ~= C.zoneId or not waves[nativeWave] then
		return EMPTY
	end
	local choices = if mapSizePercent == C.selection.explorerWhenMapSizeEquals
		then C.groups.holes_explorer_scene
		elseif mapSizePercent ~= 0 then C.groups.holes_old_scene
		else C.groups.holes_scene
	local index = pickIndex(#choices)
	assert(index >= 1 and index <= #choices and index % 1 == 0, "Invalid native terrain layout index")
	local path = choices[index]
	local layout = C.layouts[path]
	local physical = C.physical
	local bodies: { Shapes.Shape } = {}
	local forbidden: { Sampling.Circle } = {}
	for _, at in layout.positionsPoints do
		local x, z =
			bounds.minX + (at[1] + C.layoutOffsetPoints[1]) * Pixel,
			bounds.minZ + (at[2] + C.layoutOffsetPoints[2]) * Pixel
		table.insert(
			bodies,
			table.freeze({
				x = x,
				z = z,
				radius = physical.radiusPoints * Pixel,
				halfLength = physical.halfLengthPoints * Pixel,
				axisX = physical.axisX,
				axisZ = physical.axisZ,
			})
		)
		table.insert(forbidden, table.freeze({ x = x, z = z, radius = C.forbiddenRadiusPoints * Pixel }))
	end
	return table.freeze({
		layoutSource = path,
		sourceMd5 = layout.sourceMd5,
		bodyShapes = table.freeze(bodies),
		forbiddenCircles = table.freeze(forbidden),
	})
end
return Terrain
