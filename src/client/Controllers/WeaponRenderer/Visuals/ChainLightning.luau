--!strict
-- Chain Lightning look: thin glowing bolts from the owner to the first enemy and on from enemy to enemy, flashing for
-- a moment per "Chain" effect. The first point is moved to the owner's character as this client sees it. Visual for
-- WeaponRenderer (behavior WeaponService/Behaviors/ChainLightning).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local VisualKit = require(script.Parent.Parent.VisualKit)

local BOLT_COLOR = Color3.fromRGB(190, 170, 255) -- violet lightning
local DURATION = 0.25 -- seconds the chain stays visible
local THICKNESS = 0.35 -- studs
local HEIGHT = 2 -- studs above the floor
local MIN_LENGTH = 0.1 -- studs

type Chain = {
	parts: { BasePart },
	userId: number,
	points: { number }, -- x1, z1, x2, z2, ...
	at: number,
	placed: boolean,
}

local pool = VisualKit.pool(function()
	return VisualKit.part("ChainLightning", Enum.PartType.Block, Vector3.one, BOLT_COLOR)
end)

local chains: { Chain } = {}

local function remove(index: number)
	local chain = table.remove(chains, index) :: Chain
	for _, part in chain.parts do
		pool:release(part)
	end
end

local ChainLightning = {}

function ChainLightning.effect(effect: Types.WeaponEffect)
	local points = effect.points
	if effect.kind == "Chain" and typeof(points) == "table" and #points >= 4 then
		table.insert(chains, { parts = {}, userId = effect.userId, points = points, at = effect.at, placed = false })
	end
end

function ChainLightning.render(frame: VisualKit.Frame)
	for index = #chains, 1, -1 do
		local chain = chains[index]
		local t = math.max(0, (frame.now - chain.at) / DURATION)
		if t >= 1 then
			remove(index)
			continue
		end
		local points = chain.points
		if not chain.placed then
			chain.placed = true
			local position = frame.ownerPosition(chain.userId)
			if position then
				points[1], points[2] = position.X, position.Z
			end
			local y = frame.floorY + HEIGHT
			for k = 1, #points // 2 - 1 do
				local a = Vector3.new(points[2 * k - 1], y, points[2 * k])
				local b = Vector3.new(points[2 * k + 1], y, points[2 * k + 2])
				local length = math.max(MIN_LENGTH, (b - a).Magnitude)
				local part = pool:acquire(frame.folder)
				part.Size = Vector3.new(THICKNESS, THICKNESS, length)
				part.CFrame = if (b - a).Magnitude > MIN_LENGTH then CFrame.lookAt((a + b) / 2, b) else CFrame.new(a)
				table.insert(chain.parts, part)
			end
		end
		for _, part in chain.parts do
			part.Transparency = t
		end
	end
end

function ChainLightning.clear()
	for index = #chains, 1, -1 do
		remove(index)
	end
end

return ChainLightning
