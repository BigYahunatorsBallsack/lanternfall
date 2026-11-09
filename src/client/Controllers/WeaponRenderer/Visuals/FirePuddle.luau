--!strict
-- Pooled ground markers for server-owned fire patches; native shader/art acceptance remains pending.
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Net.Types)
local C = require(Shared.Config.Combat).nativeFirePuddles
local Look = require(Shared.Config.WeaponVisuals).firePuddle
local grow = require(Shared.Util.FirePuddleShape)
local Kit = require(script.Parent.Parent.VisualKit)
local color = Color3.new(Look.color[1], Look.color[2], Look.color[3])
type Patch = { x: number, z: number, radius: number, duration: number, at: number, part: BasePart? }
local patches: { Patch } = {}
local pool = Kit.pool(function()
	return Kit.part("FirePuddle", Enum.PartType.Cylinder, Vector3.one, color)
end)
local Visual = {}
function Visual.effect(effect: Types.WeaponEffect)
	if effect.kind == "Puddle" then
		table.insert(patches, {
			x = effect.x or 0,
			z = effect.z or 0,
			radius = effect.radius or 0,
			duration = effect.duration or 0,
			at = effect.at,
			part = nil,
		})
	end
end
function Visual.render(frame: Kit.Frame)
	for i = #patches, 1, -1 do
		local patch = patches[i]
		local age = math.max(0, frame.now - patch.at)
		if age >= patch.duration + C.despawnSeconds then
			if patch.part then
				pool:release(patch.part)
			end
			table.remove(patches, i)
			continue
		end
		local fade = math.clamp((age - patch.duration) / C.despawnSeconds, 0, 1)
		local size = patch.radius * 2 * grow(age) * (1 - (1 - Look.despawnSizeShare) * fade * fade)
		local part = patch.part or pool:acquire(frame.folder)
		patch.part = part
		part.Size = Vector3.new(Look.thickness, math.max(size, Look.thickness), math.max(size, Look.thickness))
		part.Transparency = Look.transparency + (1 - Look.transparency) * fade
		frame.move(part, CFrame.new(patch.x, frame.floorY + Look.height, patch.z) * CFrame.Angles(0, 0, math.pi / 2))
	end
end
function Visual.clear()
	for _, patch in patches do
		if patch.part then
			pool:release(patch.part)
		end
	end
	table.clear(patches)
end
return Visual
