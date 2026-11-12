--!strict
-- Original slash rectangle animation and target-square volley geometry; server collision and client rendering share these functions.
local C = require(script.Parent.Parent.Config.NightmareEnemies).slash
local Geometry = {}
local function interpolate(values: { { number } }, age: number): (number, number)
	if age < C.times[1] then
		local reset = if values == C.positions then C.resetPosition else C.resetExtents
		return reset[1], reset[2]
	end
	for index = 1, #C.times - 1 do
		if age < C.times[index + 1] then
			local alpha = (age - C.times[index]) / (C.times[index + 1] - C.times[index])
			return values[index][1] + (values[index + 1][1] - values[index][1]) * alpha,
				values[index][2] + (values[index + 1][2] - values[index][2]) * alpha
		end
	end
	local value = values[#values]
	return value[1], value[2]
end
function Geometry.active(age: number): boolean
	return age >= C.hitFrom and age < C.hitUntil
end
function Geometry.rectangle(shot: any, age: number, pixel: number): (number, number, number, number)
	local ox, oz = interpolate(C.positions, age)
	local hx, hz = interpolate(C.extents, age)
	ox = (ox + C.hitboxOffset[1]) * pixel
	oz = (oz + C.hitboxOffset[2]) * pixel
	return shot.x + shot.dx * shot.speed * age + shot.dx * ox - shot.dz * oz,
		shot.z + shot.dz * shot.speed * age + shot.dz * ox + shot.dx * oz,
		hx * pixel,
		hz * pixel
end
function Geometry.contains(shot: any, age: number, x: number, z: number, radius: number, pixel: number): boolean
	if not Geometry.active(age) then
		return false
	end
	local cx, cz, hx, hz = Geometry.rectangle(shot, age, pixel)
	local vx, vz = x - cx, z - cz
	local along = vx * shot.dx + vz * shot.dz
	local across = -vx * shot.dz + vz * shot.dx
	local ax = math.max(0, math.abs(along) - hx)
	local az = math.max(0, math.abs(across) - hz)
	return ax * ax + az * az <= radius * radius
end
function Geometry.volley(
	tx: number,
	tz: number,
	spreadPixels: number,
	speed: number,
	count: number,
	pixel: number,
	random: () -> number
): { any }
	local result = {}
	for _ = 1, count do
		local x, z = tx + (random() - 0.5) * spreadPixels * pixel, tz + (random() - 0.5) * spreadPixels * pixel
		local dx, dz = tx - x, tz - z
		local length = math.sqrt(dx * dx + dz * dz)
		table.insert(result, {
			x = x,
			z = z,
			dx = if length > 0 then dx / length else 1,
			dz = if length > 0 then dz / length else 0,
			speed = speed,
		})
	end
	return result
end
return Geometry
