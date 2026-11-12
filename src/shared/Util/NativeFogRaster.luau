--!strict
-- Renders shared additive grayscale transmission from locally decoded native light layers; color multiply and shader warp remain open graphics work.
local C = require(script.Parent.Parent.Config.NativeFog)
local Rules = require(script.Parent.NativeFogRules)
local hex = require(script.Parent.Parent.Config.NativeFogMask)
local MASK_SIZE = C.runtimeCompatibility.maskSize
local mask = buffer.create(MASK_SIZE * MASK_SIZE)
for i = 0, buffer.len(mask) - 1 do
	buffer.writeu8(mask, i, tonumber(string.sub(hex, i * 2 + 1, i * 2 + 2), 16) :: number)
end
export type Light = { x: number, y: number, kind: string, age: number, visibility: number, fade: number }
local Raster = {}
local function sample(u: number, v: number): number
	if u < 0 or v < 0 or u > 1 or v > 1 then
		return 0
	end
	local x, y = u * (MASK_SIZE - 1), v * (MASK_SIZE - 1)
	local ix, iy = math.floor(x), math.floor(y)
	local nx, ny = math.min(ix + 1, MASK_SIZE - 1), math.min(iy + 1, MASK_SIZE - 1)
	local fx, fy = x - ix, y - iy
	local a, b = buffer.readu8(mask, iy * MASK_SIZE + ix), buffer.readu8(mask, iy * MASK_SIZE + nx)
	local c, d = buffer.readu8(mask, ny * MASK_SIZE + ix), buffer.readu8(mask, ny * MASK_SIZE + nx)
	return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy
end
function Raster.draw(width: number, height: number, wave: number, lights: { Light }): buffer
	local pixels = buffer.create(width * height * 4)
	-- Alpha starts fully opaque black; every light contributes to the same transmission mask.
	for i = 0, width * height - 1 do
		buffer.writeu8(pixels, i * 4 + 3, 255)
	end
	local scale = Rules.waveScale(wave)
	for _, light in lights do
		local def = C.lights[light.kind]
		local visibility = if light.kind == "player" then Rules.visibility(light.visibility) else 1
		if not def or visibility <= 0 or light.fade <= 0 then
			continue
		end
		local pulse = Rules.pulse(def.pulse, light.age)
		local sx = width / C.rules.viewport[1] * scale * visibility * pulse
		local sy = height / C.rules.viewport[2] * scale * visibility * pulse
		local a, b, c, d = sx, 0, 0, sy
		for _, layer in def.layers do
			local rotation = layer.rotation
			local angle = 2 * math.pi * (1 - (light.age % rotation.length) / rotation.keyEnd)
			local co, si = math.cos(angle), math.sin(angle)
			local lx, ly = layer.scale[1], layer.scale[2]
			-- Preserve nested transforms, including the innermost nonuniform player layer.
			a, b, c, d =
				(a * co + b * si) * lx, (-a * si + b * co) * ly, (c * co + d * si) * lx, (-c * si + d * co) * ly
			local determinant = a * d - b * c
			local half = C.runtimeCompatibility.nativeTextureSize / 2
			local rx, ry = (math.abs(a) + math.abs(b)) * half, (math.abs(c) + math.abs(d)) * half
			local x0, x1 = math.max(0, math.floor(light.x - rx)), math.min(width - 1, math.ceil(light.x + rx))
			local y0, y1 = math.max(0, math.floor(light.y - ry)), math.min(height - 1, math.ceil(light.y + ry))
			local alpha = layer.color[4] * light.fade
			for y = y0, y1 do
				for x = x0, x1 do
					local offset = (y * width + x) * 4 + 3
					local old = buffer.readu8(pixels, offset)
					if old == 0 then
						continue
					end
					local dx, dy = x + 0.5 - light.x, y + 0.5 - light.y
					local u = ((d * dx - b * dy) / determinant / half + 1) / 2
					local v = ((-c * dx + a * dy) / determinant / half + 1) / 2
					buffer.writeu8(pixels, offset, math.max(0, math.floor(old - sample(u, v) * alpha + 0.5)))
				end
			end
		end
	end
	return pixels
end
return Raster
