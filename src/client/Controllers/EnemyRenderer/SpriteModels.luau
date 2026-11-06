--!strict
-- EnemyRenderer's looks since Paket 25: every enemy is one pooled 2D sprite plus a flat shadow on the floor, with the same
-- functions as the former rig module (Models.luau). The figure's width follows the enemy's collision radius
-- (Config/Sprites); pictures come from Config/SpriteImages.
-- Gloom Elites keep their crown, HP and affix label, Swift trail, Armored steel and Summoning wisps. Bosses and champions
-- keep their red glow; BossController draws their attack warnings. Floor warnings stay flat parts on the floor.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EnemyKinds = require(Shared:WaitForChild("Util"):WaitForChild("EnemyKinds"))

local WorldSprite = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("WorldSprite")
)

local SpritesConfig = require(Shared:WaitForChild("Config"):WaitForChild("Sprites"))

local Sprites = Config.Sprites
local Look = Sprites.enemy

local SHADOW_COLOR = Color3.fromRGB(table.unpack(Sprites.shadow.color))
local SHADOW_TRANSPARENCY = Sprites.shadow.transparency
local SHADOW_THICKNESS = Sprites.shadow.thickness
local SHADOW_DIAMETER = 2 -- times the radius
local TELEGRAPH_COLOR = Color3.fromRGB(255, 60, 60)
local TELEGRAPH_TRANSPARENCY = 0.55
local HEAL_RING_COLOR = Color3.fromRGB(120, 255, 150)
local BUFF_RING_COLOR = Color3.fromRGB(255, 206, 92)
local RING_THICKNESS = 0.1 -- studs
local WHITE = Color3.new(1, 1, 1)
local BURN_COLOR = Color3.fromRGB(255, 96, 28)
local FROST_COLOR = Color3.fromRGB(140, 200, 255)
local BUFF_COLOR = Color3.fromRGB(255, 206, 92)
local ELITE_GOLD = Color3.fromRGB(236, 188, 88)
local AFFIX_COLORS: { [string]: Color3 } = {
	Swift = Color3.fromRGB(90, 220, 255),
	Armored = Color3.fromRGB(214, 224, 240),
	Summoner = Color3.fromRGB(120, 255, 140),
}
local HP_BAR_COLOR = Color3.fromRGB(236, 96, 96)
local HP_BAR_BACK_COLOR = Color3.fromRGB(24, 20, 34)
local HP_BAR_WIDTH = 70 -- pixels
local HP_BAR_HEIGHT_PIXELS = 8
local AFFIX_TEXT_SIZE = 16
local HP_BAR_HEIGHT = 1.4 -- studs above the top of the sprite
local TRAIL_SECONDS = 0.3
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
local DEFAULT_GLOW = Color3.fromRGB(200, 125, 255)
local RUSH_TINT = Color3.fromRGB(table.unpack(Look.rushTint))
local STEEL_TINT = Color3.fromRGB(table.unpack(Look.steelTint))

type Gait = { stride: number, bob: number, roll: number, lean: number, legSwing: number, armSwing: number }

export type Visual = {
	model: Model,
	body: BasePart, -- invisible anchor of the sprite; other modules read its position
	sprite: WorldSprite.Sprite,
	shadow: BasePart,
	gait: Gait,
	radius: number,
	speed: number,
	glowColor: Color3,
	hpBar: Frame?,
	affixLabel: TextLabel?,
	trail: Trail?,
	crown: WorldSprite.Sprite?,
	wisps: { WorldSprite.Sprite },
	telegraph: BasePart?,
	telegraphOffset: CFrame,
	windupTint: boolean,
	mode: number,
	affix: number,
	flashing: boolean,
	burning: boolean,
	slowed: boolean,
	buffed: boolean,
	lowDetail: boolean,
	poseTick: number,
}

local SpriteModels = {}

SpriteModels.MODE_WINDUP = 1
SpriteModels.MODE_RUSH = 2
SpriteModels.MODE_RECOVER = 3

local function flatPart(name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local artCache: { [any]: SpritesConfig.EnemyArt } = {}

-- The sprite values of an enemy kind. An elite has its plain kind's picture; its larger radius makes it larger.
local function artOf(enemy: any): SpritesConfig.EnemyArt?
	if not enemy then
		return nil
	end
	local cached = artCache[enemy]
	if cached then
		return cached
	end
	local image = Sprites.enemyImages[enemy.id]
	if not image then
		return nil
	end
	local gait = Look.gait
	local art: SpritesConfig.EnemyArt = {
		image = image.image,
		studs = enemy.radius * (Look.figureWidths[enemy.id] or Look.figureWidth) / image.width,
		ground = image.ground,
		center = image.center,
		pixels = image.pixels,
		stride = gait.stride,
		bob = gait.bob,
		roll = gait.roll,
		lean = gait.lean,
		glow = if image.color then Color3.fromRGB(table.unpack(image.color)) else nil,
	}
	artCache[enemy] = art
	return art
end

SpriteModels.artOf = artOf

local function addElite(visual: any, art: SpritesConfig.EnemyArt, r: number)
	local anchor = visual.body
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, art.studs * 0.4, 0)
	top.Parent = anchor
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Parent = anchor
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(AFFIX_COLORS.Swift)
	trail.LightEmission = 1
	trail.FaceCamera = true -- flat from straight above otherwise
	trail.Lifetime = TRAIL_SECONDS
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.Enabled = false
	trail.Parent = anchor

	local figureTop = art.studs * (1 - (art.ground or 0))
	local gui = Instance.new("BillboardGui")
	gui.Name = "HpBar"
	gui.Size = UDim2.fromOffset(HP_BAR_WIDTH * 2, AFFIX_TEXT_SIZE + HP_BAR_HEIGHT_PIXELS + 2)
	gui.StudsOffset = Vector3.new(0, figureTop + HP_BAR_HEIGHT, Sprites.depthBias)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Name = "Affix"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, AFFIX_TEXT_SIZE)
	label.Font = Enum.Font.GothamBold
	label.TextSize = AFFIX_TEXT_SIZE
	label.TextStrokeTransparency = 0.4
	label.Text = ""
	label.Visible = false
	label.Parent = gui
	local back = Instance.new("Frame")
	back.Size = UDim2.fromOffset(HP_BAR_WIDTH, HP_BAR_HEIGHT_PIXELS)
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.fromScale(0.5, 1)
	back.BackgroundColor3 = HP_BAR_BACK_COLOR
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = HP_BAR_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = back

	local crown = WorldSprite.create({
		name = "Crown",
		image = Sprites.images.crown,
		studs = Look.crownStuds * r,
	})
	crown.picture.ImageColor3 = ELITE_GOLD
	crown.gui.StudsOffset += Vector3.new(0, figureTop, 0) -- along the sprite, which leans back with the camera
	local crownAnchor = crown.anchor :: BasePart
	crownAnchor.Parent = visual.model
	visual.crown = crown

	for index = 1, 2 do
		local wisp = WorldSprite.glow(`SummonWisp{index}`, Look.wispStuds * r, AFFIX_COLORS.Summoner, 0.4)
		WorldSprite.setVisible(wisp, false)
		local wispAnchor = wisp.anchor :: BasePart
		wispAnchor.Parent = visual.model
		table.insert(visual.wisps, wisp)
	end
	visual.hpBar = fill
	visual.affixLabel = label
	visual.trail = trail
end

function SpriteModels.build(typeId: number): Visual
	local enemy: any = EnemyKinds.byTypeId(typeId)
	local model = Instance.new("Model")
	model.Name = if enemy then (if enemy.elite then `Elite{enemy.id}` else enemy.id) else `Unknown{typeId}`
	local r = if enemy then enemy.radius else 1.5
	local art: SpritesConfig.EnemyArt = artOf(enemy)
		or { image = "", studs = r * 3, ground = 0.05, stride = 4, bob = 0.05, roll = 0.05, lean = 0.1 }
	local sprite = WorldSprite.create({
		name = "Body",
		image = art.image,
		studs = art.studs,
		ground = art.ground or 0,
		center = art.center or 0.5,
		pixels = art.pixels,
	})
	local body = sprite.anchor :: BasePart
	body.Parent = model

	local shadow = flatPart(
		"Shadow",
		Enum.PartType.Cylinder,
		Vector3.new(SHADOW_THICKNESS, SHADOW_DIAMETER * r, SHADOW_DIAMETER * r),
		SHADOW_COLOR,
		Enum.Material.SmoothPlastic
	)
	shadow.Transparency = SHADOW_TRANSPARENCY
	shadow.Parent = model

	local telegraph: BasePart? = nil
	local telegraphOffset = CFrame.identity
	if enemy and enemy.charge then
		local length = enemy.charge.maxDistance
		telegraph = flatPart(
			"RushPath",
			Enum.PartType.Block,
			Vector3.new(1.6 * r, 0.12, length),
			TELEGRAPH_COLOR,
			Enum.Material.Neon
		)
		telegraphOffset = CFrame.new(0, 0.08, -(r + length / 2))
	elseif enemy and (enemy.slash or enemy.pulse) then
		local radius = if enemy.slash then enemy.slash.radius + Config.Simulation.playerRadius else enemy.pulse.radius
		local color = if enemy.slash
			then TELEGRAPH_COLOR
			elseif enemy.pulse.heal then HEAL_RING_COLOR
			else BUFF_RING_COLOR
		telegraph = flatPart(
			if enemy.slash then "CutArea" else "PulseRing",
			Enum.PartType.Cylinder,
			Vector3.new(RING_THICKNESS, 2 * radius, 2 * radius),
			color,
			Enum.Material.Neon
		)
		telegraphOffset = CFrame.new(0, 0.06, 0) * UPRIGHT
	end
	if telegraph then
		telegraph.Transparency = 1
		telegraph.Parent = model
	end

	local visual: any = {
		model = model,
		body = body,
		sprite = sprite,
		shadow = shadow,
		gait = { stride = art.stride, bob = art.bob, roll = art.roll, lean = art.lean, legSwing = 0, armSwing = 0 },
		radius = r,
		speed = if enemy then enemy.speed else 10,
		glowColor = art.glow or DEFAULT_GLOW,
		wisps = {},
		telegraph = telegraph,
		telegraphOffset = telegraphOffset,
		windupTint = enemy ~= nil and enemy.pulse == nil,
		mode = 0,
		affix = 0,
		flashing = false,
		burning = false,
		slowed = false,
		buffed = false,
		lowDetail = false,
		poseTick = 0,
	}
	if enemy and enemy.elite then
		addElite(visual, art, r)
	end
	return visual
end

local function isCharging(mode: number): boolean
	return mode == SpriteModels.MODE_WINDUP or mode == SpriteModels.MODE_RUSH
end

-- Colors of the picture: hit flash first, then a charger's wind-up, then status, then Armored steel.
local function paint(visual: Visual)
	local sprite = visual.sprite
	if visual.flashing then
		WorldSprite.setTint(sprite, WHITE, Look.flashBrightness)
		return
	end
	local color = WHITE
	if visual.windupTint and isCharging(visual.mode) then
		color = RUSH_TINT
	elseif visual.burning then
		color = WHITE:Lerp(BURN_COLOR, Look.statusTint)
	elseif visual.slowed then
		color = WHITE:Lerp(FROST_COLOR, Look.statusTint)
	elseif visual.buffed then
		color = WHITE:Lerp(BUFF_COLOR, Look.statusTint)
	elseif visual.hpBar then
		local affix = Config.Enemies.elite.affixes[visual.affix]
		if affix and affix.id == "Armored" then
			color = STEEL_TINT
		end
	end
	WorldSprite.setTint(sprite, color)
end

-- Loads every enemy image while the player is in the lobby.
function SpriteModels.preload()
	local probes: { Instance } = {}
	for _, entry in Sprites.enemyImages do
		local probe = Instance.new("ImageLabel")
		probe.Image = entry.image
		table.insert(probes, probe)
	end
	local ok, err = pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(probes)
	end)
	for _, probe in probes do
		probe:Destroy()
	end
	if not ok then
		warn(`[Lanternfall] Enemy sprite preload failed: {err}`)
	end
end

function SpriteModels.setFlash(visual: Visual, on: boolean)
	if visual.flashing ~= on then
		visual.flashing = on
		paint(visual)
	end
end

function SpriteModels.setStatus(visual: Visual, burning: boolean, slowed: boolean, buffed: boolean?)
	local isBuffed = buffed == true
	if visual.burning ~= burning or visual.slowed ~= slowed or visual.buffed ~= isBuffed then
		visual.burning, visual.slowed, visual.buffed = burning, slowed, isBuffed
		paint(visual)
	end
end

-- A charger's mode (0 walk, 1 wind-up, 2 rush, 3 recover): the red picture from the wind-up through the rush and
-- the warning on the floor only during the wind-up.
function SpriteModels.setMode(visual: Visual, mode: number)
	if visual.mode == mode then
		return
	end
	visual.mode = mode
	paint(visual)
	local telegraph = visual.telegraph
	if telegraph then
		telegraph.Transparency = if mode == SpriteModels.MODE_WINDUP then TELEGRAPH_TRANSPARENCY else 1
	end
end

-- An elite's affix: its colored name and crown, Swift's trail, Armored's steel and Summoning's wisps.
function SpriteModels.setAffix(visual: Visual, affix: number)
	local label, crown = visual.affixLabel, visual.crown
	if visual.affix == affix or not (label and crown) then
		return
	end
	visual.affix = affix
	local info = Config.Enemies.elite.affixes[affix]
	local id = if info then info.id else nil
	local color = if id then AFFIX_COLORS[id] or ELITE_GOLD else ELITE_GOLD
	label.Visible = info ~= nil
	label.Text = if info then string.upper(info.displayName) else ""
	label.TextColor3 = color
	crown.picture.ImageColor3 = color
	local trail = visual.trail
	if trail then
		trail.Enabled = id == "Swift"
		trail:Clear()
	end
	for _, wisp in visual.wisps do
		WorldSprite.setVisible(wisp, id == "Summoner")
	end
	paint(visual)
end

-- Big crowds pose the picture less often; the sprite itself always stays.
function SpriteModels.setDetail(visual: Visual, on: boolean)
	visual.lowDetail = on
end

function SpriteModels.reset(visual: Visual)
	visual.flashing = false
	visual.burning, visual.slowed, visual.buffed = false, false, false
	SpriteModels.setMode(visual, 0)
	paint(visual)
	local trail = visual.trail
	if trail then
		trail:Clear()
	end
end

-- Queues the parts of `visual` for this frame, standing at `base` (floor point, turned where it walks), and poses the
-- picture: it mirrors to the side it walks to, hops and sways with the walk. Returns the new list length.
function SpriteModels.pose(
	visual: Visual,
	base: CFrame,
	phase: number,
	move: number,
	now: number,
	seed: number,
	parts: { BasePart },
	cframes: { CFrame },
	count: number
): number
	local gait, r, mode = visual.gait, visual.radius, visual.mode
	local s = math.sin(phase)
	local hop = gait.bob * r * move * math.abs(s)
	local shift = 0
	local rotation = math.deg(gait.roll * move * s)
	local scaleX, scaleY = 1, 1
	if mode == SpriteModels.MODE_WINDUP then
		scaleY = Look.windupScale
		scaleX = 2 - Look.windupScale
		shift = Look.tremble * r * math.sin(now * Look.trembleSpeed)
	elseif mode == SpriteModels.MODE_RUSH then
		rotation = if visual.sprite.flipped then -Look.rushDegrees else Look.rushDegrees
	elseif mode == SpriteModels.MODE_RECOVER then
		rotation = if visual.sprite.flipped then Look.recoverDegrees else -Look.recoverDegrees
	else
		local breath = math.sin(now * Look.idleSpeed + seed) * Look.idleSquash * (1 - move)
		local stride = math.abs(s) * Look.squash * move
		scaleY = 1 + breath + stride
		scaleX = 1 - breath - stride * 0.6
	end

	local position = base.Position
	local x, y, z = position.X, position.Y, position.Z
	local look = base.LookVector
	if math.abs(look.X) > 0.15 then
		WorldSprite.setFlip(visual.sprite, look.X < 0)
	end
	visual.poseTick += 1
	if not visual.lowDetail or visual.poseTick % Look.lowDetailStep == 0 then
		WorldSprite.pose(visual.sprite, scaleX, scaleY, rotation)
	end

	count += 1
	parts[count] = visual.body
	cframes[count] = CFrame.new(x + shift, y, z - hop) -- north is up on the screen; height would not show
	count += 1
	parts[count] = visual.shadow
	cframes[count] = CFrame.new(x, y + SHADOW_THICKNESS, z) * UPRIGHT
	local telegraph = visual.telegraph
	if telegraph and telegraph.Transparency < 1 then
		count += 1
		parts[count] = telegraph
		cframes[count] = base * visual.telegraphOffset
	end
	local crown: WorldSprite.Sprite? = visual.crown
	if crown then
		count += 1
		parts[count] = crown.anchor :: BasePart
		cframes[count] = CFrame.new(x, y, z - hop)
		crown.picture.Rotation = (now * Look.crownSpinDegrees + seed * 57) % 360
	end
	for index, wisp in visual.wisps do
		if wisp.gui.Enabled then
			local angle = now * Look.wispSpeed + seed + index * math.pi
			count += 1
			parts[count] = wisp.anchor :: BasePart
			cframes[count] = CFrame.new(
				x + math.cos(angle) * Look.wispOrbit * r,
				y,
				z - hop - r + math.sin(angle) * Look.wispOrbit * r
			)
		end
	end
	return count
end

return SpriteModels
