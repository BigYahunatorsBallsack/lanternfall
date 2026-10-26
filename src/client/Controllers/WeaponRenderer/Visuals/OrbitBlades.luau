--!strict
-- Orbit Blades look: glowing blades spinning around their owner from bladeInnerRadius out to `radius`, placed with
-- the same angle math as the server's hits (Util/Orbit), so the server sends no effects for them. Blade Storm
-- (evolution) blades glow red. Visual for
-- WeaponRenderer (behavior WeaponService/Behaviors/OrbitBlades).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Orbit = require(Shared:WaitForChild("Util"):WaitForChild("Orbit"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local VisualKit = require(script.Parent.Parent.VisualKit)

local BLADE_COLOR = Color3.fromRGB(255, 226, 150) -- warm lantern light
local STORM_COLOR = Color3.fromRGB(255, 110, 90) -- Blade Storm
local BLADE_THICKNESS = 0.25 -- studs
local DRAWN_WIDTH = 0.6 -- share of the hit width that is drawn, so blades look like blades
local HEIGHT = 1.5 -- studs above the floor

type BladeSet = {
	parts: { BasePart },
	size: Vector3,
	color: Color3,
	seenFrame: number,
}

local pool = VisualKit.pool(function()
	return VisualKit.part("OrbitBlade", Enum.PartType.Block, Vector3.one, BLADE_COLOR)
end)

local sets: { [string]: BladeSet } = {} -- by "userId:weaponId"

local function release(key: string, set: BladeSet)
	for _, part in set.parts do
		pool:release(part)
	end
	sets[key] = nil
end

local OrbitBlades = {}

function OrbitBlades.renderWeapon(owner: VisualKit.Owner, weapon: Types.WeaponInfo, frame: VisualKit.Frame)
	local stats = weapon.stats
	local key = `{owner.userId}:{weapon.id}`
	local set = sets[key]
	if not set then
		set = { parts = {}, size = Vector3.zero, color = BLADE_COLOR, seenFrame = 0 }
		sets[key] = set
	end
	local current = set :: BladeSet
	current.seenFrame = frame.number

	local count = math.max(0, math.floor(stats.count))
	local parts = current.parts
	while #parts < count do
		table.insert(parts, pool:acquire(frame.folder))
	end
	while #parts > count do
		pool:release(table.remove(parts) :: BasePart)
	end

	local inner, outer = stats.bladeInnerRadius, stats.radius
	local size = Vector3.new(stats.bladeWidth * DRAWN_WIDTH, BLADE_THICKNESS, math.max(0.1, outer - inner))
	local resized = size ~= current.size
	current.size = size
	local color = if weapon.evolution then STORM_COLOR else BLADE_COLOR
	local recolored = color ~= current.color
	current.color = color

	local middle = (inner + outer) / 2
	local center = owner.position
	local y = frame.floorY + HEIGHT
	for index, part in parts do
		if resized or part.Size ~= size then
			part.Size = size
		end
		if recolored or part.Color ~= color then
			part.Color = color
		end
		local angle = Orbit.bladeAngle(stats.rotationSpeed, weapon.addedAt, frame.now, index, count)
		local cx, cz = math.cos(angle), math.sin(angle)
		local position = Vector3.new(center.X + cx * middle, y, center.Z + cz * middle)
		frame.move(part, CFrame.lookAt(position, position + Vector3.new(cx, 0, cz)))
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
