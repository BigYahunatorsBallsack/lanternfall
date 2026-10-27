--!strict
-- Orbit Blades look: brass blades with a glowing cutting edge on the side they turn towards, each sweeping a
-- fading arc of light, spinning around their owner from bladeInnerRadius out to `radius`. They are placed with the
-- same angle math as the server's hits (Util/Orbit), so the server sends no effects for them. Blade Storm
-- (evolution) blades are dark iron with a red edge. Visual for WeaponRenderer (behavior
-- WeaponService/Behaviors/OrbitBlades).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Orbit = require(Shared:WaitForChild("Util"):WaitForChild("Orbit"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local VisualKit = require(script.Parent.Parent.VisualKit)

local EDGE_COLOR = Color3.fromRGB(255, 226, 150) -- warm lantern light
local BODY_COLOR = Color3.fromRGB(196, 150, 72) -- brass
local STORM_EDGE_COLOR = Color3.fromRGB(255, 96, 70) -- Blade Storm
local STORM_BODY_COLOR = Color3.fromRGB(70, 56, 60) -- dark iron
local BLADE_THICKNESS = 0.25 -- studs
local DRAWN_WIDTH = 0.6 -- share of the hit width that is drawn, so blades look like blades
local EDGE_SHARE = 0.4 -- share of the drawn width that glows
local EDGE_THICKNESS = 0.6 -- share of the blade's thickness
local TRAIL_SECONDS = 0.14
local HEIGHT = 1.5 -- studs above the floor

type Blade = { edge: BasePart, body: BasePart, trail: Trail }

type BladeSet = {
	blades: { Blade },
	size: Vector3,
	storm: boolean?,
	seenFrame: number,
}

local pool = VisualKit.objectPool(function(): Blade
	local edge = VisualKit.part("OrbitBlade", Enum.PartType.Block, Vector3.one, EDGE_COLOR)
	local body = VisualKit.solid("OrbitBladeBody", Enum.PartType.Block, Vector3.one, BODY_COLOR, Enum.Material.Metal)
	local trail = VisualKit.trail(edge, EDGE_COLOR, 1, TRAIL_SECONDS, "Z")
	return { edge = edge, body = body, trail = trail }
end, function(blade: Blade): { BasePart }
	return { blade.edge, blade.body }
end)

local sets: { [string]: BladeSet } = {} -- by "userId:weaponId"

local function release(key: string, set: BladeSet)
	for _, blade in set.blades do
		pool:release(blade)
	end
	sets[key] = nil
end

-- Sizes a blade's parts for a drawn blade of `size` (width, thickness, length) and stretches its trail along it.
local function shape(blade: Blade, size: Vector3)
	blade.body.Size = Vector3.new(size.X * (1 - EDGE_SHARE), size.Y, size.Z)
	blade.edge.Size = Vector3.new(size.X * EDGE_SHARE, size.Y * EDGE_THICKNESS, size.Z)
	local a, b = blade.trail.Attachment0, blade.trail.Attachment1
	if a and b then
		a.Position = Vector3.zAxis * size.Z / 2
		b.Position = -Vector3.zAxis * size.Z / 2
	end
end

local function paint(blade: Blade, storm: boolean)
	local edge = if storm then STORM_EDGE_COLOR else EDGE_COLOR
	blade.edge.Color = edge
	blade.body.Color = if storm then STORM_BODY_COLOR else BODY_COLOR
	blade.trail.Color = ColorSequence.new(edge)
end

local OrbitBlades = {}

function OrbitBlades.renderWeapon(owner: VisualKit.Owner, weapon: Types.WeaponInfo, frame: VisualKit.Frame)
	local stats = weapon.stats
	local key = `{owner.userId}:{weapon.id}`
	local set = sets[key]
	if not set then
		set = { blades = {}, size = Vector3.zero, storm = nil, seenFrame = 0 }
		sets[key] = set
	end
	local current = set :: BladeSet
	current.seenFrame = frame.number

	local inner, outer = stats.bladeInnerRadius, stats.radius
	local size = Vector3.new(stats.bladeWidth * DRAWN_WIDTH, BLADE_THICKNESS, math.max(0.1, outer - inner))
	local storm = weapon.evolution ~= nil
	local changed = size ~= current.size or storm ~= current.storm
	current.size = size
	current.storm = storm

	local count = math.max(0, math.floor(stats.count))
	local blades = current.blades
	while #blades < count do
		local blade = pool:acquire(frame.folder)
		shape(blade, size)
		paint(blade, storm)
		blade.trail:Clear()
		table.insert(blades, blade)
	end
	while #blades > count do
		pool:release(table.remove(blades) :: Blade)
	end

	-- the edge leads: local +X of a blade looking outwards points where growing angles turn
	local side = if stats.rotationSpeed >= 0 then 1 else -1
	local edgeOffset = CFrame.new(side * size.X * (1 - EDGE_SHARE) / 2, 0, 0)
	local bodyOffset = CFrame.new(-side * size.X * EDGE_SHARE / 2, 0, 0)
	local middle = (inner + outer) / 2
	local center = owner.position
	local y = frame.floorY + HEIGHT
	for index, blade in blades do
		if changed then
			shape(blade, size)
			paint(blade, storm)
		end
		local angle = Orbit.bladeAngle(stats.rotationSpeed, weapon.addedAt, frame.now, index, count)
		local cx, cz = math.cos(angle), math.sin(angle)
		local position = Vector3.new(center.X + cx * middle, y, center.Z + cz * middle)
		local cframe = CFrame.lookAt(position, position + Vector3.new(cx, 0, cz))
		frame.move(blade.edge, cframe * edgeOffset)
		frame.move(blade.body, cframe * bodyOffset)
	end
end

function OrbitBlades.render(frame: VisualKit.Frame)
	for key, set in sets do
		if set.seenFrame ~= frame.number then
			release(key, set) -- weapon gone, owner down or left
		end
	end
end

function OrbitBlades.clear()
	for key, set in sets do
		release(key, set)
	end
end

return OrbitBlades
