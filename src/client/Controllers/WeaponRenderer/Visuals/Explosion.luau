--!strict
-- Explosion look (since B5 for every weapon and item effect that explodes, before only Starfire): a white flash, an
-- expanding ring of fire on the floor and sparks and embers, per "Blast" effect at its center and radius. The
-- server emits them from WeaponService/Arsenal (ctx:explode) under the name "Explosion". Visual for WeaponRenderer.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Bursts = require(script.Parent.Parent.Parent.Parent.Vfx.Bursts)
local VisualKit = require(script.Parent.Parent.VisualKit)

local DURATION = 0.4 -- seconds
local FLASH_SECONDS = 0.12 -- the white flash at the start of a blast
local FLASH_COLOR = Color3.fromRGB(255, 250, 230)
local RING_COLOR = Color3.fromRGB(255, 150, 60)
local EMBER_COLOR = Color3.fromRGB(255, 168, 70)
local RING_THICKNESS = 0.2
local RING_START = 0.3 -- share of the radius the ring starts at
local HEIGHT = 2 -- studs above the floor for the flash
local SPARKS = 10
local EMBERS = 14
local MAX_BLASTS = 24 -- drawn at once; more in one moment are skipped (many small blasts look the same)
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is X: lay the disc flat

type BlastParts = { flash: BasePart, ring: BasePart }

type Blast = {
	parts: BlastParts?,
	x: number,
	z: number,
	radius: number,
	at: number,
}

local pool = VisualKit.objectPool(function(): BlastParts
	return {
		flash = VisualKit.part("Explosion", Enum.PartType.Ball, Vector3.one, FLASH_COLOR),
		ring = VisualKit.part("ExplosionRing", Enum.PartType.Cylinder, Vector3.one, RING_COLOR),
	}
end, function(parts: BlastParts): { BasePart }
	return { parts.flash, parts.ring }
end)

local blasts: { Blast } = {}

local function remove(index: number)
	local blast = table.remove(blasts, index) :: Blast
	if blast.parts then
		pool:release(blast.parts)
	end
end

local Explosion = {}

function Explosion.effect(effect: Types.WeaponEffect)
	if effect.kind == "Blast" and #blasts < MAX_BLASTS then
		table.insert(
			blasts,
			{ parts = nil, x = effect.x or 0, z = effect.z or 0, radius = effect.radius or 0, at = effect.at }
		)
	end
end

function Explosion.render(frame: VisualKit.Frame)
	for index = #blasts, 1, -1 do
		local blast = blasts[index]
		local t = math.max(0, (frame.now - blast.at) / DURATION)
		if t >= 1 then
			remove(index)
			continue
		end
		local center = Vector3.new(blast.x, frame.floorY + HEIGHT, blast.z)
		local parts = blast.parts
		if not parts then
			parts = pool:acquire(frame.folder)
			blast.parts = parts
			Bursts.emit("spark", RING_COLOR, center, SPARKS)
			Bursts.emit("ember", EMBER_COLOR, center, EMBERS)
		end
		local current = parts :: BlastParts
		local flashT = math.min(1, (frame.now - blast.at) / FLASH_SECONDS)
		current.flash.Size = Vector3.one * blast.radius * (1 - 0.5 * flashT)
		current.flash.Transparency = 0.1 + 0.9 * flashT
		frame.move(current.flash, CFrame.new(center))
		local grow = 1 - (1 - t) ^ 3
		local diameter = 2 * blast.radius * (RING_START + (1 - RING_START) * grow)
		current.ring.Size = Vector3.new(RING_THICKNESS, diameter, diameter)
		current.ring.Transparency = 0.15 + 0.85 * t
		frame.move(current.ring, CFrame.new(blast.x, frame.floorY + 0.2, blast.z) * UPRIGHT)
	end
end

function Explosion.clear()
	for index = #blasts, 1, -1 do
		remove(index)
	end
end

return Explosion
