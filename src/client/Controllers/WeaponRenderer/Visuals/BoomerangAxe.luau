--!strict
-- Boomerang Axe look: a spinning double-headed axe per "Fire" effect (dark handle, brass heads with glowing
-- edges) that sweeps a ring of light behind it as it flies out at the server's speed and range, then back to its
-- owner's character as this client sees it, until the server's "End" effect says it is gone. Visual for
-- WeaponRenderer (behavior WeaponService/Behaviors/BoomerangAxe).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local VisualKit = require(script.Parent.Parent.VisualKit)

local EDGE_COLOR = Color3.fromRGB(255, 150, 90) -- hot orange
local HEAD_COLOR = Color3.fromRGB(196, 150, 72) -- brass
local HANDLE_COLOR = Color3.fromRGB(64, 46, 40)
local HANDLE_SIZE = Vector3.new(2.2, 0.22, 0.22) -- studs, along X
local HEAD_SIZE = Vector3.new(0.55, 0.28, 1.1)
local EDGE_SIZE = Vector3.new(0.2, 0.2, 1.35)
local HEAD_AT = 0.85 -- studs from the middle
local EDGE_AT = 1.2
local TRAIL_WIDTH = 2.6 -- studs, the ring the spinning edges sweep
local TRAIL_SECONDS = 0.1
local HEIGHT = 2 -- studs above the floor
local SPIN = math.rad(900) -- radians/s
local MAX_SECONDS = 5 -- drops an axe whose "End" effect never arrived

-- where each part sits on the spinning axe
local OFFSETS = {
	headA = CFrame.new(HEAD_AT, 0, 0),
	headB = CFrame.new(-HEAD_AT, 0, 0),
	edgeA = CFrame.new(EDGE_AT, 0, 0),
	edgeB = CFrame.new(-EDGE_AT, 0, 0),
}

type AxeParts = {
	handle: BasePart,
	headA: BasePart,
	headB: BasePart,
	edgeA: BasePart,
	edgeB: BasePart,
	trail: Trail,
}

type Axe = {
	parts: AxeParts?,
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

local pool = VisualKit.objectPool(function(): AxeParts
	local handle = VisualKit.solid("BoomerangAxe", Enum.PartType.Block, HANDLE_SIZE, HANDLE_COLOR, Enum.Material.Wood)
	local function head()
		return VisualKit.solid("BoomerangAxeHead", Enum.PartType.Block, HEAD_SIZE, HEAD_COLOR, Enum.Material.Metal)
	end
	local function edge()
		return VisualKit.part("BoomerangAxeEdge", Enum.PartType.Block, EDGE_SIZE, EDGE_COLOR)
	end
	return {
		handle = handle,
		headA = head(),
		headB = head(),
		edgeA = edge(),
		edgeB = edge(),
		trail = VisualKit.trail(handle, EDGE_COLOR, TRAIL_WIDTH, TRAIL_SECONDS, "X"),
	}
end, function(parts: AxeParts): { BasePart }
	return { parts.handle, parts.headA, parts.headB, parts.edgeA, parts.edgeB }
end)

local axes: { [number]: Axe } = {} -- by projectile id

local function remove(id: number, axe: Axe)
	if axe.parts then
		pool:release(axe.parts)
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
			parts = nil,
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
		local parts = axe.parts
		if not parts then
			local created = pool:acquire(frame.folder)
			created.trail:Clear()
			axe.parts = created
			parts = created
		end
		local current = parts :: AxeParts
		local cframe = CFrame.new(x, frame.floorY + HEIGHT, z) * CFrame.Angles(0, age * SPIN, 0)
		frame.move(current.handle, cframe)
		frame.move(current.headA, cframe * OFFSETS.headA)
		frame.move(current.headB, cframe * OFFSETS.headB)
		frame.move(current.edgeA, cframe * OFFSETS.edgeA)
		frame.move(current.edgeB, cframe * OFFSETS.edgeB)
	end
end

function BoomerangAxe.clear()
	for id, axe in axes do
		remove(id, axe)
	end
end

return BoomerangAxe
