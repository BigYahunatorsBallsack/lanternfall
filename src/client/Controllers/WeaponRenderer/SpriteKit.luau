--!strict
-- Builds a pooled world-space weapon sprite from the approved shop artwork for HeldModels and thrown visuals.

local Images = require(script.Parent.Parent.Parent.UI.WeaponImages)
local VisualKit = require(script.Parent.VisualKit)
local Look = require(game:GetService("ReplicatedStorage").Shared.Config.WeaponVisuals)
local Sprites = require(game:GetService("ReplicatedStorage").Shared.Config.Sprites)
local WorldSprite = require(game:GetService("ReplicatedStorage").Shared.Util.WorldSprite)

export type Sprite = { anchor: BasePart, picture: ImageLabel }

local SpriteKit = {}

function SpriteKit.rotationToward(id: string, dx: number, dz: number): number
	local camera = workspace.CurrentCamera
	local cameraFrame = camera and camera.CFrame
	if not cameraFrame then
		return 0
	end
	local facing = Vector3.new(dx, 0, dz)
	local right, up = cameraFrame.RightVector, cameraFrame.UpVector
	local screenAngle = math.deg(math.atan2(-facing:Dot(up), facing:Dot(right)))
	local baseline = Look.forwardDegrees[id] or Look.defaultForwardDegrees
	return screenAngle - baseline
end

function SpriteKit.create(id: string, size: number, name: string): Sprite
	local anchor = VisualKit.part(name, Enum.PartType.Block, Vector3.new(0.12, 0.12, 0.12), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WeaponArtwork"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromScale(size, size)
	billboard.StudsOffset = Vector3.new(0, 0, Sprites.depthBias) -- same layer as characters and enemies
	billboard.Parent = anchor
	local picture = Instance.new("ImageLabel")
	picture.Name = "Sprite"
	picture.BackgroundTransparency = 1
	picture.Size = UDim2.fromScale(1, 1)
	picture.Image = Images[id] or ""
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Parent = billboard
	WorldSprite.outlinePicture(picture, Sprites.outline.studs / size) -- owner 08.11.2026: dark outline on everything
	return { anchor = anchor, picture = picture }
end

return SpriteKit
