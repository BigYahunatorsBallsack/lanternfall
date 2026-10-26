--!strict
-- Shared pieces for weapon visuals (WeaponRenderer/Visuals): the Frame and Visual types, glowing parts and a part
-- pool. Used by WeaponRenderer and every visual module.

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

local VisualKit = {}

-- An anchored glowing part that never collides, casts no shadow and is ignored by raycasts and touches.
function VisualKit.part(name: string, shape: Enum.PartType, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
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
	return part
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

return VisualKit
