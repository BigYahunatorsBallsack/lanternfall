--!strict
-- Draws weapon shots and muzzle flashes as flat 2D shapes made of rounded GUI frames inside a world sprite (own
-- drawings in Brotato's style, no images to upload). Every shape points right, along the flight; WorldSprite.pose
-- turns it. Looks come from Config/ShotLooks. Used by WeaponRenderer/B7ProjectileVisual.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ShotLooks = require(Shared:WaitForChild("Config"):WaitForChild("ShotLooks"))
local WorldSprite = require(Shared:WaitForChild("Util"):WaitForChild("WorldSprite"))

export type Shot = {
	sprite: WorldSprite.Sprite,
	-- frames whose transparency follows ShotShapes.setFade, with their own base transparency
	fading: { { frame: Frame, base: number } },
	flicker: { Frame }, -- exhaust flames that flicker
}

local ShotShapes = {}

local function rgb(values: { number }?, fallback: Color3): Color3
	if not values then
		return fallback
	end
	return Color3.fromRGB(values[1], values[2], values[3])
end

local RIM_COLOR = rgb(ShotLooks.rimColor, Color3.new(0, 0, 0))

-- One rounded frame centered on (x, y), sizes as shares of the square picture; `round` 0.5 makes a capsule or circle.
local function piece(
	shot: Shot,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	round: number,
	rotation: number?,
	transparency: number?,
	order: number?
): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Piece"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.Rotation = rotation or 0
	frame.ZIndex = order or 3
	if round > 0 then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = frame
	end
	frame.Parent = shot.sprite.picture
	table.insert(shot.fading, { frame = frame, base = transparency or 0 })
	return frame
end

local function rim(frame: Frame)
	local stroke = Instance.new("UIStroke")
	stroke.Color = RIM_COLOR
	stroke.Thickness = ShotLooks.rimPixels
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = frame
end

-- A straight piece from (x1, y1) to (x2, y2), `thickness` thick (lightning segments).
local function segment(
	shot: Shot,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	thickness: number,
	color: Color3,
	transparency: number?,
	order: number?
): Frame
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy) + thickness
	return piece(
		shot,
		(x1 + x2) / 2,
		(y1 + y2) / 2,
		length,
		thickness,
		color,
		0.5,
		math.deg(math.atan2(dy, dx)),
		transparency,
		order
	)
end

type Builder = (
	shot: Shot,
	look: ShotLooks.Look,
	l: number,
	w: number,
	main: Color3,
	core: Color3,
	accent: Color3
) -> ()

local BUILDERS: { [string]: Builder } = {}

function BUILDERS.bullet(shot, look, l, w, main, core, accent)
	local body = piece(shot, 0.5, 0.5, l, w, main, 0.5)
	if look.rim then
		rim(body)
	end
	piece(shot, 0.5 + l * 0.06, 0.5, l * 0.78, w * 0.56, core, 0.5, 0, 0, 4)
	piece(shot, 0.5 + l * 0.1, 0.5 - w * 0.1, l * 0.42, w * 0.2, accent, 0.5, 0, 0, 5)
end

function BUILDERS.pellet(shot, look, l, w, main, core)
	local body = piece(shot, 0.5, 0.5, l, w, main, 0.5)
	if look.rim then
		rim(body)
	end
	piece(shot, 0.5 + l * 0.08, 0.5 - w * 0.06, l * 0.55, w * 0.5, core, 0.5, 0, 0, 4)
end

function BUILDERS.laser(shot, _look, l, w, main, core)
	piece(shot, 0.5, 0.5, l, w, main, 0.5, 0, 0.3)
	piece(shot, 0.5, 0.5, l * 0.9, w * 0.62, main, 0.5, 0, 0, 4)
	piece(shot, 0.5 + l * 0.02, 0.5, l * 0.82, w * 0.3, core, 0.5, 0, 0, 5)
end

function BUILDERS.lightning(shot, _look, l, w, main, core)
	local tail, nose = 0.5 - l / 2, 0.5 + l / 2
	local points = {
		{ tail, 0.5 },
		{ tail + l * 0.3, 0.5 - w * 0.38 },
		{ tail + l * 0.62, 0.5 + w * 0.38 },
		{ nose, 0.5 },
	}
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		segment(shot, a[1], a[2], b[1], b[2], w * 0.34, main, 0.35)
		segment(shot, a[1], a[2], b[1], b[2], w * 0.14, core, 0, 4)
	end
end

function BUILDERS.orb(shot, _look, l, w, main, core)
	local size = math.min(l, w)
	piece(shot, 0.5, 0.5, size, size, main, 0.5, 0, 0.4)
	piece(shot, 0.5, 0.5, size * 0.7, size * 0.7, main, 0.5, 0, 0, 4)
	piece(shot, 0.5 + size * 0.05, 0.5 - size * 0.05, size * 0.38, size * 0.38, core, 0.5, 0, 0, 5)
end

function BUILDERS.fireball(shot, _look, l, w, main, core)
	local head = w
	local headX = 0.5 + l / 2 - head / 2
	local tail = piece(shot, 0.5 - head * 0.15, 0.5, l - head * 0.3, w * 0.7, main, 0.5, 0, 0.15)
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	gradient.Parent = tail
	piece(shot, headX, 0.5, head, head, main, 0.5, 0, 0, 4)
	piece(shot, headX + head * 0.08, 0.5, head * 0.55, head * 0.55, core, 0.5, 0, 0, 5)
end

function BUILDERS.flame(shot, _look, l, w, main, core)
	local size = math.min(l, w)
	piece(shot, 0.5 - size * 0.18, 0.5 + size * 0.12, size * 0.6, size * 0.6, main, 0.5, 0, 0.3)
	piece(shot, 0.5, 0.5, size, size * 0.85, main, 0.5, 0, 0.1, 4)
	piece(shot, 0.5 + size * 0.08, 0.5 - size * 0.04, size * 0.5, size * 0.45, core, 0.5, 0, 0, 5)
end

function BUILDERS.icicle(shot, look, l, w, main, core)
	local tip = w * 0.72
	local body = piece(shot, 0.5 - l * 0.08, 0.5, l * 0.82, w, main, 0.5)
	local point = piece(shot, 0.5 + l / 2 - tip * 0.72, 0.5, tip, tip, main, 0.15, 45, 0, 3)
	if look.rim then
		rim(body)
		rim(point)
	end
	piece(shot, 0.5 - l * 0.04, 0.5 - w * 0.12, l * 0.6, w * 0.24, core, 0.5, 0, 0, 5)
end

-- An arrow-like point at the nose: two slanted bars meeting at the tip, `size` long.
local function point(shot: Shot, nose: number, size: number, thickness: number, color: Color3, hasRim: boolean)
	local tipX = nose - thickness / 2
	for _, side in { -1, 1 } do
		local bar = segment(shot, tipX, 0.5, tipX - size * 0.8, 0.5 + side * size * 0.5, thickness, color, 0, 4)
		if hasRim then
			rim(bar)
		end
	end
end

function BUILDERS.arrow(shot, look, l, w, main, core, accent)
	local nose = 0.5 + l / 2
	local tail = 0.5 - l / 2 + w * 0.3
	local top = piece(shot, tail, 0.5 - w * 0.2, w * 0.55, w * 0.18, accent, 0.5, 35, 0, 2)
	local bottom = piece(shot, tail, 0.5 + w * 0.2, w * 0.55, w * 0.18, accent, 0.5, -35, 0, 2)
	local shaft = piece(shot, 0.5 - w * 0.05, 0.5, l - w * 0.1, w * 0.2, main, 0.5)
	if look.rim then
		for _, frame in { shaft, top, bottom } do
			rim(frame)
		end
	end
	point(shot, nose, w * 0.75, w * 0.24, core, look.rim == true)
end

function BUILDERS.harpoon(shot, look, l, w, main, core)
	local nose = 0.5 + l / 2
	local shaft = piece(shot, 0.5 - w * 0.05, 0.5, l - w * 0.1, w * 0.24, main, 0.5)
	if look.rim then
		rim(shaft)
	end
	point(shot, nose, w * 0.8, w * 0.26, core, look.rim == true)
	point(shot, nose - w * 0.75, w * 0.6, w * 0.2, core, look.rim == true)
end

function BUILDERS.dart(shot, look, l, w, main, _core, accent)
	local needle = piece(shot, 0.5 + l * 0.15, 0.5, l * 0.7, w * 0.3, main, 0.5)
	local fluff = piece(shot, 0.5 - l / 2 + w / 2, 0.5, w, w, accent, 0.5, 0, 0, 4)
	if look.rim then
		rim(needle)
		rim(fluff)
	end
end

function BUILDERS.thorn(shot, look, l, w, main, core)
	local body = piece(shot, 0.5, 0.5, l, w, main, 0.5)
	if look.rim then
		rim(body)
	end
	piece(shot, 0.5 + l * 0.3, 0.5, l * 0.36, w * 0.45, core, 0.5, 0, 0, 4)
end

function BUILDERS.rock(shot, look, l, w, main, core)
	local body = piece(shot, 0.5, 0.5, l, w * 0.86, main, 0.42)
	if look.rim then
		rim(body)
	end
	piece(shot, 0.5 - l * 0.14, 0.5 - w * 0.14, l * 0.34, w * 0.28, core, 0.5, 0, 0, 4)
end

function BUILDERS.potato(shot, look, l, w, main, core, accent)
	local body = piece(shot, 0.5, 0.5, l, w, main, 0.5)
	if look.rim then
		rim(body)
	end
	piece(shot, 0.5 - l * 0.12, 0.5 - w * 0.16, l * 0.4, w * 0.3, core, 0.5, 0, 0, 4)
	piece(shot, 0.5 + l * 0.2, 0.5 + w * 0.12, w * 0.14, w * 0.14, accent, 0.5, 0, 0, 5)
	piece(shot, 0.5 - l * 0.16, 0.5 + w * 0.2, w * 0.11, w * 0.11, accent, 0.5, 0, 0, 5)
end

function BUILDERS.shuriken(shot, look, l, w, main, core)
	local size = math.min(l, w)
	-- four long blades and four short ones in between; the hub hides where the outlines cross
	for _, spec in { { 0, 0.92, 0.26 }, { 90, 0.92, 0.26 }, { 45, 0.56, 0.2 }, { 135, 0.56, 0.2 } } do
		local blade = piece(shot, 0.5, 0.5, size * spec[2], size * spec[3], main, 0.12, spec[1])
		if look.rim then
			rim(blade)
		end
	end
	piece(shot, 0.5, 0.5, size * 0.34, size * 0.34, core, 0.5, 0, 0, 5)
end

function BUILDERS.rocket(shot, look, l, w, main, core, accent)
	local tail = 0.5 - l / 2
	local bodyLength = l * 0.72
	local bodyX = 0.5 + l / 2 - bodyLength / 2
	local flame = piece(shot, tail + l * 0.16, 0.5, l * 0.34, w * 0.5, accent, 0.5, 0, 0.1, 2)
	table.insert(shot.flicker, flame)
	local top = piece(shot, bodyX - bodyLength * 0.36, 0.5 - w * 0.32, w * 0.5, w * 0.24, core, 0.3, -35, 0, 2)
	local bottom = piece(shot, bodyX - bodyLength * 0.36, 0.5 + w * 0.32, w * 0.5, w * 0.24, core, 0.3, 35, 0, 2)
	local body = piece(shot, bodyX, 0.5, bodyLength, w * 0.62, main, 0.5)
	local nose = piece(shot, 0.5 + l / 2 - w * 0.24, 0.5, w * 0.48, w * 0.48, core, 0.5, 0, 0, 4)
	if look.rim then
		for _, frame in { top, bottom, body, nose } do
			rim(frame)
		end
	end
	piece(shot, bodyX - bodyLength * 0.05, 0.5, w * 0.16, w * 0.62, core, 0, 0, 0, 4)
end

function BUILDERS.grenade(shot, look, l, w, main, core, accent)
	local size = math.min(l, w)
	local body = piece(shot, 0.5, 0.5, size, size, main, 0.5)
	local cap = piece(shot, 0.5 + size * 0.45, 0.5, size * 0.3, size * 0.36, accent, 0.2, 0, 0, 2)
	if look.rim then
		rim(body)
		rim(cap)
	end
	piece(shot, 0.5 - size * 0.14, 0.5 - size * 0.14, size * 0.34, size * 0.3, core, 0.5, 0, 0, 4)
end

-- The look for a weapon behavior; ShotLooks.default for one without its own entry.
function ShotShapes.lookOf(behavior: string?): ShotLooks.Look
	return behavior and ShotLooks.byBehavior[behavior] or ShotLooks.default
end

function ShotShapes.color(values: { number }?, fallback: Color3): Color3
	return rgb(values, fallback)
end

-- A new pooled shot sprite (parent its anchor to show it) drawn in `look`.
function ShotShapes.build(name: string, look: ShotLooks.Look): Shot
	local studs = math.max(look.length, look.width)
	local sprite = WorldSprite.create({ name = name, image = "", studs = studs })
	sprite.picture.ImageTransparency = 1
	local shot: Shot = { sprite = sprite, fading = {}, flicker = {} }
	local main = rgb(look.color, Color3.new(1, 1, 1))
	local core = rgb(look.core, main)
	local accent = rgb(look.accent, core)
	local builder = BUILDERS[look.shape] or BUILDERS.bullet
	builder(shot, look, look.length / studs, look.width / studs, main, core, accent)
	return shot
end

-- Fades the whole shot (0 = as drawn, 1 = gone); each piece keeps its own see-through share on top.
function ShotShapes.setFade(shot: Shot, fade: number)
	for _, entry in shot.fading do
		entry.frame.BackgroundTransparency = entry.base + (1 - entry.base) * fade
	end
end

-- Exhaust flames flicker between `low` and full size.
function ShotShapes.flicker(shot: Shot, amount: number)
	for _, frame in shot.flicker do
		frame.BackgroundTransparency = 0.1 + 0.4 * amount
	end
end

-- The short star at the barrel when a gun fires.
function ShotShapes.muzzleFlash(): Shot
	local look = ShotLooks.muzzleFlash
	local sprite = WorldSprite.create({ name = "MuzzleFlash", image = "", studs = look.studs })
	sprite.picture.ImageTransparency = 1
	local shot: Shot = { sprite = sprite, fading = {}, flicker = {} }
	local main = rgb(look.color, Color3.new(1, 1, 0.6))
	local core = rgb(look.core, Color3.new(1, 1, 1))
	piece(shot, 0.5, 0.5, 0.9, 0.34, main, 0.5, 0, 0.1)
	piece(shot, 0.5, 0.5, 0.62, 0.62, main, 0.12, 45, 0.15)
	piece(shot, 0.5, 0.5, 0.36, 0.36, core, 0.5, 0, 0, 4)
	return shot
end

return ShotShapes
