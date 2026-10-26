--!strict
-- Placeholder enemy looks from 2-4 parts each (DESIGN.md section 14: violet-black bodies, glowing eyes,
-- one silhouette per type). Built in code for EnemyRenderer's pool until real models arrive in WP21.
-- Sizes follow each enemy's collision radius from Config.Enemies, so what you see is what touches you.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EnemiesConfig = require(Shared:WaitForChild("Config"):WaitForChild("Enemies"))

export type Visual = {
	model: Model,
	parts: { BasePart },
	offsets: { CFrame }, -- per part, relative to the enemy's floor point, facing -Z
	body: BasePart, -- flashes on hits
	bodyColor: Color3,
}

local BODY_COLOR = Color3.fromRGB(44, 26, 68)
local HEAD_COLOR = Color3.fromRGB(32, 18, 50)
local EYE_COLOR = Color3.fromRGB(205, 130, 255)
local SPITTER_MOUTH_COLOR = Color3.fromRGB(255, 92, 200)
local UNKNOWN_COLOR = Color3.fromRGB(255, 0, 255)

local Models = {}

local typeById: { [number]: EnemiesConfig.Enemy } = {}

local function newPart(
	model: Model,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	color: Color3,
	glow: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false -- CanQuery may only be turned off once CanCollide is off
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

type Builder = (model: Model, radius: number) -> ({ BasePart }, { CFrame })

-- Each builder returns the parts (body first) and their offsets for an enemy of `radius`.
local BUILDERS: { [string]: Builder } = {
	-- round blob with two eyes
	Shadeling = function(model, r)
		local body = newPart(model, "Body", Enum.PartType.Ball, Vector3.one * 2 * r, BODY_COLOR, false)
		local eyeSize = Vector3.one * 0.32 * r
		local left = newPart(model, "EyeLeft", Enum.PartType.Ball, eyeSize, EYE_COLOR, true)
		local right = newPart(model, "EyeRight", Enum.PartType.Ball, eyeSize, EYE_COLOR, true)
		return { body, left, right }, {
			CFrame.new(0, r, 0),
			CFrame.new(-0.35 * r, 1.25 * r, -0.82 * r),
			CFrame.new(0.35 * r, 1.25 * r, -0.82 * r),
		}
	end,
	-- wide block with a head and two eyes
	Brute = function(model, r)
		local body =
			newPart(model, "Body", Enum.PartType.Block, Vector3.new(2 * r, 1.6 * r, 1.6 * r), BODY_COLOR, false)
		local head =
			newPart(model, "Head", Enum.PartType.Block, Vector3.new(0.9 * r, 0.7 * r, 0.9 * r), HEAD_COLOR, false)
		local eyeSize = Vector3.one * 0.2 * r
		local left = newPart(model, "EyeLeft", Enum.PartType.Ball, eyeSize, EYE_COLOR, true)
		local right = newPart(model, "EyeRight", Enum.PartType.Ball, eyeSize, EYE_COLOR, true)
		return { body, head, left, right }, {
			CFrame.new(0, 0.8 * r, 0),
			CFrame.new(0, 1.95 * r, -0.3 * r),
			CFrame.new(-0.2 * r, 2 * r, -0.76 * r),
			CFrame.new(0.2 * r, 2 * r, -0.76 * r),
		}
	end,
	-- thin stalk with a round head and a glowing mouth
	Spitter = function(model, r)
		local stalk =
			newPart(model, "Body", Enum.PartType.Cylinder, Vector3.new(2 * r, 1.2 * r, 1.2 * r), BODY_COLOR, false)
		local head = newPart(model, "Head", Enum.PartType.Ball, Vector3.one * 1.5 * r, HEAD_COLOR, false)
		local mouth = newPart(model, "Mouth", Enum.PartType.Ball, Vector3.one * 0.55 * r, SPITTER_MOUTH_COLOR, true)
		return { stalk, head, mouth }, {
			CFrame.new(0, r, 0) * CFrame.Angles(0, 0, math.pi / 2), -- a cylinder's axis is X: stand it up
			CFrame.new(0, 2.4 * r, 0),
			CFrame.new(0, 2.4 * r, -0.62 * r),
		}
	end,
}

-- Magenta cube for a typeId the client does not know (should never happen; shows up clearly in tests).
local function buildUnknown(model: Model, r: number): ({ BasePart }, { CFrame })
	local body = newPart(model, "Body", Enum.PartType.Block, Vector3.one * 2 * r, UNKNOWN_COLOR, false)
	return { body }, { CFrame.new(0, r, 0) }
end

function Models.build(typeId: number): Visual
	if next(typeById) == nil then
		for _, enemy in Config.Enemies.types do
			typeById[enemy.typeId] = enemy
		end
	end
	local enemy = typeById[typeId]
	local model = Instance.new("Model")
	model.Name = if enemy then enemy.id else `Unknown{typeId}`
	local builder = enemy and BUILDERS[enemy.id]
	local parts, offsets
	if enemy and builder then
		parts, offsets = builder(model, enemy.radius)
	else
		parts, offsets = buildUnknown(model, if enemy then enemy.radius else 1.5)
	end
	return {
		model = model,
		parts = parts,
		offsets = offsets,
		body = parts[1],
		bodyColor = parts[1].Color,
	}
end

return Models
