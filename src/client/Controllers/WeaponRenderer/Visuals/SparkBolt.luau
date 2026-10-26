--!strict
-- Spark Bolt look: a glowing bolt per "Fire" effect, flying from where the server fired it at the server's speed and
-- vanishing at its range or where an "End" effect says an enemy stopped it. Positions follow server time, so the
-- bolt is where the server has it. Starfire's "Blast" effects show as a quickly fading glowing ball. Visual for WeaponRenderer (behavior WeaponService/Behaviors/SparkBolt).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local VisualKit = require(script.Parent.Parent.VisualKit)

local BOLT_COLOR = Color3.fromRGB(170, 225, 255) -- bright spark blue
local BOLT_SIZE = Vector3.new(0.5, 0.5, 2.2) -- studs, long side along the flight
local HEIGHT = 2 -- studs above the floor
local BLAST_COLOR = Color3.fromRGB(255, 190, 90) -- Starfire orange
local BLAST_DURATION = 0.3 -- seconds
local BLAST_START_SIZE = 0.4 -- share of the radius the ball starts at
local BLAST_TRANSPARENCY = 0.4

type Bolt = {
	part: BasePart?,
	x: number,
	z: number,
	dx: number,
	dz: number,
	speed: number,
	range: number,
	at: number, -- server time it was fired
	stopAt: number?, -- studs; set by the "End" effect
}

local pool = VisualKit.pool(function()
	return VisualKit.part("SparkBolt", Enum.PartType.Block, BOLT_SIZE, BOLT_COLOR)
end)

type Blast = {
	part: BasePart?,
	x: number,
	z: number,
	radius: number,
	at: number,
}

local blastPool = VisualKit.pool(function()
	return VisualKit.part("Starfire", Enum.PartType.Ball, Vector3.one, BLAST_COLOR)
end)

local bolts: { [number]: Bolt } = {} -- by projectile id
local blasts: { Blast } = {}

local function removeBlast(index: number)
	local blast = table.remove(blasts, index) :: Blast
	if blast.part then
		blastPool:release(blast.part)
	end
end

local function remove(id: number, bolt: Bolt)
	if bolt.part then
		pool:release(bolt.part)
	end
	bolts[id] = nil
end

local SparkBolt = {}

function SparkBolt.effect(effect: Types.WeaponEffect)
	if effect.kind == "Blast" then
		table.insert(
			blasts,
			{ part = nil, x = effect.x or 0, z = effect.z or 0, radius = effect.radius or 0, at = effect.at }
		)
		return
	end
	local id = effect.id
	if not id then
		return
	end
	if effect.kind == "Fire" then
		bolts[id] = {
			part = nil,
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
		if distance >= math.min(bolt.range, bolt.stopAt or math.huge) then
			remove(id, bolt)
			continue
		end
		local part = bolt.part
		if not part then
			part = pool:acquire(frame.folder)
			bolt.part = part
		end
		local position = Vector3.new(bolt.x + bolt.dx * distance, frame.floorY + HEIGHT, bolt.z + bolt.dz * distance)
		frame.move(part :: BasePart, CFrame.lookAt(position, position + Vector3.new(bolt.dx, 0, bolt.dz)))
	end
	for index = #blasts, 1, -1 do
		local blast = blasts[index]
		local t = math.max(0, (frame.now - blast.at) / BLAST_DURATION)
		if t >= 1 then
			removeBlast(index)
			continue
		end
		local part = blast.part
		if not part then
			part = blastPool:acquire(frame.folder)
			blast.part = part
		end
		local ball = part :: BasePart
		ball.Size = Vector3.one * 2 * blast.radius * (BLAST_START_SIZE + (1 - BLAST_START_SIZE) * t)
		ball.Transparency = BLAST_TRANSPARENCY + (1 - BLAST_TRANSPARENCY) * t
		frame.move(ball, CFrame.new(blast.x, frame.floorY + HEIGHT, blast.z))
	end
end

function SparkBolt.clear()
	for id, bolt in bolts do
		remove(id, bolt)
	end
	for index = #blasts, 1, -1 do
		removeBlast(index)
	end
end

return SparkBolt
