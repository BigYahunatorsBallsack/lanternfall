--!strict
-- Per-weapon pooled projectile visual factory for B7 Visuals, based on SparkBolt.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local LOOK = require(Shared:WaitForChild("Config"):WaitForChild("WeaponVisuals"))
local SPRITES = require(Shared:WaitForChild("Config"):WaitForChild("Sprites"))

local Bursts = require(script.Parent.Parent.Parent.Vfx.Bursts)
local HeldModels = require(script.Parent.HeldModels)
local VisualKit = require(script.Parent.VisualKit)
local WorldSprite = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("WorldSprite")
)

return function(color: Color3)
	local CORE_COLOR = Color3.fromRGB(230, 246, 255)
	local HALO_COLOR = color -- spark blue
	local STARFIRE_CORE_COLOR = Color3.fromRGB(255, 246, 214)
	local STARFIRE_HALO_COLOR = Color3.fromRGB(255, 168, 70)
	local BOLT_STUDS = 2.4 * SPRITES.glowScale -- the picture points along the flight
	local CORE_SHARE = 0.6
	local TRAIL_WIDTH = 0.55
	local TRAIL_SECONDS = 0.16
	local HEIGHT = 2 -- studs above the floor
	local HIT_SPARKS = 5

	type BoltParts = { sprite: WorldSprite.Sprite, core: BasePart, color: Color3, trail: Trail, starfire: boolean }

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
		receivedAt: number,
		startX: number,
		startZ: number,
		stopAt: number?, -- studs; set by the "End" effect
	}

	local boltPool = VisualKit.objectPool(function(): BoltParts
		local sprite = WorldSprite.create({ name = "SparkBolt", image = SPRITES.images.bolt, studs = BOLT_STUDS })
		sprite.picture.ImageColor3 = HALO_COLOR
		WorldSprite.addLayer(sprite, SPRITES.images.bolt, CORE_SHARE, CORE_COLOR)
		local core = sprite.anchor :: BasePart
		local trail = VisualKit.trail(core, HALO_COLOR, TRAIL_WIDTH, TRAIL_SECONDS)
		return { sprite = sprite, core = core, color = HALO_COLOR, trail = trail, starfire = false }
	end, function(parts: BoltParts): { BasePart }
		return { parts.core }
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
		parts.sprite.layers[1].ImageColor3 = if starfire then STARFIRE_CORE_COLOR else CORE_COLOR
		parts.color = if starfire then STARFIRE_HALO_COLOR else HALO_COLOR
		parts.sprite.picture.ImageColor3 = parts.color
		parts.trail.Color = ColorSequence.new(parts.color)
	end

	local SparkBolt = {}

	function SparkBolt.effect(effect: Types.WeaponEffect)
		local id = effect.id
		if not id then
			return
		end
		if effect.kind == "Fire" then
			local startX, startZ = HeldModels.projectileOrigin(effect)
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
				receivedAt = workspace:GetServerTimeNow(),
				startX = startX,
				startZ = startZ,
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
			local blend = math.clamp((frame.now - bolt.receivedAt) / LOOK.projectileCatchupSeconds, 0, 1)
			local lag = math.max(0, bolt.receivedAt - bolt.at)
			local distance = math.max(0, bolt.speed * (frame.now - bolt.at - lag * (1 - blend)))
			local stop = math.min(bolt.range, bolt.stopAt or math.huge)
			if distance >= stop then
				if bolt.stopAt and bolt.parts then
					local parts = bolt.parts :: BoltParts
					local at = Vector3.new(bolt.x + bolt.dx * stop, frame.floorY + HEIGHT, bolt.z + bolt.dz * stop)
					Bursts.emit("spark", parts.color, at, HIT_SPARKS)
				end
				remove(id, bolt)
				continue
			end
			local parts = bolt.parts
			if not parts then
				local created = boltPool:acquire(frame.folder)
				paint(created, false)
				created.trail:Clear()
				bolt.parts = created
				parts = created
			end
			local position = Vector3.new(
				bolt.x + (bolt.startX - bolt.x) * (1 - blend) + bolt.dx * distance,
				frame.floorY + HEIGHT,
				bolt.z + (bolt.startZ - bolt.z) * (1 - blend) + bolt.dz * distance
			)
			local cframe = CFrame.lookAt(position, position + Vector3.new(bolt.dx, 0, bolt.dz))
			local current = parts :: BoltParts
			current.sprite.picture.Rotation = WorldSprite.screenAngle(bolt.dx, bolt.dz)
			frame.move(current.core, cframe)
		end
	end

	function SparkBolt.clear()
		for id, bolt in bolts do
			remove(id, bolt)
		end
	end

	return SparkBolt
end
