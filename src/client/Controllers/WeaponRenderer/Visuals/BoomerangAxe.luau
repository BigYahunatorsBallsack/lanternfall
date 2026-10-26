--!strict
-- Boomerang Axe look: a spinning glowing axe per "Fire" effect that flies out at the server's speed and range, then
-- back to its owner's character as this client sees it, until the server's "End" effect says it is gone. Visual for
-- WeaponRenderer (behavior WeaponService/Behaviors/BoomerangAxe).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local VisualKit = require(script.Parent.Parent.VisualKit)

local AXE_COLOR = Color3.fromRGB(255, 150, 90) -- hot orange
local AXE_SIZE = Vector3.new(2.4, 0.3, 0.7) -- studs
local HEIGHT = 2 -- studs above the floor
local SPIN = math.rad(900) -- radians/s
local MAX_SECONDS = 5 -- drops an axe whose "End" effect never arrived

type Axe = {
	part: BasePart?,
	userId: number,
	x: number, -- start
	z: number,
	dx: number,
	dz: number,
	speed: number,
	range: number,
	at: number,
	backX: number?, -- position on the way back, moved every frame
	backZ: number?,
}

local pool = VisualKit.pool(function()
	return VisualKit.part("BoomerangAxe", Enum.PartType.Block, AXE_SIZE, AXE_COLOR)
end)

local axes: { [number]: Axe } = {} -- by projectile id

local function remove(id: number, axe: Axe)
	if axe.part then
		pool:release(axe.part)
	end
	axes[id] = nil
end

local BoomerangAxe = {}

function BoomerangAxe.effect(effect: Types.WeaponEffect)
	local id = effect.id
	if not id then
		return
	end
	if effect.kind == "Fire" then
		axes[id] = {
			part = nil,
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
		if age > MAX_SECONDS then
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
		local part = axe.part
		if not part then
			part = pool:acquire(frame.folder)
			axe.part = part
		end
		frame.move(part :: BasePart, CFrame.new(x, frame.floorY + HEIGHT, z) * CFrame.Angles(0, age * SPIN, 0))
	end
end

function BoomerangAxe.clear()
	for id, axe in axes do
		remove(id, axe)
	end
end

return BoomerangAxe
