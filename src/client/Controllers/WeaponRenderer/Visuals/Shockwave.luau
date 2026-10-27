--!strict
-- Shockwave look: a white flash at the owner, a ring of glowing art-deco segments racing out to the blast radius
-- over a soft golden disc, and a ring of dust kicked up from the floor, all centered on the owner's character as
-- this client sees it when the "Pulse" effect arrives. Visual for WeaponRenderer (behavior
-- WeaponService/Behaviors/Shockwave).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Bursts = require(script.Parent.Parent.Parent.Parent.Vfx.Bursts)
local VisualKit = require(script.Parent.Parent.VisualKit)

local WAVE_COLOR = Color3.fromRGB(255, 205, 110) -- lantern yellow
local RING_COLOR = Color3.fromRGB(255, 238, 190)
local FLASH_COLOR = Color3.fromRGB(255, 250, 230)
local DUST_COLOR = Color3.fromRGB(150, 132, 110)
local DURATION = 0.35 -- seconds from blast to gone
local START_SIZE = 0.3 -- share of the radius the disc and ring start at
local DISC_TRANSPARENCY = 0.65 -- at the start
local DISC_THICKNESS = 0.2 -- studs
local DISC_HEIGHT = 0.15 -- studs above the floor
local SEGMENTS = 12
local SEGMENT_FILL = 0.7 -- share of the ring the segments cover, the rest are gaps
local SEGMENT_THICKNESS = 0.35 -- studs
local SEGMENT_HEIGHT = 0.7 -- studs at the start, shrinking as the ring fades
local FLASH_SECONDS = 0.12
local FLASH_SIZE = 3 -- studs
local DUST_POINTS = 8 -- puffs around the ring
local DUST_PER_POINT = 2
local DUST_RADIUS = 0.6 -- share of the blast radius
local HEIGHT = 1.5 -- studs above the floor for the flash
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is X: lay the disc flat

type WaveParts = { disc: BasePart, flash: BasePart, segments: { BasePart } }

type Wave = {
	parts: WaveParts?,
	userId: number,
	x: number,
	z: number,
	radius: number,
	at: number, -- server time of the blast
	placed: boolean, -- centered on the owner once, then it stays there
}

local pool = VisualKit.objectPool(function(): WaveParts
	local segments: { BasePart } = {}
	for _ = 1, SEGMENTS do
		table.insert(segments, VisualKit.part("ShockwaveRing", Enum.PartType.Block, Vector3.one, RING_COLOR))
	end
	return {
		disc = VisualKit.part("Shockwave", Enum.PartType.Cylinder, Vector3.new(DISC_THICKNESS, 1, 1), WAVE_COLOR),
		flash = VisualKit.part("ShockwaveFlash", Enum.PartType.Ball, Vector3.one, FLASH_COLOR),
		segments = segments,
	}
end, function(parts: WaveParts): { BasePart }
	local list = { parts.disc, parts.flash }
	for _, segment in parts.segments do
		table.insert(list, segment)
	end
	return list
end)

local waves: { Wave } = {}

local function remove(index: number)
	local wave = table.remove(waves, index) :: Wave
	if wave.parts then
		pool:release(wave.parts)
	end
end

local function kickDust(wave: Wave, y: number)
	for point = 1, DUST_POINTS do
		local angle = 2 * math.pi * point / DUST_POINTS
		local distance = wave.radius * DUST_RADIUS
		local at = Vector3.new(wave.x + math.cos(angle) * distance, y, wave.z + math.sin(angle) * distance)
		Bursts.emit("dust", DUST_COLOR, at, DUST_PER_POINT)
	end
end

local Shockwave = {}

function Shockwave.effect(effect: Types.WeaponEffect)
	if effect.kind == "Pulse" then
		table.insert(waves, {
			parts = nil,
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
		local age = math.max(0, frame.now - wave.at)
		local t = age / DURATION
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
		local parts = wave.parts
		if not parts then
			parts = pool:acquire(frame.folder)
			wave.parts = parts
			kickDust(wave, frame.floorY + 0.5)
		end
		local current = parts :: WaveParts
		local grow = 1 - (1 - t) ^ 2 -- fast first, then slowing down
		local radius = wave.radius * (START_SIZE + (1 - START_SIZE) * grow)

		current.disc.Size = Vector3.new(DISC_THICKNESS, 2 * radius, 2 * radius)
		current.disc.Transparency = DISC_TRANSPARENCY + (1 - DISC_TRANSPARENCY) * t
		frame.move(current.disc, CFrame.new(wave.x, frame.floorY + DISC_HEIGHT, wave.z) * UPRIGHT)

		local flashT = math.min(1, age / FLASH_SECONDS)
		current.flash.Size = Vector3.one * FLASH_SIZE * (1 - 0.6 * flashT)
		current.flash.Transparency = 0.1 + 0.9 * flashT
		frame.move(current.flash, CFrame.new(wave.x, frame.floorY + HEIGHT, wave.z))

		local height = SEGMENT_HEIGHT * (1 - 0.7 * t)
		local length = 2 * math.pi * radius / SEGMENTS * SEGMENT_FILL
		local size = Vector3.new(SEGMENT_THICKNESS, height, math.max(0.1, length))
		local transparency = 0.1 + 0.9 * t * t
		local y = frame.floorY + height / 2
		for segment, part in current.segments do
			local angle = 2 * math.pi * segment / SEGMENTS
			local cx, cz = math.cos(angle), math.sin(angle)
			local position = Vector3.new(wave.x + cx * radius, y, wave.z + cz * radius)
			part.Size = size
			part.Transparency = transparency
			frame.move(part, CFrame.lookAt(position, position + Vector3.new(-cz, 0, cx)))
		end
	end
end

function Shockwave.clear()
	for index = #waves, 1, -1 do
		remove(index)
	end
end

return Shockwave
