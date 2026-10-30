--!strict
-- Spark Bolt look: a white-hot bolt inside a soft blue halo with a fading trail, per "Fire" effect, flying from where
-- the server fired it at the server's speed and vanishing at its range or where an "End" effect says an enemy
-- stopped it (with a few sparks). Positions follow server time, so the bolt is where the server has it. Starfire
-- (evolution) bolts burn gold; its blasts are drawn by Visuals/Explosion (since B5). A bolt that bounces (B5) ends at
-- the enemy and comes back as a new "Fire" from there. Visual for WeaponRenderer (behavior
-- WeaponService/Behaviors/SparkBolt).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Bursts = require(script.Parent.Parent.Parent.Parent.Vfx.Bursts)
local VisualKit = require(script.Parent.Parent.VisualKit)

local CORE_COLOR = Color3.fromRGB(230, 246, 255)
local HALO_COLOR = Color3.fromRGB(110, 196, 255) -- spark blue
local STARFIRE_CORE_COLOR = Color3.fromRGB(255, 246, 214)
local STARFIRE_HALO_COLOR = Color3.fromRGB(255, 168, 70)
local CORE_SIZE = Vector3.new(0.3, 0.3, 1.5) -- studs, long side along the flight
local HALO_SIZE = Vector3.new(0.95, 0.95, 2.4)
local HALO_TRANSPARENCY = 0.6
local TRAIL_WIDTH = 0.55
local TRAIL_SECONDS = 0.16
local HEIGHT = 2 -- studs above the floor
local HIT_SPARKS = 5

type BoltParts = { core: BasePart, halo: BasePart, trail: Trail, starfire: boolean }

type Bolt = {
	parts: BoltParts?,
	userId: number,
	x: number,
	z: number,
	dx: number,
	dz: number,
	speed: number,
	range: number,
	at: number, -- server time it was fired
	stopAt: number?, -- studs; set by the "End" effect
}

local boltPool = VisualKit.objectPool(function(): BoltParts
	local core = VisualKit.part("SparkBolt", Enum.PartType.Block, CORE_SIZE, CORE_COLOR)
	local halo =
		VisualKit.egg(VisualKit.halo("SparkBoltHalo", Enum.PartType.Block, HALO_SIZE, HALO_COLOR, HALO_TRANSPARENCY))
	local trail = VisualKit.trail(core, HALO_COLOR, TRAIL_WIDTH, TRAIL_SECONDS)
	return { core = core, halo = halo, trail = trail, starfire = false }
end, function(parts: BoltParts): { BasePart }
	return { parts.core, parts.halo }
end)

local bolts: { [number]: Bolt } = {} -- by projectile id

local function remove(id: number, bolt: Bolt)
	if bolt.parts then
		boltPool:release(bolt.parts)
	end
	bolts[id] = nil
end

local function paint(parts: BoltParts, starfire: boolean)
	if parts.starfire == starfire then
		return
	end
	parts.starfire = starfire
	parts.core.Color = if starfire then STARFIRE_CORE_COLOR else CORE_COLOR
	parts.halo.Color = if starfire then STARFIRE_HALO_COLOR else HALO_COLOR
	parts.trail.Color = ColorSequence.new(parts.halo.Color)
end

local SparkBolt = {}

function SparkBolt.effect(effect: Types.WeaponEffect)
	local id = effect.id
	if not id then
		return
	end
	if effect.kind == "Fire" then
		bolts[id] = {
			parts = nil,
			userId = effect.userId,
			x = effect.x or 0,
			z = effect.z or 0,
			dx = effect.dx or 0,
			dz = effect.dz or 0,
			speed = effect.speed or 0,
			range = effect.range or 0,
			at = effect.at,
			stopAt = nil,
		}
	elseif effect.kind == "End" then
		local bolt = bolts[id]
		if bolt then
			bolt.stopAt = effect.distance
		end
	end
end

function SparkBolt.render(frame: VisualKit.Frame)
	for id, bolt in bolts do
		local distance = math.max(0, bolt.speed * (frame.now - bolt.at))
		local stop = math.min(bolt.range, bolt.stopAt or math.huge)
		if distance >= stop then
			if bolt.stopAt and bolt.parts then
				local parts = bolt.parts :: BoltParts
				local at = Vector3.new(bolt.x + bolt.dx * stop, frame.floorY + HEIGHT, bolt.z + bolt.dz * stop)
				Bursts.emit("spark", parts.halo.Color, at, HIT_SPARKS)
			end
			remove(id, bolt)
			continue
		end
		local parts = bolt.parts
		if not parts then
			local created = boltPool:acquire(frame.folder)
			paint(created, frame.evolved(bolt.userId, "SparkBolt"))
			created.trail:Clear()
			bolt.parts = created
			parts = created
		end
		local position = Vector3.new(bolt.x + bolt.dx * distance, frame.floorY + HEIGHT, bolt.z + bolt.dz * distance)
		local cframe = CFrame.lookAt(position, position + Vector3.new(bolt.dx, 0, bolt.dz))
		local current = parts :: BoltParts
		frame.move(current.core, cframe)
		frame.move(current.halo, cframe)
	end
end

function SparkBolt.clear()
	for id, bolt in bolts do
		remove(id, bolt)
	end
end

return SparkBolt
