--!strict
-- Red blobs that splash from a hit enemy (DESIGN.md section 14, hit feedback), used by EnemyRenderer whenever an enemy's
-- HP in the snapshots drops. As in the owner's Brotato screenshots (08.11.2026) the blobs fly from the enemy back
-- towards the player nearest to it (the client does not know who hit it) and fade within half a second. One pooled
-- ParticleEmitter serves every hit; counts, sizes and the per-frame limit come from Config.Feedback.hitBursts (fewer at
-- Low graphics, GraphicsController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local GraphicsController = require(script.Parent.Parent.GraphicsController)

local FOLDER_NAME = "LanternfallHitBursts"

local HitBursts = {}

local emitter: ParticleEmitter? = nil
local left = 0 -- enemies that may still splash this frame
local players: { Vector3 } = {} -- where the players stand this frame, filled on the first hit of a frame
local playersFresh = false

local function getEmitter(): ParticleEmitter
	local current = emitter
	if current then
		return current
	end
	local settings = Config.Feedback.hitBursts
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
	local part = Instance.new("Part")
	part.Name = "HitBurst"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.Parent = folder
	local created = Instance.new("ParticleEmitter")
	created.Enabled = false
	created.Rate = 0
	created.Texture = Config.Sprites.images.glow -- a soft round dot
	created.Color = ColorSequence.new(Color3.fromRGB(table.unpack(settings.color)))
	created.LightEmission = 0
	created.LightInfluence = 0 -- keeps its red in the dark arena
	created.Lifetime = NumberRange.new(settings.lifetime[1], settings.lifetime[2])
	created.Speed = NumberRange.new(settings.speed[1], settings.speed[2])
	created.SpreadAngle = Vector2.new(settings.spreadDegrees, settings.spreadDegrees)
	created.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, settings.size),
		NumberSequenceKeypoint.new(0.6, settings.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	created.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	created.Drag = settings.drag
	created.EmissionDirection = Enum.NormalId.Front -- along the part's look vector, see hit()
	created.ZOffset = settings.zOffset
	created.Parent = part
	emitter = created
	return created
end

local function collectPlayers()
	table.clear(players)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			table.insert(players, root.Position)
		end
	end
	playersFresh = true
end

-- Call once per frame before the hits of that frame.
function HitBursts.beginFrame()
	local settings = Config.Feedback.hitBursts
	left = if not settings.enabled
		then 0
		elseif GraphicsController.isLow() then settings.maxPerFrameTouch
		else settings.maxPerFrame
	playersFresh = false
end

-- Blobs from an enemy of `radius` hit at floor point (x, y, z). Returns false when this frame's limit was used up.
function HitBursts.hit(x: number, y: number, z: number, radius: number): boolean
	if left <= 0 then
		return false
	end
	left -= 1
	if not playersFresh then
		collectPlayers()
	end
	-- towards the nearest player; with nobody around, up the screen
	local dx, dz, best = 0, -1, math.huge
	for _, position in players do
		local px, pz = position.X - x, position.Z - z
		local distance = px * px + pz * pz
		if distance < best and distance > 1e-6 then
			best = distance
			local length = math.sqrt(distance)
			dx, dz = px / length, pz / length
		end
	end
	local settings = Config.Feedback.hitBursts
	local count = if GraphicsController.isLow() then settings.particlesTouch else settings.particles
	local current = getEmitter()
	local part = current.Parent :: BasePart
	local origin = Vector3.new(x + dx * radius * 0.5, y + radius * settings.height, z + dz * radius * 0.5)
	part.CFrame = CFrame.lookAt(origin, origin + Vector3.new(dx, 0, dz))
	current:Emit(count)
	return true
end

return HitBursts
