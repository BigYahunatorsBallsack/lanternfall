--!strict
-- Placeholder enemy looks from 2-5 parts each (DESIGN.md section 14: violet-black bodies, glowing eyes,
-- one silhouette per type). Built in code for EnemyRenderer's pool until real models arrive in WP21.
-- Sizes follow each enemy's collision radius from Config.Enemies, so what you see is what touches you. Enemies with
-- a `look` reuse that silhouette in their own colors (Abyss variants: near-black with red eyes). Chargers carry a
-- floor strip that lights up during their wind-up and shows where they will rush (setMode). Gloom Elites
-- (Util/EnemyKinds, WP9) use the same silhouette, bigger, with golden eyes, a violet glow, an HP bar and the name of
-- their affix (setAffix).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EnemyKinds = require(Shared:WaitForChild("Util"):WaitForChild("EnemyKinds"))

export type Visual = {
	model: Model,
	parts: { BasePart },
	offsets: { CFrame }, -- per part, relative to the enemy's floor point, facing -Z
	body: BasePart, -- flashes on hits, turns red while a charger winds up and rushes
	bodyColor: Color3,
	glowColor: Color3, -- its eyes; death bursts use it
	hpBar: Frame?, -- elites only: width = remaining HP fraction
	affixLabel: TextLabel?, -- elites only
	glow: PointLight?, -- elites only
	telegraph: BasePart?, -- chargers only: the rush path on the floor
	mode: number, -- what setMode last showed
	affix: number, -- what setAffix last showed
}

type Palette = { body: Color3, head: Color3, eye: Color3, accent: Color3 }

local DEFAULT_PALETTE: Palette = {
	body = Color3.fromRGB(44, 26, 68),
	head = Color3.fromRGB(32, 18, 50),
	eye = Color3.fromRGB(205, 130, 255),
	accent = Color3.fromRGB(255, 92, 200), -- the Spitter's mouth
}
local PALETTES: { [string]: Palette } = {
	AbyssShadeling = {
		body = Color3.fromRGB(18, 10, 28),
		head = Color3.fromRGB(12, 6, 20),
		eye = Color3.fromRGB(255, 70, 90),
		accent = Color3.fromRGB(255, 70, 90),
	},
	AbyssBrute = {
		body = Color3.fromRGB(22, 12, 30),
		head = Color3.fromRGB(14, 8, 22),
		eye = Color3.fromRGB(255, 70, 90),
		accent = Color3.fromRGB(255, 70, 90),
	},
	Charger = {
		body = Color3.fromRGB(70, 28, 44),
		head = Color3.fromRGB(48, 18, 30),
		eye = Color3.fromRGB(255, 150, 70),
		accent = Color3.fromRGB(255, 150, 70),
	},
	Splitter = {
		body = Color3.fromRGB(30, 46, 70),
		head = Color3.fromRGB(22, 32, 52),
		eye = Color3.fromRGB(110, 230, 255),
		accent = Color3.fromRGB(110, 230, 255),
	},
	Splitling = {
		body = Color3.fromRGB(36, 56, 84),
		head = Color3.fromRGB(22, 32, 52),
		eye = Color3.fromRGB(110, 230, 255),
		accent = Color3.fromRGB(110, 230, 255),
	},
}
local UNKNOWN_COLOR = Color3.fromRGB(255, 0, 255)
local RUSH_COLOR = Color3.fromRGB(255, 60, 60) -- body while a charger winds up and rushes
local TELEGRAPH_TRANSPARENCY = 0.55 -- the rush path during the wind-up
local ELITE_BODY_COLOR = Color3.fromRGB(86, 40, 132)
local ELITE_EYE_COLOR = Color3.fromRGB(255, 196, 87) -- lantern gold
local ELITE_GLOW_COLOR = Color3.fromRGB(170, 100, 255)
local AFFIX_COLORS: { [string]: Color3 } = {
	Swift = Color3.fromRGB(90, 220, 255),
	Armored = Color3.fromRGB(210, 220, 240),
	Summoner = Color3.fromRGB(120, 255, 140),
}
local ELITE_GLOW_BRIGHTNESS = 3
local ELITE_GLOW_RANGE = 14 -- studs
local HP_BAR_COLOR = Color3.fromRGB(236, 96, 96)
local HP_BAR_BACK_COLOR = Color3.fromRGB(24, 20, 34)
local HP_BAR_WIDTH = 70 -- pixels
local HP_BAR_HEIGHT_PIXELS = 8
local AFFIX_TEXT_SIZE = 16
local HP_BAR_HEIGHT = 1.4 -- studs above the top of the model

local Models = {}

Models.MODE_WINDUP = 1
Models.MODE_RUSH = 2

local function newPart(
	model: Model,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	color: Color3,
	glow: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false -- CanQuery may only be turned off once CanCollide is off
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

type Builder = (model: Model, radius: number, palette: Palette) -> ({ BasePart }, { CFrame })

-- Each builder returns the parts (body first) and their offsets for an enemy of `radius`.
local BUILDERS: { [string]: Builder } = {
	-- round blob with two eyes
	Shadeling = function(model, r, palette)
		local body = newPart(model, "Body", Enum.PartType.Ball, Vector3.one * 2 * r, palette.body, false)
		local eyeSize = Vector3.one * 0.32 * r
		local left = newPart(model, "EyeLeft", Enum.PartType.Ball, eyeSize, palette.eye, true)
		local right = newPart(model, "EyeRight", Enum.PartType.Ball, eyeSize, palette.eye, true)
		return { body, left, right }, {
			CFrame.new(0, r, 0),
			CFrame.new(-0.35 * r, 1.25 * r, -0.82 * r),
			CFrame.new(0.35 * r, 1.25 * r, -0.82 * r),
		}
	end,
	-- wide block with a head and two eyes
	Brute = function(model, r, palette)
		local body =
			newPart(model, "Body", Enum.PartType.Block, Vector3.new(2 * r, 1.6 * r, 1.6 * r), palette.body, false)
		local head =
			newPart(model, "Head", Enum.PartType.Block, Vector3.new(0.9 * r, 0.7 * r, 0.9 * r), palette.head, false)
		local eyeSize = Vector3.one * 0.2 * r
		local left = newPart(model, "EyeLeft", Enum.PartType.Ball, eyeSize, palette.eye, true)
		local right = newPart(model, "EyeRight", Enum.PartType.Ball, eyeSize, palette.eye, true)
		return { body, head, left, right }, {
			CFrame.new(0, 0.8 * r, 0),
			CFrame.new(0, 1.95 * r, -0.3 * r),
			CFrame.new(-0.2 * r, 2 * r, -0.76 * r),
			CFrame.new(0.2 * r, 2 * r, -0.76 * r),
		}
	end,
	-- thin stalk with a round head and a glowing mouth
	Spitter = function(model, r, palette)
		local stalk =
			newPart(model, "Body", Enum.PartType.Cylinder, Vector3.new(2 * r, 1.2 * r, 1.2 * r), palette.body, false)
		local head = newPart(model, "Head", Enum.PartType.Ball, Vector3.one * 1.5 * r, palette.head, false)
		local mouth = newPart(model, "Mouth", Enum.PartType.Ball, Vector3.one * 0.55 * r, palette.accent, true)
		return { stalk, head, mouth }, {
			CFrame.new(0, r, 0) * CFrame.Angles(0, 0, math.pi / 2), -- a cylinder's axis is X: stand it up
			CFrame.new(0, 2.4 * r, 0),
			CFrame.new(0, 2.4 * r, -0.62 * r),
		}
	end,
	-- low, long block with two glowing horns in front
	Charger = function(model, r, palette)
		local body =
			newPart(model, "Body", Enum.PartType.Block, Vector3.new(1.7 * r, 1.1 * r, 2 * r), palette.body, false)
		local hornSize = Vector3.new(0.25 * r, 0.25 * r, 0.9 * r)
		local left = newPart(model, "HornLeft", Enum.PartType.Block, hornSize, palette.accent, true)
		local right = newPart(model, "HornRight", Enum.PartType.Block, hornSize, palette.accent, true)
		local eyeSize = Vector3.one * 0.22 * r
		local eyeLeft = newPart(model, "EyeLeft", Enum.PartType.Ball, eyeSize, palette.eye, true)
		local eyeRight = newPart(model, "EyeRight", Enum.PartType.Ball, eyeSize, palette.eye, true)
		return { body, left, right, eyeLeft, eyeRight }, {
			CFrame.new(0, 0.55 * r, 0),
			CFrame.new(-0.6 * r, 1 * r, -1.25 * r),
			CFrame.new(0.6 * r, 1 * r, -1.25 * r),
			CFrame.new(-0.3 * r, 0.75 * r, -1.02 * r),
			CFrame.new(0.3 * r, 0.75 * r, -1.02 * r),
		}
	end,
	-- lumpy blob made of three lobes and one big eye: it falls apart into Splitlings
	Splitter = function(model, r, palette)
		local body = newPart(model, "Body", Enum.PartType.Ball, Vector3.one * 1.7 * r, palette.body, false)
		local lobeSize = Vector3.one * 0.9 * r
		local top = newPart(model, "LobeTop", Enum.PartType.Ball, lobeSize, palette.head, false)
		local left = newPart(model, "LobeLeft", Enum.PartType.Ball, lobeSize, palette.head, false)
		local right = newPart(model, "LobeRight", Enum.PartType.Ball, lobeSize, palette.head, false)
		local eye = newPart(model, "Eye", Enum.PartType.Ball, Vector3.one * 0.45 * r, palette.eye, true)
		return { body, top, left, right, eye }, {
			CFrame.new(0, 0.85 * r, 0),
			CFrame.new(0, 1.65 * r, 0.1 * r),
			CFrame.new(-0.7 * r, 1.25 * r, 0.25 * r),
			CFrame.new(0.7 * r, 1.25 * r, 0.25 * r),
			CFrame.new(0, 1 * r, -0.78 * r),
		}
	end,
	-- small ball with one eye
	Splitling = function(model, r, palette)
		local body = newPart(model, "Body", Enum.PartType.Ball, Vector3.one * 2 * r, palette.body, false)
		local eye = newPart(model, "Eye", Enum.PartType.Ball, Vector3.one * 0.5 * r, palette.eye, true)
		return { body, eye }, {
			CFrame.new(0, r, 0),
			CFrame.new(0, 1.2 * r, -0.8 * r),
		}
	end,
}

-- Magenta cube for a typeId the client does not know (should never happen; shows up clearly in tests).
local function buildUnknown(model: Model, r: number): ({ BasePart }, { CFrame })
	local body = newPart(model, "Body", Enum.PartType.Block, Vector3.one * 2 * r, UNKNOWN_COLOR, false)
	return { body }, { CFrame.new(0, r, 0) }
end

-- Red strip on the floor in front of a charger, as long as its rush (hidden until it winds up).
local function addTelegraph(model: Model, parts: { BasePart }, offsets: { CFrame }, r: number, length: number): BasePart
	local strip = newPart(model, "RushPath", Enum.PartType.Block, Vector3.new(1.6 * r, 0.12, length), RUSH_COLOR, true)
	strip.Transparency = 1
	table.insert(parts, strip)
	table.insert(offsets, CFrame.new(0, 0.08, -(r + length / 2)))
	return strip
end

type EliteParts = { hpBar: Frame, affixLabel: TextLabel, glow: PointLight }

-- Glow, golden eyes, an affix name and an HP bar on top of a normal model.
local function makeElite(parts: { BasePart }, offsets: { CFrame }): EliteParts
	local body = parts[1]
	body.Color = ELITE_BODY_COLOR
	local top = 0
	for k, part in parts do
		if part.Material == Enum.Material.Neon and part.Name ~= "RushPath" then
			part.Color = ELITE_EYE_COLOR
		end
		top = math.max(top, offsets[k].Position.Y + part.Size.Y / 2)
	end
	local light = Instance.new("PointLight")
	light.Color = ELITE_GLOW_COLOR
	light.Brightness = ELITE_GLOW_BRIGHTNESS
	light.Range = ELITE_GLOW_RANGE
	light.Parent = body

	local gui = Instance.new("BillboardGui")
	gui.Name = "HpBar"
	gui.Size = UDim2.fromOffset(HP_BAR_WIDTH * 2, AFFIX_TEXT_SIZE + HP_BAR_HEIGHT_PIXELS + 2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top - offsets[1].Position.Y + HP_BAR_HEIGHT, 0)
	gui.AlwaysOnTop = true
	gui.Parent = body
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
	return { hpBar = fill, affixLabel = label, glow = light }
end

function Models.build(typeId: number): Visual
	local enemy = EnemyKinds.byTypeId(typeId)
	local model = Instance.new("Model")
	model.Name = if enemy then (if enemy.elite then `Elite{enemy.id}` else enemy.id) else `Unknown{typeId}`
	local look = enemy and EnemyKinds.lookOf(enemy)
	local builder = look and BUILDERS[look]
	local palette = enemy and PALETTES[enemy.id] or DEFAULT_PALETTE
	local parts, offsets
	if enemy and builder then
		parts, offsets = builder(model, enemy.radius, palette)
	else
		parts, offsets = buildUnknown(model, if enemy then enemy.radius else 1.5)
	end
	local telegraph = if enemy and enemy.charge
		then addTelegraph(model, parts, offsets, enemy.radius, enemy.charge.maxDistance)
		else nil
	local elite = if enemy and enemy.elite then makeElite(parts, offsets) else nil
	return {
		model = model,
		parts = parts,
		offsets = offsets,
		body = parts[1],
		bodyColor = parts[1].Color,
		glowColor = if elite then ELITE_EYE_COLOR else palette.eye,
		hpBar = elite and elite.hpBar,
		affixLabel = elite and elite.affixLabel,
		glow = elite and elite.glow,
		telegraph = telegraph,
		mode = 0,
		affix = 0,
	}
end

-- The body color for a mode: red while winding up or rushing, its own otherwise.
function Models.colorFor(visual: Visual, mode: number): Color3
	return if mode == Models.MODE_WINDUP or mode == Models.MODE_RUSH then RUSH_COLOR else visual.bodyColor
end

-- Shows a charger's mode (0 walk, 1 wind-up, 2 rush, 3 recover): red body from the wind-up through the rush, the
-- rush path on the floor only during the wind-up.
function Models.setMode(visual: Visual, mode: number)
	if visual.mode == mode then
		return
	end
	visual.mode = mode
	visual.body.Color = Models.colorFor(visual, mode)
	local telegraph = visual.telegraph
	if telegraph then
		telegraph.Transparency = if mode == Models.MODE_WINDUP then TELEGRAPH_TRANSPARENCY else 1
	end
end

-- Shows an elite's affix (0 = none, else index into Config.Enemies.elite.affixes) as a colored name and glow.
function Models.setAffix(visual: Visual, affix: number)
	local label, glow = visual.affixLabel, visual.glow
	if visual.affix == affix or not (label and glow) then
		return
	end
	visual.affix = affix
	local info = Config.Enemies.elite.affixes[affix]
	local color = if info then AFFIX_COLORS[info.id] or ELITE_GLOW_COLOR else ELITE_GLOW_COLOR
	label.Visible = info ~= nil
	label.Text = if info then string.upper(info.displayName) else ""
	label.TextColor3 = color
	glow.Color = color
end

return Models
