--!strict
-- Original slash rectangle animation and target-square volley geometry; server collision and client rendering share these functions.
local C = require(script.Parent.Parent.Config.NightmareEnemies).slash
local F = require(script.Parent.Parent.Config.JungleWalkers).shootingRules.forwardSlash
local Geometry = {}
local function profile(shot: any): any
	return if shot and shot.variant == "Forward" then F else C
end
function Geometry.stopAt(shot: any): number
	return profile(shot).stopAt
end
local function interpolate(c: any, values: { { number } }, age: number): (number, number)
	if age < c.times[1] then
		local reset = if values == c.positions then c.resetPosition else c.resetExtents
		return reset[1], reset[2]
	end
	for index = 1, #c.times - 1 do
		if age < c.times[index + 1] then
			local alpha = (age - c.times[index]) / (c.times[index + 1] - c.times[index])
			return values[index][1] + (values[index + 1][1] - values[index][1]) * alpha,
				values[index][2] + (values[index + 1][2] - values[index][2]) * alpha
		end
	end
	local value = values[#values]
	return value[1], value[2]
end
function Geometry.active(age: number, shot: any?): boolean
	local c = profile(shot)
	return age >= c.hitFrom and age < c.hitUntil
end
function Geometry.rectangle(shot: any, age: number, pixel: number): (number, number, number, number)
	local c = profile(shot)
	local ox, oz = interpolate(c, c.positions, age)
	local hx, hz = interpolate(c, c.extents, age)
	ox = (ox + c.hitboxOffset[1]) * pixel
	oz = (oz + c.hitboxOffset[2]) * pixel
	return shot.x + shot.dx * shot.speed * age + shot.dx * ox - shot.dz * oz,
		shot.z + shot.dz * shot.speed * age + shot.dz * ox + shot.dx * oz,
		hx * pixel,
		hz * pixel
end
function Geometry.contains(shot: any, age: number, x: number, z: number, radius: number, pixel: number): boolean
	if not Geometry.active(age, shot) then
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
