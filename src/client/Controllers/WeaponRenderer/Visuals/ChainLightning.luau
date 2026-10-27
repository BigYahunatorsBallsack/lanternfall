--!strict
-- Chain Lightning look: per "Chain" effect, a white-hot thread from the owner to the first enemy and on from enemy
-- to enemy, wrapped in violet arcs that twitch into new curves many times a second, with sparks where it strikes.
-- The first point is moved to the owner's character as this client sees it. Visual for WeaponRenderer (behavior
-- WeaponService/Behaviors/ChainLightning).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Bursts = require(script.Parent.Parent.Parent.Parent.Vfx.Bursts)
local VisualKit = require(script.Parent.Parent.VisualKit)

local CORE_COLOR = Color3.fromRGB(240, 232, 255)
local ARC_COLOR = Color3.fromRGB(176, 140, 255) -- violet lightning
local GLOW_COLOR = Color3.fromRGB(120, 80, 230)
local DURATION = 0.25 -- seconds the chain stays visible
local THICKNESS = 0.15 -- studs, the white core
local ARC_WIDTH = 0.35 -- studs
local GLOW_WIDTH = 1.1 -- studs
local ARC_CURVE = 2.5 -- studs, how far an arc may bend away from the core (scaled by hop length below)
local CURVE_PER_STUD = 0.25 -- short hops bend less
local FLICKER_SECONDS = 0.04 -- the arcs take new curves this often
local HEIGHT = 2 -- studs above the floor
local MIN_LENGTH = 0.1 -- studs
local STRIKE_SPARKS = 6

type Hop = { core: BasePart, arc: Beam, glow: Beam, bend: number }

type Chain = {
	hops: { Hop },
	userId: number,
	points: { number }, -- x1, z1, x2, z2, ...
	at: number,
	placed: boolean,
	flickerAt: number,
}

local function beam(core: BasePart, a: Attachment, b: Attachment, color: Color3, width: number): Beam
	local created = Instance.new("Beam")
	created.Attachment0 = a
	created.Attachment1 = b
	created.Color = ColorSequence.new(color)
	created.LightEmission = 1
	created.FaceCamera = true
	created.Width0 = width
	created.Width1 = width
	created.Segments = 8
	created.Parent = core
	return created
end

local pool = VisualKit.objectPool(function(): Hop
	local core = VisualKit.part("ChainLightning", Enum.PartType.Block, Vector3.one, CORE_COLOR)
	local a = Instance.new("Attachment")
	a.Name = "From"
	a.Parent = core
	local b = Instance.new("Attachment")
	b.Name = "To"
	b.Parent = core
	return {
		core = core,
		arc = beam(core, a, b, ARC_COLOR, ARC_WIDTH),
		glow = beam(core, a, b, GLOW_COLOR, GLOW_WIDTH),
		bend = 0,
	}
end, function(hop: Hop): { BasePart }
	return { hop.core }
end)

local chains: { Chain } = {}

local function remove(index: number)
	local chain = table.remove(chains, index) :: Chain
	for _, hop in chain.hops do
		pool:release(hop)
	end
end

local function randomCurve(bend: number): number
	return (math.random() * 2 - 1) * bend
end

-- New random bends for every arc of a chain, so the lightning twitches.
local function flicker(chain: Chain)
	for _, hop in chain.hops do
		hop.arc.CurveSize0 = randomCurve(hop.bend)
		hop.arc.CurveSize1 = randomCurve(hop.bend)
		hop.glow.CurveSize0 = randomCurve(hop.bend * 0.5)
		hop.glow.CurveSize1 = randomCurve(hop.bend * 0.5)
	end
end

local function place(chain: Chain, frame: VisualKit.Frame)
	local points = chain.points
	local position = frame.ownerPosition(chain.userId)
	if position then
		points[1], points[2] = position.X, position.Z
	end
	local y = frame.floorY + HEIGHT
	for k = 1, #points // 2 - 1 do
		local a = Vector3.new(points[2 * k - 1], y, points[2 * k])
		local b = Vector3.new(points[2 * k + 1], y, points[2 * k + 2])
		local length = math.max(MIN_LENGTH, (b - a).Magnitude)
		local hop = pool:acquire(frame.folder)
		hop.core.Size = Vector3.new(THICKNESS, THICKNESS, length)
		hop.core.CFrame = if (b - a).Magnitude > MIN_LENGTH then CFrame.lookAt((a + b) / 2, b) else CFrame.new(a)
		local from, to = hop.arc.Attachment0, hop.arc.Attachment1
		if from and to then
			from.Position = Vector3.new(0, 0, length / 2)
			to.Position = Vector3.new(0, 0, -length / 2)
		end
		hop.bend = math.min(ARC_CURVE, length * CURVE_PER_STUD)
		table.insert(chain.hops, hop)
		Bursts.emit("spark", ARC_COLOR, b, STRIKE_SPARKS)
	end
	flicker(chain)
	chain.flickerAt = frame.now + FLICKER_SECONDS
end

local ChainLightning = {}

function ChainLightning.effect(effect: Types.WeaponEffect)
	local points = effect.points
	if effect.kind == "Chain" and typeof(points) == "table" and #points >= 4 then
		table.insert(chains, {
			hops = {},
			userId = effect.userId,
			points = points,
			at = effect.at,
			placed = false,
			flickerAt = 0,
		})
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
		if not chain.placed then
			chain.placed = true
			place(chain, frame)
		elseif frame.now >= chain.flickerAt then
			flicker(chain)
			chain.flickerAt = frame.now + FLICKER_SECONDS
		end
		local fade = NumberSequence.new(t)
		local glowFade = NumberSequence.new(0.4 + 0.6 * t)
		for _, hop in chain.hops do
			hop.core.Transparency = t
			hop.arc.Transparency = fade
			hop.glow.Transparency = glowFade
		end
	end
end

function ChainLightning.clear()
	for index = #chains, 1, -1 do
		remove(index)
	end
end

return ChainLightning
