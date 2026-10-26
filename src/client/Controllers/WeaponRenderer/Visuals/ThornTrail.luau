--!strict
-- Thorn Trail look: a flat dark green disc per "Drop" effect where the server dropped a thorn patch, fading out
-- just before the patch is gone. Patches do not move, so they are placed once. Visual for WeaponRenderer (behavior
-- WeaponService/Behaviors/ThornTrail).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local VisualKit = require(script.Parent.Parent.VisualKit)

local THORN_COLOR = Color3.fromRGB(70, 150, 60) -- poisonous green
local THICKNESS = 0.15 -- studs
local HEIGHT = 0.1 -- studs above the floor
local TRANSPARENCY = 0.35
local FADE = 0.3 -- seconds of fading at the end
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is X: lay the disc flat

type Patch = {
	part: BasePart?,
	x: number,
	z: number,
	radius: number,
	at: number,
	duration: number,
}

local pool = VisualKit.pool(function()
	local part = VisualKit.part("ThornPatch", Enum.PartType.Cylinder, Vector3.new(THICKNESS, 1, 1), THORN_COLOR)
	part.Material = Enum.Material.Grass
	return part
end)

local patches: { Patch } = {}

local function remove(index: number)
	local patch = table.remove(patches, index) :: Patch
	if patch.part then
		pool:release(patch.part)
	end
end

local ThornTrail = {}

function ThornTrail.effect(effect: Types.WeaponEffect)
	if effect.kind == "Drop" then
		table.insert(patches, {
			part = nil,
			x = effect.x or 0,
			z = effect.z or 0,
			radius = effect.radius or 0,
			at = effect.at,
			duration = effect.duration or 0,
		})
	end
end

function ThornTrail.render(frame: VisualKit.Frame)
	for index = #patches, 1, -1 do
		local patch = patches[index]
		local left = patch.at + patch.duration - frame.now
		if left <= 0 then
			remove(index)
			continue
		end
		local part = patch.part
		if not part then
			local created = pool:acquire(frame.folder)
			created.Size = Vector3.new(THICKNESS, 2 * patch.radius, 2 * patch.radius)
			created.CFrame = CFrame.new(patch.x, frame.floorY + HEIGHT, patch.z) * UPRIGHT
			patch.part = created
			part = created
		end
		local fade = math.clamp(1 - left / FADE, 0, 1);
		(part :: BasePart).Transparency = TRANSPARENCY + (1 - TRANSPARENCY) * fade
	end
end

function ThornTrail.clear()
	for index = #patches, 1, -1 do
		remove(index)
	end
end

return ThornTrail
