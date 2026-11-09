--!strict
-- Sticky Grenade flight and pooled fusing markers; server Drop events follow attached targets until detonation.
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Net.Types)
local Look = require(Shared.Config.WeaponVisuals).stickyGrenade
local COLOR = Color3.new(Look.color[1], Look.color[2], Look.color[3])
local FLASH = Color3.new(Look.flash[1], Look.flash[2], Look.flash[3])
local Kit = require(script.Parent.Parent.VisualKit)
local flight = require(script.Parent.Parent.B7ProjectileVisual)(COLOR)
type Fuse = { x: number, z: number, untilTime: number, startTime: number, part: BasePart? }
local fuses: { [number]: Fuse } = {}
local WorldSprite = require(Shared.Util.WorldSprite)
local artwork: { [string]: { image: string, pixels: number } } = require(Shared.Config.SpriteImages).world
local pool = Kit.pool(function()
	local part =
		Kit.part("StickyGrenadeFuse", Enum.PartType.Ball, Vector3.new(Look.studs, Look.studs, Look.studs), COLOR)
	local image = artwork.StickyGrenadeGround
	if image then
		part.Transparency = 1
		WorldSprite.attach(
			part,
			part,
			{ name = "StickyGrenade", image = image.image, pixels = image.pixels, studs = Look.studs }
		)
	end
	return part
end)
local Visual = {}
function Visual.effect(effect: Types.WeaponEffect)
	flight.effect(effect)
	if effect.kind == "Drop" and effect.id then
		local fuse = fuses[effect.id] or { x = 0, z = 0, untilTime = 0, startTime = effect.at, part = nil }
		fuse.x, fuse.z = effect.x or 0, effect.z or 0
		fuse.untilTime = effect.at + (effect.duration or 0)
		fuses[effect.id] = fuse
	end
end
function Visual.render(frame: Kit.Frame)
	flight.render(frame)
	for id, fuse in fuses do
		if frame.now >= fuse.untilTime then
			if fuse.part then
				pool:release(fuse.part)
			end
			fuses[id] = nil
		else
			local part = fuse.part or pool:acquire(frame.folder)
			fuse.part = part
			local flashes = 0
			for _, time in Look.flashTimes do
				if frame.now - fuse.startTime >= time then
					flashes += 1
				end
			end
			part.Color = if flashes % 2 == 0 then COLOR else FLASH
			local board = part:FindFirstChild("StickyGrenade")
			local picture = board and board:FindFirstChild("Picture")
			if picture and picture:IsA("ImageLabel") then
				picture.ImageColor3 = part.Color
			end
			frame.move(part, CFrame.new(fuse.x, frame.floorY + Look.height, fuse.z))
		end
	end
end
function Visual.clear()
	flight.clear()
	for _, fuse in fuses do
		if fuse.part then
			pool:release(fuse.part)
		end
	end
	table.clear(fuses)
end
return Visual
