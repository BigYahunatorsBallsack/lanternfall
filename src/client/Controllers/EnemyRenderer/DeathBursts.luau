--!strict
-- Short glowing puffs where enemies die (DESIGN.md section 14, hit feedback), used by EnemyRenderer when an enemy
-- drops out of the snapshots. One hidden part with a ParticleEmitter per color and size: an emitter's colors apply
-- to its particles in flight too, so different colors never share one. Particles live in world space, so one
-- emitter moved from death to death serves them all. Counts come from Config.Feedback.deathBursts (fewer on
-- touch devices).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local FOLDER_NAME = "LanternfallDeathBursts"
local LIFETIME = NumberRange.new(0.3, 0.55)
local SPEED = NumberRange.new(6, 14)
local BIG_SPEED = NumberRange.new(10, 24)
local SIZE = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
local BIG_SIZE = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
local TRANSPARENCY = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
local DRAG = 5
local RISE = Vector3.new(0, 6, 0) -- studs/s^2, the puff drifts up a little
local HEIGHT = 1.5 -- studs above the floor

local DeathBursts = {}

local folder: Folder? = nil
local emitters: { [string]: { part: BasePart, emitter: ParticleEmitter } } = {}
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

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

local function emitterFor(color: Color3, big: boolean): ParticleEmitter
	local key = `{color.R},{color.G},{color.B},{big}`
	local entry = emitters[key]
	if entry then
		return entry.emitter
	end
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
	emitter.LightEmission = 1
	emitter.Lifetime = LIFETIME
	emitter.Speed = if big then BIG_SPEED else SPEED
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = if big then BIG_SIZE else SIZE
	emitter.Transparency = TRANSPARENCY
	emitter.Drag = DRAG
	emitter.Acceleration = RISE
	emitter.Parent = part
	emitters[key] = { part = part, emitter = emitter }
	return emitter
end

-- A puff of `color` at floor point (x, y, z); `big` for elites.
function DeathBursts.burst(x: number, y: number, z: number, color: Color3, big: boolean)
	local settings = Config.Feedback.deathBursts
	if not settings.enabled then
		return
	end
	local count = if big then settings.eliteParticles elseif touch then settings.particlesTouch else settings.particles
	local emitter = emitterFor(color, big)
	local part = emitter.Parent :: BasePart
	part.CFrame = CFrame.new(x, y + HEIGHT, z)
	emitter:Emit(count)
end

return DeathBursts
