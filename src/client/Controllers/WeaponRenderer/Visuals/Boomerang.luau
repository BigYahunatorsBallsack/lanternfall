--!strict
-- Cosmetic native Boomerang snapshots and original looping rotation; WeaponRenderer owns lifecycle, server owns hits.
local Shared = game:GetService("ReplicatedStorage").Shared
local WorldSprite = require(Shared.Util.WorldSprite)
local C = require(Shared.Config.WeaponVisuals).boomerang
local Images: any = require(Shared.Config.SpriteImages)
local Kit = require(script.Parent.Parent.VisualKit)
local Visual = {}
local shots: { [number]: any } = {}
local pool = Kit.objectPool(function()
	return WorldSprite.create({ name = "Boomerang", image = "", studs = C.studs, ground = 0.5 })
end, function(sprite)
	return { sprite.anchor }
end)
local function remove(id, shot)
	if shot.sprite then
		pool:release(shot.sprite)
	end
	shots[id] = nil
end
function Visual.effect(effect)
	if not effect.id then
		return
	end
	local shot = shots[effect.id]
	if effect.kind == "End" then
		if shot then
			remove(effect.id, shot)
		end
		return
	end
	if effect.kind ~= "Drop" then
		return
	end
	shot = shot or { start = effect.at }
	shot.x, shot.z, shot.untilTime = effect.x, effect.z, effect.at + (effect.duration or 0)
	shots[effect.id] = shot
end
function Visual.render(frame)
	local art = Images.boomerang and Images.boomerang.BoomerangThrown
	for id, shot in shots do
		if frame.now >= shot.untilTime then
			remove(id, shot)
		elseif art then
			local sprite = shot.sprite or pool:acquire(frame.folder)
			shot.sprite = sprite
			WorldSprite.setImage(
				sprite,
				{ name = "Boomerang", image = art.image, pixels = art.pixels, studs = C.studs, ground = 0.5 }
			)
			WorldSprite.pose(sprite, 1, 1, ((frame.now - shot.start) * C.rotationDegreesPerSecond) % 360, 0)
			frame.move(sprite.anchor, CFrame.new(shot.x, frame.floorY + C.height, shot.z))
		end
	end
end
function Visual.clear()
	for id, shot in shots do
		remove(id, shot)
	end
end
return Visual
