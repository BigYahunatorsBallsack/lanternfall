--!strict
-- Renders the approved Boomerang Axe sprite at the server-thrown position and spins it until the server ends it.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local SpriteKit = require(script.Parent.Parent.SpriteKit)
local VisualKit = require(script.Parent.Parent.VisualKit)

local LOOK = Config.WeaponVisuals

type Axe = {
	sprite: SpriteKit.Sprite?,
	userId: number,
	x: number,
	z: number,
	dx: number,
	dz: number,
	speed: number,
	range: number,
	at: number,
	backX: number?,
	backZ: number?,
}

local pool = VisualKit.objectPool(function(): SpriteKit.Sprite
	return SpriteKit.create("BoomerangAxe", LOOK.thrownSpriteStuds, "ThrownBoomerangAxe")
end, function(sprite: SpriteKit.Sprite): { BasePart }
	return { sprite.anchor }
end)

local axes: { [number]: Axe } = {}
local BoomerangAxe = {}

local function remove(id: number, axe: Axe)
	if axe.sprite then
		pool:release(axe.sprite)
	end
	axes[id] = nil
end

function BoomerangAxe.effect(effect: Types.WeaponEffect)
	local id = effect.id
	if not id then
		return
	end
	if effect.kind == "Fire" then
		axes[id] = {
			userId = effect.userId,
			x = effect.x or 0,
			z = effect.z or 0,
			dx = effect.dx or 0,
			dz = effect.dz or 0,
			speed = effect.speed or 0,
			range = effect.range or 0,
			at = effect.at,
		}
	elseif effect.kind == "End" then
		local axe = axes[id]
		if axe then
			remove(id, axe)
		end
	end
end

function BoomerangAxe.render(frame: VisualKit.Frame)
	for id, axe in axes do
		local age = frame.now - axe.at
		if age > LOOK.thrownMaxSeconds then
			remove(id, axe)
			continue
		end
		local x, z
		local out = math.max(0, axe.speed * age)
		if out < axe.range then
			x, z = axe.x + axe.dx * out, axe.z + axe.dz * out
		else
			x = axe.backX or axe.x + axe.dx * axe.range
			z = axe.backZ or axe.z + axe.dz * axe.range
			local owner = frame.ownerPosition(axe.userId)
			if owner then
				local tx, tz = owner.X - x, owner.Z - z
				local length = math.sqrt(tx * tx + tz * tz)
				local step = math.min(length, axe.speed * frame.dt)
				if length > 0 then
					x, z = x + tx / length * step, z + tz / length * step
				end
			end
			axe.backX, axe.backZ = x, z
		end
		local sprite = axe.sprite
		if not sprite then
			sprite = pool:acquire(frame.folder)
			axe.sprite = sprite
		end
		sprite.picture.Rotation = age * LOOK.thrownSpinDegreesPerSecond
		frame.move(sprite.anchor, CFrame.new(x, frame.floorY + LOOK.projectileHeight, z))
	end
end

function BoomerangAxe.clear()
	for id, axe in axes do
		remove(id, axe)
	end
end

return BoomerangAxe
