--!strict
-- Shared pieces for weapon visuals (WeaponRenderer/Visuals): the Frame and Visual types, glowing parts and
-- wedges, solid parts, trails and part pools. The look (DESIGN.md section 14): a white-hot core inside a colored,
-- see-through halo, with a fading trail behind anything that flies, and brass for anything solid. Used by
-- WeaponRenderer, every visual module, EnemyShotRenderer and ChestController.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

-- A player whose weapons are drawn this frame.
export type Owner = {
	userId: number,
	position: Vector3, -- the character's root as this client sees it
}

export type Frame = {
	number: number, -- counts up every frame
	now: number, -- server time
	dt: number,
	floorY: number,
	folder: Folder, -- parent for weapon parts
	-- queues a part for this frame's workspace:BulkMoveTo
	move: (part: BasePart, cframe: CFrame) -> (),
	-- where a player's character is on this client, nil without a character
	ownerPosition: (userId: number) -> Vector3?,
	-- whether that player's weapon with this behavior has evolved (e.g. Starfire bolts look different)
	evolved: (userId: number, behavior: string) -> boolean,
}

export type Visual = {
	-- Every frame, for each weapon with this behavior whose owner is alive in the run.
	renderWeapon: ((owner: Owner, weapon: Types.WeaponInfo, frame: Frame) -> ())?,
	-- Every frame after renderWeapon: draw effects and release whatever was not drawn this frame.
	render: ((frame: Frame) -> ())?,
	-- A server effect for this behavior (Net/Types.WeaponEffect); only store it, render draws it.
	effect: ((effect: Types.WeaponEffect) -> ())?,
	-- Drop everything (run over or renderer switched off).
	clear: (() -> ())?,
}

export type Pool = {
	acquire: (self: Pool, parent: Instance) -> BasePart,
	release: (self: Pool, part: BasePart) -> (),
}

-- A pool of visuals made of several parts (core, halo, ...): `partsOf` lists the parts to parent and unparent.
export type ObjectPool<T> = {
	acquire: (self: ObjectPool<T>, parent: Instance) -> T,
	release: (self: ObjectPool<T>, object: T) -> (),
}

local VisualKit = {}

local function configure(part: BasePart, name: string, size: Vector3, color: Color3)
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false -- CanQuery may only be turned off once CanCollide is off
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- An anchored glowing part that never collides, casts no shadow and is ignored by raycasts and touches.
function VisualKit.part(name: string, shape: Enum.PartType, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Shape = shape
	configure(part, name, size, color)
	return part
end

-- A glowing wedge (thorns, blade tips), otherwise like VisualKit.part: its slope falls towards -Z.
function VisualKit.wedge(name: string, size: Vector3, color: Color3): WedgePart
	local part = Instance.new("WedgePart")
	configure(part, name, size, color)
	return part
end

-- Turns a block part into an ellipsoid of its size (round halos around long bolts).
function VisualKit.egg(part: BasePart): BasePart
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- A see-through glowing part around a core, for the soft light around bolts and blades.
function VisualKit.halo(name: string, shape: Enum.PartType, size: Vector3, color: Color3, transparency: number): Part
	local part = VisualKit.part(name, shape, size, color)
	part.Transparency = transparency
	return part
end

-- A part that does not glow (brass, wood, steel), otherwise like VisualKit.part.
function VisualKit.solid(
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = VisualKit.part(name, shape, size, color)
	part.Material = material
	return part
end

-- A glowing trail behind `part`, as wide as `width` studs along the part's own `axis` ("X", "Y" or "Z"). Moving
-- the part draws it; call trail:Clear() after a pooled part jumps to a new place.
function VisualKit.trail(part: BasePart, color: Color3, width: number, lifetime: number, axis: string?): Trail
	local direction = if axis == "Y" then Vector3.yAxis elseif axis == "Z" then Vector3.zAxis else Vector3.xAxis
	local a = Instance.new("Attachment")
	a.Name = "TrailA"
	a.Position = direction * width / 2
	a.Parent = part
	local b = Instance.new("Attachment")
	b.Name = "TrailB"
	b.Position = -direction * width / 2
	b.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a
	trail.Attachment1 = b
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.Lifetime = lifetime
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	trail.Parent = part
	return trail
end

-- Reuses parts made by `build` instead of creating and destroying them all the time.
function VisualKit.pool(build: () -> BasePart): Pool
	local free: { BasePart } = {}
	local pool = {}
	function pool.acquire(_, parent: Instance): BasePart
		local part = table.remove(free) or build()
		part.Parent = parent
		return part
	end
	function pool.release(_, part: BasePart)
		part.Parent = nil
		table.insert(free, part)
	end
	return (pool :: any) :: Pool
end

-- Like VisualKit.pool for visuals made of several parts.
function VisualKit.objectPool<T>(build: () -> T, partsOf: (T) -> { BasePart }): ObjectPool<T>
	local free: { T } = {}
	local pool = {}
	function pool.acquire(_, parent: Instance): T
		local object = table.remove(free) or build()
		for _, part in partsOf(object) do
			part.Parent = parent
		end
		return object
	end
	function pool.release(_, object: T)
		for _, part in partsOf(object) do
			part.Parent = nil
		end
		table.insert(free, object)
	end
	return (pool :: any) :: ObjectPool<T>
end

return VisualKit
