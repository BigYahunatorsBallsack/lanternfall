--!strict
-- Shockwave look: a flat glowing disc that grows to the blast radius and fades out, centered on the owner's
-- character as this client sees it when the "Pulse" effect arrives. Visual for WeaponRenderer (behavior
-- WeaponService/Behaviors/Shockwave).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local VisualKit = require(script.Parent.Parent.VisualKit)

local WAVE_COLOR = Color3.fromRGB(255, 205, 110) -- lantern yellow
local DURATION = 0.35 -- seconds from blast to gone
local START_SIZE = 0.3 -- share of the radius the disc starts at
local START_TRANSPARENCY = 0.45
local THICKNESS = 0.2 -- studs
local HEIGHT = 0.15 -- studs above the floor
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is X: lay the disc flat

type Wave = {
	part: BasePart?,
	userId: number,
	x: number,
	z: number,
	radius: number,
	at: number, -- server time of the blast
	placed: boolean, -- centered on the owner once, then it stays there
}

local pool = VisualKit.pool(function()
	return VisualKit.part("Shockwave", Enum.PartType.Cylinder, Vector3.new(THICKNESS, 1, 1), WAVE_COLOR)
end)

local waves: { Wave } = {}

local function remove(index: number)
	local wave = table.remove(waves, index) :: Wave
	if wave.part then
		pool:release(wave.part)
	end
end

local Shockwave = {}

function Shockwave.effect(effect: Types.WeaponEffect)
	if effect.kind == "Pulse" then
		table.insert(waves, {
			part = nil,
			userId = effect.userId,
			x = effect.x or 0,
			z = effect.z or 0,
			radius = effect.radius or 0,
			at = effect.at,
			placed = false,
		})
	end
end

function Shockwave.render(frame: VisualKit.Frame)
	for index = #waves, 1, -1 do
		local wave = waves[index]
		local t = math.max(0, (frame.now - wave.at) / DURATION)
		if t >= 1 then
			remove(index)
			continue
		end
		if not wave.placed then
			wave.placed = true
			local position = frame.ownerPosition(wave.userId)
			if position then
				wave.x, wave.z = position.X, position.Z
			end
		end
		local part = wave.part
		if not part then
			part = pool:acquire(frame.folder)
			wave.part = part
		end
		local grow = 1 - (1 - t) ^ 2 -- fast first, then slowing down
		local diameter = 2 * wave.radius * (START_SIZE + (1 - START_SIZE) * grow)
		local disc = part :: BasePart
		disc.Size = Vector3.new(THICKNESS, diameter, diameter)
		disc.Transparency = START_TRANSPARENCY + (1 - START_TRANSPARENCY) * t
		frame.move(disc, CFrame.new(wave.x, frame.floorY + HEIGHT, wave.z) * UPRIGHT)
	end
end

function Shockwave.clear()
	for index = #waves, 1, -1 do
		remove(index)
	end
end

return Shockwave
