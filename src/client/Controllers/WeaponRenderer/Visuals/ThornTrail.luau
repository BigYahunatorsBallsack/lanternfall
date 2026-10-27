--!strict
-- Thorn Trail look: per "Drop" effect, a dark bramble disc where the server dropped a thorn patch, with a few
-- poison-green thorns that shoot up out of the floor and sink back just before the patch is gone. Patches do not
-- move: the disc is placed once and only the thorns move while rising and sinking. Visual for WeaponRenderer
-- (behavior WeaponService/Behaviors/ThornTrail).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local VisualKit = require(script.Parent.Parent.VisualKit)

local BRAMBLE_COLOR = Color3.fromRGB(46, 74, 38)
local THORN_COLOR = Color3.fromRGB(150, 255, 110) -- poisonous green
local THICKNESS = 0.15 -- studs
local HEIGHT = 0.1 -- studs above the floor
local TRANSPARENCY = 0.25
local FADE = 0.3 -- seconds of fading at the end
local THORNS = 3 -- per patch
local THORN_SIZE = Vector3.new(0.3, 1.3, 0.6) -- studs, a wedge seen from the side is a spike
local THORN_SPREAD = 0.6 -- share of the radius thorns stand in
local RISE_SECONDS = 0.15
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is X: lay the disc flat

type PatchParts = { disc: BasePart, thorns: { BasePart } }

type Patch = {
	parts: PatchParts?,
	x: number,
	z: number,
	radius: number,
	at: number,
	duration: number,
	spots: { CFrame }, -- where the thorns stand when fully up
	settled: boolean, -- thorns fully up and not sinking yet: nothing to move
}

local pool = VisualKit.objectPool(function(): PatchParts
	local disc = VisualKit.solid(
		"ThornPatch",
		Enum.PartType.Cylinder,
		Vector3.new(THICKNESS, 1, 1),
		BRAMBLE_COLOR,
		Enum.Material.Grass
	)
	local thorns: { BasePart } = {}
	for _ = 1, THORNS do
		table.insert(thorns, VisualKit.wedge("Thorn", THORN_SIZE, THORN_COLOR))
	end
	return { disc = disc, thorns = thorns }
end, function(parts: PatchParts): { BasePart }
	local list = { parts.disc }
	for _, thorn in parts.thorns do
		table.insert(list, thorn)
	end
	return list
end)

local patches: { Patch } = {}

local function remove(index: number)
	local patch = table.remove(patches, index) :: Patch
	if patch.parts then
		pool:release(patch.parts)
	end
end

local function place(patch: Patch, frame: VisualKit.Frame): PatchParts
	local parts = pool:acquire(frame.folder)
	parts.disc.Size = Vector3.new(THICKNESS, 2 * patch.radius, 2 * patch.radius)
	parts.disc.CFrame = CFrame.new(patch.x, frame.floorY + HEIGHT, patch.z) * UPRIGHT
	parts.disc.Transparency = TRANSPARENCY
	local start = math.random() * 2 * math.pi
	for index = 1, THORNS do
		local angle = start + 2 * math.pi * index / THORNS
		local distance = patch.radius * THORN_SPREAD * (0.4 + 0.6 * math.random())
		local x, z = patch.x + math.cos(angle) * distance, patch.z + math.sin(angle) * distance
		local turn = CFrame.Angles(0, math.random() * 2 * math.pi, 0)
		patch.spots[index] = CFrame.new(x, frame.floorY + THORN_SIZE.Y / 2, z) * turn
	end
	return parts
end

local ThornTrail = {}

function ThornTrail.effect(effect: Types.WeaponEffect)
	if effect.kind == "Drop" then
		table.insert(patches, {
			parts = nil,
			x = effect.x or 0,
			z = effect.z or 0,
			radius = effect.radius or 0,
			at = effect.at,
			duration = effect.duration or 0,
			spots = {},
			settled = false,
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
		local parts = patch.parts
		if not parts then
			parts = place(patch, frame)
			patch.parts = parts
		end
		local current = parts :: PatchParts
		local rise = math.clamp((frame.now - patch.at) / RISE_SECONDS, 0, 1)
		local fade = math.clamp(1 - left / FADE, 0, 1)
		if rise >= 1 and fade <= 0 then
			if not patch.settled then
				patch.settled = true
				for thorn, part in current.thorns do
					part.CFrame = patch.spots[thorn]
				end
			end
			continue
		end
		patch.settled = false
		current.disc.Transparency = TRANSPARENCY + (1 - TRANSPARENCY) * fade
		local up = (1 - (1 - rise) ^ 2) * (1 - fade)
		local sunk = CFrame.new(0, -THORN_SIZE.Y * (1 - up), 0)
		for thorn, part in current.thorns do
			frame.move(part, sunk * patch.spots[thorn])
		end
	end
end

function ThornTrail.clear()
	for index = #patches, 1, -1 do
		remove(index)
	end
end

return ThornTrail
