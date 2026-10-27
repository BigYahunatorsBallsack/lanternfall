--!strict
-- Pooled particle bursts (DESIGN.md section 14, VFX): sparks, rising embers, soft soul wisps and smoke puffs for
-- hits, deaths, blasts and the dash. One hidden part with a ParticleEmitter per style, color and scale: an
-- emitter's colors apply to its particles in flight too, so different colors never share one. Particles live in
-- world space, so one emitter moved from burst to burst serves them all. Used by EnemyRenderer/DeathBursts,
-- WeaponRenderer visuals and FeedbackController.

local FOLDER_NAME = "LanternfallBursts"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- ships with every Roblox client

export type Style = "spark" | "ember" | "soul" | "smoke" | "dust"

type StyleInfo = {
	lifetime: NumberRange,
	speed: { number }, -- min and max studs/s (times the square root of scale)
	size: { number }, -- start and end size in studs (times scale)
	transparency: { number }, -- start and end
	drag: number,
	rise: number, -- studs/s^2 upwards (negative falls)
	lightEmission: number,
	spread: Vector2, -- degrees
	texture: string?,
	rotate: boolean?,
}

local STYLES: { [string]: StyleInfo } = {
	-- quick bright sparks flying out in every direction
	spark = {
		lifetime = NumberRange.new(0.25, 0.5),
		speed = { 8, 16 },
		size = { 0.5, 0 },
		transparency = { 0, 1 },
		drag = 6,
		rise = -12,
		lightEmission = 1,
		spread = Vector2.new(180, 180),
	},
	-- small glowing embers that drift up
	ember = {
		lifetime = NumberRange.new(0.5, 0.9),
		speed = { 3, 9 },
		size = { 0.35, 0 },
		transparency = { 0, 1 },
		drag = 3,
		rise = 8,
		lightEmission = 1,
		spread = Vector2.new(180, 180),
	},
	-- big soft wisps that rise slowly, like a soul leaving
	soul = {
		lifetime = NumberRange.new(0.6, 1),
		speed = { 1, 3 },
		size = { 1.3, 0 },
		transparency = { 0.35, 1 },
		drag = 2,
		rise = 5,
		lightEmission = 1,
		spread = Vector2.new(180, 180),
	},
	-- dark smoke that swells and fades
	smoke = {
		lifetime = NumberRange.new(0.5, 0.8),
		speed = { 2, 5 },
		size = { 1.4, 3 },
		transparency = { 0.45, 1 },
		drag = 3,
		rise = 2,
		lightEmission = 0,
		spread = Vector2.new(180, 180),
		texture = SMOKE_TEXTURE,
		rotate = true,
	},
	-- low dust kicked up from the floor that swells and settles
	dust = {
		lifetime = NumberRange.new(0.35, 0.6),
		speed = { 3, 7 },
		size = { 1, 2.4 },
		transparency = { 0.5, 1 },
		drag = 5,
		rise = 1,
		lightEmission = 0.3,
		spread = Vector2.new(180, 180),
		texture = SMOKE_TEXTURE,
		rotate = true,
	},
}

local Bursts = {}

local folder: Folder? = nil
local emitters: { [string]: ParticleEmitter } = {}

local function getFolder(): Folder
	local current = folder
	if current then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = workspace
	folder = created
	return created
end

local function emitterFor(style: Style, color: Color3, scale: number): ParticleEmitter
	local key = `{style},{color.R},{color.G},{color.B},{scale}`
	local existing = emitters[key]
	if existing then
		return existing
	end
	local info = STYLES[style]
	local part = Instance.new("Part")
	part.Name = "Burst"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.Parent = getFolder()
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = info.lightEmission
	emitter.Lifetime = info.lifetime
	emitter.Speed = NumberRange.new(info.speed[1] * math.sqrt(scale), info.speed[2] * math.sqrt(scale))
	emitter.SpreadAngle = info.spread
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, info.size[1] * scale),
		NumberSequenceKeypoint.new(1, info.size[2] * scale),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, info.transparency[1]),
		NumberSequenceKeypoint.new(1, info.transparency[2]),
	})
	emitter.Drag = info.drag
	emitter.Acceleration = Vector3.new(0, info.rise, 0)
	if info.texture then
		emitter.Texture = info.texture
	end
	if info.rotate then
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-60, 60)
	end
	emitter.Parent = part
	emitters[key] = emitter
	return emitter
end

-- Emits `count` particles of `style` in `color` at `position`; `scale` (default 1) makes them bigger and faster.
function Bursts.emit(style: Style, color: Color3, position: Vector3, count: number, scale: number?)
	if count <= 0 then
		return
	end
	local emitter = emitterFor(style, color, scale or 1)
	local part = emitter.Parent :: BasePart
	part.CFrame = CFrame.new(position)
	emitter:Emit(count)
end

return Bursts
