--!strict
-- Enemy looks (DESIGN.md section 14, art direction "occult art deco"): the Gloom as masked cultists and soot-black
-- creatures with aged brass, porcelain masks and glowing eyes, lenses and cracks, one silhouette per type. Built in
-- code from parts for EnemyRenderer's pool (no uploaded meshes); sizes follow each enemy's collision radius from
-- Config.Enemies, so what you see is what touches you.
-- Every part belongs to a simple rig: it stands on the floor, rides on the body (which bobs, sways and leans while
-- walking) or swings around a pivot (legs, arms, a censer, spinning crowns). Models.pose places all visible parts
-- of one enemy for a frame; EnemyRenderer moves them with workspace:BulkMoveTo. In big crowds EnemyRenderer turns
-- on low detail (setDetail): small trims (claws, filters, hems, bands) vanish and are not moved, a third fewer
-- parts to move.
-- Enemies with a `look` reuse that silhouette in their own palette (Abyss variants: blood-black with crimson eyes
-- and extra spikes). Chargers carry a floor strip that lights up during their wind-up and shows where they will
-- rush; their furnace and eyes turn white-hot (setMode). Gloom Elites (Util/EnemyKinds) are gilded, bigger, wear a
-- spinning sunburst crown, glow and show an HP bar with the name of their affix (setAffix), which also changes
-- their look: Swift leaves a trail, Armored turns its metal to steel, Summoning is circled by two wisps.
-- Since B5 burning enemies glow ember-red and slowed ones turn frost-blue (setStatus).
-- Since B9 the new kinds mostly reuse a silhouette in their own palette (Stalker, Skulker, Thornback, Herald, Mender,
-- Reaper, Gobbler); the Brood Egg has its own. A Reaper shows a red disc of its cut during the wind-up, Heralds and
-- Menders a golden or green ring when they pulse, an egg glows and shakes before it hatches, and enemies a Herald
-- buffed turn gold (setStatus).
-- Since WP10 the bosses: the Lantern Eater, a hulking soot-iron furnace with a porcelain jaw, a glowing grate for a
-- belly and lanterns caged on its back; the Hollow Seer, a towering veiled oracle with one great eye and a spinning
-- brass halo, hovering above the floor. Both carry a red glow. Their attacks are drawn by BossController.
-- Since WP10 part 2 the eight champions of the elite waves, each its own silhouette with the same red glow: a brass
-- ram, a hooded butcher with a cleaver, a robed abbot with a staff, a swamp lizard, a walking obelisk with orbiting
-- stones, a sickle-armed wraith, a brood mother with glowing egg sacs and a winged stone gargoyle.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EnemyKinds = require(Shared:WaitForChild("Util"):WaitForChild("EnemyKinds"))

-- How a part moves (see Models.pose).
local GROUND = 1 -- with the floor point: shadows, the rush path
local BODY = 2 -- with the body
local LEG_LEFT = 3 -- swings around its pivot on the floor frame, legs in turn
local LEG_RIGHT = 4
local ARM_LEFT = 5 -- swings around its pivot on the body, against the legs
local ARM_RIGHT = 6
local SWING = 7 -- pendulum around its pivot on the body (the Spitter's censer)
local SPIN = 8 -- turns around the vertical axis through its pivot on the body (crowns, wisps)
local FLOAT = 9 -- bobs on its own on the body (the Splitter's wisps)

-- How a silhouette walks. `stride` is studs per full step cycle; amplitudes scale with how fast it moves.
type Gait = {
	stride: number,
	bob: number, -- studs (times radius) up and down per step
	roll: number, -- radians of side-to-side sway
	lean: number, -- radians leaning into the walk
	legSwing: number, -- radians
	armSwing: number, -- radians
}

export type Visual = {
	model: Model,
	parts: { BasePart },
	anims: { number }, -- per part, how it moves
	pivots: { CFrame }, -- per part: the pivot (identity for parts without one)
	offsets: { CFrame }, -- per part: relative to its pivot (or to the floor point / body), facing -Z
	hidden: { boolean }, -- per part: invisible right now (an inactive affix, the rush path off), so not posed
	details: { boolean }, -- per part: a small trim that low detail leaves out
	lowDetail: boolean,
	gait: Gait,
	radius: number,
	speed: number, -- studs/s at which the walk animation runs at full swing
	body: BasePart, -- the main part (flashes on hits, turns red while a charger winds up and rushes)
	bodyColor: Color3,
	glowColor: Color3, -- eyes and lenses; death bursts use it
	flashParts: { BasePart }, -- turn white on hits
	flashColors: { Color3 },
	heatParts: { BasePart }, -- chargers: furnace and eyes, white-hot during wind-up and rush
	heatColors: { Color3 },
	metalParts: { BasePart }, -- brass and gold, steel while Armored
	metalColors: { Color3 },
	affixParts: { [number]: { BasePart } }, -- elites: shown only with that affix
	trail: Trail?, -- elites: Swift
	hpBar: Frame?, -- elites only: width = remaining HP fraction
	affixLabel: TextLabel?, -- elites only
	glow: PointLight?, -- elites only
	telegraph: BasePart?, -- chargers: the rush path on the floor; since B9 a Reaper's cut, a Herald's or Mender's ring
	windupTint: boolean, -- the body turns red during the wind-up (chargers, Reapers, eggs; not pulsing kinds)
	mode: number, -- what setMode last showed
	affix: number, -- what setAffix last showed
	flashing: boolean,
	burning: boolean, -- what setStatus last showed
	slowed: boolean,
	buffed: boolean, -- B9: a Herald made it stronger
}

type Palette = {
	cloth: Color3, -- robes, cloaks, coats, hides
	clothDark: Color3,
	soot: Color3, -- limbs, helmets, feet
	metal: Color3, -- brass trims and plates
	metalDark: Color3,
	mask: Color3, -- porcelain masks and bone
	eye: Color3, -- glowing eyes and lenses
	accent: Color3, -- the Spitter's censer and mouth, the Charger's furnace
	spikes: boolean, -- Abyss variants grow horns and spikes
}

-- Colors -----------------------------------------------------------------------------------------------------------

local BRASS = Color3.fromRGB(176, 136, 72)
local BRASS_DARK = Color3.fromRGB(118, 88, 50)
local PORCELAIN = Color3.fromRGB(226, 218, 202)
local SOOT = Color3.fromRGB(26, 22, 30)
local SHADOW_COLOR = Color3.fromRGB(0, 0, 0)

local PALETTES: { [string]: Palette } = {
	Shadeling = {
		cloth = Color3.fromRGB(48, 34, 66),
		clothDark = Color3.fromRGB(34, 24, 48),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(200, 125, 255),
		accent = Color3.fromRGB(200, 125, 255),
		spikes = false,
	},
	Brute = {
		cloth = Color3.fromRGB(56, 50, 66), -- dusty trooper coat
		clothDark = Color3.fromRGB(40, 36, 48),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(255, 176, 70), -- amber gas-mask lenses
		accent = Color3.fromRGB(255, 176, 70),
		spikes = false,
	},
	Spitter = {
		cloth = Color3.fromRGB(70, 30, 62), -- acolyte robe
		clothDark = Color3.fromRGB(46, 20, 42),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(255, 92, 200), -- the same pink as its shots
		accent = Color3.fromRGB(255, 92, 200),
		spikes = false,
	},
	Charger = {
		cloth = Color3.fromRGB(62, 28, 32), -- scorched hide
		clothDark = Color3.fromRGB(42, 20, 24),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = Color3.fromRGB(214, 202, 180), -- bone
		eye = Color3.fromRGB(255, 132, 50),
		accent = Color3.fromRGB(255, 120, 40), -- the furnace on its back
		spikes = false,
	},
	Splitter = {
		cloth = Color3.fromRGB(30, 50, 62), -- dark glaze
		clothDark = Color3.fromRGB(20, 34, 44),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(90, 236, 228),
		accent = Color3.fromRGB(90, 236, 228),
		spikes = false,
	},
	Splitling = {
		cloth = Color3.fromRGB(32, 72, 82),
		clothDark = Color3.fromRGB(22, 48, 56),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(90, 236, 228),
		accent = Color3.fromRGB(90, 236, 228),
		spikes = false,
	},
	-- B6
	Looter = {
		cloth = Color3.fromRGB(96, 74, 40), -- worn ochre coat
		clothDark = Color3.fromRGB(66, 50, 28),
		soot = SOOT,
		metal = BRASS,
		metalDark = Color3.fromRGB(122, 96, 64), -- the sack
		mask = PORCELAIN,
		eye = Color3.fromRGB(255, 214, 92), -- gold, like what it carries
		accent = Color3.fromRGB(255, 196, 87),
		spikes = false,
	},
	-- B9 part 2
	Stalker = { -- a sickly green Shadeling that keeps getting faster
		cloth = Color3.fromRGB(44, 70, 40),
		clothDark = Color3.fromRGB(30, 48, 28),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(170, 255, 90),
		accent = Color3.fromRGB(170, 255, 90),
		spikes = false,
	},
	Skulker = { -- a teal acolyte that keeps away
		cloth = Color3.fromRGB(26, 64, 70),
		clothDark = Color3.fromRGB(18, 44, 50),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(80, 230, 255),
		accent = Color3.fromRGB(80, 230, 255),
		spikes = false,
	},
	Thornback = { -- a rust-red trooper covered in thorns
		cloth = Color3.fromRGB(86, 40, 28),
		clothDark = Color3.fromRGB(60, 28, 20),
		soot = SOOT,
		metal = Color3.fromRGB(150, 96, 60),
		metalDark = Color3.fromRGB(100, 64, 40),
		mask = Color3.fromRGB(214, 202, 180),
		eye = Color3.fromRGB(255, 92, 200), -- the same pink as enemy shots
		accent = Color3.fromRGB(255, 92, 200),
		spikes = true,
	},
	Herald = { -- white robe and gold, the one that makes the others stronger
		cloth = Color3.fromRGB(196, 186, 170),
		clothDark = Color3.fromRGB(150, 140, 126),
		soot = SOOT,
		metal = Color3.fromRGB(236, 188, 88),
		metalDark = Color3.fromRGB(184, 136, 58),
		mask = PORCELAIN,
		eye = Color3.fromRGB(255, 206, 92),
		accent = Color3.fromRGB(255, 206, 92),
		spikes = false,
	},
	Mender = { -- green robe, the healer
		cloth = Color3.fromRGB(40, 92, 56),
		clothDark = Color3.fromRGB(28, 64, 40),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(120, 255, 150),
		accent = Color3.fromRGB(120, 255, 150),
		spikes = false,
	},
	BroodEgg = { -- a pale, veined egg with a violet glow inside
		cloth = Color3.fromRGB(196, 184, 200),
		clothDark = Color3.fromRGB(150, 134, 160),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(200, 125, 255), -- the Shadelings inside
		accent = Color3.fromRGB(200, 125, 255),
		spikes = false,
	},
	Reaper = { -- black hide and bone, a red cut
		cloth = Color3.fromRGB(30, 26, 34),
		clothDark = Color3.fromRGB(20, 16, 24),
		soot = SOOT,
		metal = Color3.fromRGB(190, 190, 200), -- the blade
		metalDark = Color3.fromRGB(120, 120, 130),
		mask = Color3.fromRGB(226, 218, 202),
		eye = Color3.fromRGB(255, 60, 60),
		accent = Color3.fromRGB(255, 60, 60),
		spikes = false,
	},
	Gobbler = { -- a bloated violet thief with a hungry glow
		cloth = Color3.fromRGB(70, 40, 96),
		clothDark = Color3.fromRGB(48, 26, 68),
		soot = SOOT,
		metal = BRASS,
		metalDark = Color3.fromRGB(90, 60, 120), -- the belly sack
		mask = PORCELAIN,
		eye = Color3.fromRGB(170, 255, 120), -- the XP orbs it ate
		accent = Color3.fromRGB(170, 255, 120),
		spikes = false,
	},
	-- WP10 bosses
	LanternEater = { -- soot iron and brass, a furnace glow
		cloth = Color3.fromRGB(40, 32, 36),
		clothDark = Color3.fromRGB(26, 20, 24),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(255, 150, 60),
		accent = Color3.fromRGB(255, 120, 40), -- the grate and the lanterns
		spikes = true,
	},
	HollowSeer = { -- deep teal veils, gold, one pale-blue eye
		cloth = Color3.fromRGB(22, 46, 58),
		clothDark = Color3.fromRGB(14, 30, 40),
		soot = SOOT,
		metal = Color3.fromRGB(236, 188, 88),
		metalDark = Color3.fromRGB(184, 136, 58),
		mask = PORCELAIN,
		eye = Color3.fromRGB(150, 230, 255),
		accent = Color3.fromRGB(255, 70, 90), -- its red circles
		spikes = false,
	},
	-- WP10 part 2: the champions
	BrassRam = { -- soot hide, polished brass horns, a furnace-orange brow
		cloth = Color3.fromRGB(58, 40, 30),
		clothDark = Color3.fromRGB(40, 28, 22),
		soot = SOOT,
		metal = Color3.fromRGB(214, 168, 80),
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(255, 170, 70),
		accent = Color3.fromRGB(255, 120, 40),
		spikes = false,
	},
	Flayer = { -- blood-brown leather, a red-hot cleaver
		cloth = Color3.fromRGB(70, 34, 32),
		clothDark = Color3.fromRGB(46, 30, 26),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(255, 80, 70),
		accent = Color3.fromRGB(255, 90, 60),
		spikes = false,
	},
	Abbot = { -- ash-grey robes, gold sash, violet eyes and orb
		cloth = Color3.fromRGB(70, 66, 78),
		clothDark = Color3.fromRGB(44, 40, 52),
		soot = SOOT,
		metal = Color3.fromRGB(226, 182, 92),
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(200, 120, 255),
		accent = Color3.fromRGB(255, 200, 110),
		spikes = false,
	},
	MireJaw = { -- swamp green scales, brass ridge, yellow eyes
		cloth = Color3.fromRGB(46, 70, 44),
		clothDark = Color3.fromRGB(32, 50, 32),
		soot = Color3.fromRGB(30, 36, 26),
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(240, 230, 90),
		accent = Color3.fromRGB(240, 230, 90),
		spikes = false,
	},
	Monolith = { -- dark slate with cyan runes
		cloth = Color3.fromRGB(56, 58, 70),
		clothDark = Color3.fromRGB(38, 40, 50),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(110, 230, 255),
		accent = Color3.fromRGB(110, 230, 255),
		spikes = false,
	},
	SickleWraith = { -- pale violet chitin, bright brass sickles, green eyes
		cloth = Color3.fromRGB(84, 70, 110),
		clothDark = Color3.fromRGB(56, 46, 78),
		soot = SOOT,
		metal = Color3.fromRGB(220, 176, 90),
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(150, 255, 140),
		accent = Color3.fromRGB(150, 255, 140),
		spikes = false,
	},
	BroodMatron = { -- deep plum with glowing pink egg sacs
		cloth = Color3.fromRGB(78, 36, 64),
		clothDark = Color3.fromRGB(52, 26, 44),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(255, 120, 200),
		accent = Color3.fromRGB(255, 120, 200),
		spikes = false,
	},
	StoneSeraph = { -- weathered grey stone, a gold mouth and eyes
		cloth = Color3.fromRGB(96, 94, 100),
		clothDark = Color3.fromRGB(66, 64, 72),
		soot = Color3.fromRGB(50, 48, 54),
		metal = Color3.fromRGB(226, 182, 92),
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(255, 210, 90),
		accent = Color3.fromRGB(255, 210, 90),
		spikes = false,
	},
	Tree = {
		cloth = Color3.fromRGB(58, 44, 40), -- dark bark
		clothDark = Color3.fromRGB(40, 30, 28),
		soot = SOOT,
		metal = BRASS,
		metalDark = BRASS_DARK,
		mask = PORCELAIN,
		eye = Color3.fromRGB(255, 112, 64), -- lantern fruits, as on the floor (PickupRenderer)
		accent = Color3.fromRGB(52, 78, 58), -- dusky leaves
		spikes = false,
	},
}
-- Abyss variants: blood-black cloth, blackened bronze, obsidian masks, crimson eyes, horns
local ABYSS: Palette = {
	cloth = Color3.fromRGB(34, 14, 22),
	clothDark = Color3.fromRGB(22, 8, 14),
	soot = Color3.fromRGB(14, 8, 12),
	metal = Color3.fromRGB(96, 62, 48),
	metalDark = Color3.fromRGB(64, 40, 32),
	mask = Color3.fromRGB(44, 34, 40),
	eye = Color3.fromRGB(255, 56, 76),
	accent = Color3.fromRGB(255, 56, 76),
	spikes = true,
}
PALETTES.AbyssShadeling = ABYSS
PALETTES.AbyssBrute = ABYSS
-- Gloom Elites: royal violet and gold, golden eyes (affixes tint the glow, see AFFIX_COLORS)
local ELITE_CLOTH = Color3.fromRGB(74, 38, 118)
local ELITE_CLOTH_DARK = Color3.fromRGB(52, 26, 86)
local ELITE_GOLD = Color3.fromRGB(236, 188, 88)
local ELITE_GOLD_DARK = Color3.fromRGB(184, 136, 58)
local ELITE_EYE_COLOR = Color3.fromRGB(255, 206, 92)
local ELITE_GLOW_COLOR = Color3.fromRGB(170, 100, 255)
local AFFIX_COLORS: { [string]: Color3 } = {
	Swift = Color3.fromRGB(90, 220, 255),
	Armored = Color3.fromRGB(214, 224, 240),
	Summoner = Color3.fromRGB(120, 255, 140),
}
local STEEL = Color3.fromRGB(168, 178, 194) -- metal of Armored elites

local UNKNOWN_COLOR = Color3.fromRGB(255, 0, 255)
local FLASH_COLOR = Color3.fromRGB(255, 255, 255)
local RUSH_COLOR = Color3.fromRGB(200, 44, 36) -- charger body during wind-up and rush
local HOT_COLOR = Color3.fromRGB(255, 240, 176) -- charger furnace and eyes during wind-up and rush
local BURN_COLOR = Color3.fromRGB(255, 96, 28) -- burning enemies (B5)
local FROST_COLOR = Color3.fromRGB(140, 200, 255) -- slowed enemies (B5)
local STATUS_TINT = 0.55 -- share of the status color mixed into the body
local TELEGRAPH_COLOR = Color3.fromRGB(255, 60, 60)
local TELEGRAPH_TRANSPARENCY = 0.55 -- the rush path during the wind-up
local BUFF_COLOR = Color3.fromRGB(255, 206, 92) -- enemies a Herald buffed (B9)
local HEAL_RING_COLOR = Color3.fromRGB(120, 255, 150) -- a Mender's pulse (B9)
local BUFF_RING_COLOR = Color3.fromRGB(255, 206, 92) -- a Herald's pulse (B9)
local RING_THICKNESS = 0.1 -- studs

local SHADOW_TRANSPARENCY = 0.6
local SHADOW_THICKNESS = 0.05 -- studs
local ELITE_GLOW_BRIGHTNESS = 3
local ELITE_GLOW_RANGE = 14 -- studs
local BOSS_GLOW_COLOR = Color3.fromRGB(255, 70, 60) -- WP10
local BOSS_GLOW_BRIGHTNESS = 4
local BOSS_GLOW_RANGE = 26 -- studs
local HP_BAR_COLOR = Color3.fromRGB(236, 96, 96)
local HP_BAR_BACK_COLOR = Color3.fromRGB(24, 20, 34)
local HP_BAR_WIDTH = 70 -- pixels
local HP_BAR_HEIGHT_PIXELS = 8
local AFFIX_TEXT_SIZE = 16
local HP_BAR_HEIGHT = 1.4 -- studs above the top of the model
local TRAIL_SECONDS = 0.3

-- Motion -----------------------------------------------------------------------------------------------------------

local WINDUP_CROUCH = 0.12 -- share of the radius a charger sinks while winding up
local WINDUP_TREMBLE = 0.05 -- share of the radius it shakes sideways
local WINDUP_TREMBLE_SPEED = 70 -- radians/s
local WINDUP_REAR = 0.12 -- radians it leans back
local RUSH_LEAN = 0.3 -- radians it leans into the rush
local RECOVER_SLUMP = 0.12 -- radians it hangs its head after the rush
local SWING_SPEED = 2.6 -- radians/s of the censer pendulum
local SWING_ANGLE = 0.35 -- radians
local SPIN_SPEED = 1.6 -- radians/s
local FLOAT_SPEED = 3.2 -- radians/s
local FLOAT_HEIGHT = 0.08 -- share of the radius

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is X: stand it up (round side up)
local FACING = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder's axis is X: turn its round face to the front (-Z)
local TILTED = CFrame.Angles(0.45, 0, 0) -- faces turned up a little, so they read from the camera above
local IDENTITY = CFrame.new()

local Models = {}

Models.MODE_WINDUP = 1
Models.MODE_RUSH = 2
Models.MODE_RECOVER = 3

-- Building ---------------------------------------------------------------------------------------------------------

type Rig = {
	model: Model,
	r: number,
	palette: Palette,
	parts: { BasePart },
	anims: { number },
	pivots: { CFrame },
	offsets: { CFrame },
	details: { boolean },
	flash: { BasePart },
	heat: { BasePart },
	metal: { BasePart },
	top: number, -- highest point of the model (studs above the floor)
	crown: Vector3?, -- where an elite's crown sits
}

local function newRig(model: Model, r: number, palette: Palette): Rig
	return {
		model = model,
		r = r,
		palette = palette,
		parts = {},
		anims = {},
		pivots = {},
		offsets = {},
		details = {},
		flash = {},
		heat = {},
		metal = {},
		top = 0,
		crown = nil,
	}
end

local function setup(part: BasePart, name: string, size: Vector3, color: Color3, material: Enum.Material)
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false -- CanQuery may only be turned off once CanCollide is off
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- Shapes: "block", "ball", "egg" (an ellipsoid of the part's size), "cylinder" (axis X), "wedge" (sloping down
-- towards -Z).
local function newPiece(
	rig: Rig,
	name: string,
	shape: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): BasePart
	local part: BasePart
	if shape == "wedge" then
		part = Instance.new("WedgePart")
	else
		local plain = Instance.new("Part")
		plain.Shape = if shape == "ball"
			then Enum.PartType.Ball
			elseif shape == "cylinder" then Enum.PartType.Cylinder
			else Enum.PartType.Block
		part = plain
		if shape == "egg" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = plain
		end
	end
	setup(part, name, size, color, material)
	part.Parent = rig.model
	return part
end

-- Adds a part to the rig at `cframe` (relative to the floor point or the body), swinging around `pivot` if given.
local function attach(rig: Rig, part: BasePart, anim: number, cframe: CFrame, pivot: Vector3?)
	table.insert(rig.parts, part)
	table.insert(rig.anims, anim)
	table.insert(rig.details, false)
	if pivot then
		table.insert(rig.pivots, CFrame.new(pivot))
		table.insert(rig.offsets, CFrame.new(-pivot) * cframe)
	else
		table.insert(rig.pivots, IDENTITY)
		table.insert(rig.offsets, cframe)
	end
	rig.top = math.max(rig.top, cframe.Position.Y + part.Size.Y / 2)
end

type PieceOptions = {
	anim: number?, -- default BODY
	pivot: Vector3?,
	glow: boolean?, -- Neon
	material: Enum.Material?,
	flash: boolean?,
	heat: boolean?,
	metal: boolean?,
	transparency: number?,
	detail: boolean?, -- a small trim, left out in low detail
}

-- Creates and attaches one part. Positions and sizes are in units of the radius.
local function piece(
	rig: Rig,
	name: string,
	shape: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	options: PieceOptions?,
	rotation: CFrame?
): BasePart
	local o: PieceOptions = options or {}
	local r = rig.r
	local material = if o.glow
		then Enum.Material.Neon
		elseif o.material then o.material
		elseif o.metal then Enum.Material.Metal
		else Enum.Material.SmoothPlastic
	local part = newPiece(rig, name, shape, size * r, color, material)
	if o.transparency then
		part.Transparency = o.transparency
	end
	local pivot = if o.pivot then o.pivot * r else nil
	attach(rig, part, o.anim or BODY, CFrame.new(position * r) * (rotation or IDENTITY), pivot)
	if o.detail then
		rig.details[#rig.details] = true
	end
	if o.flash then
		table.insert(rig.flash, part)
	end
	if o.heat then
		table.insert(rig.heat, part)
	end
	if o.metal then
		table.insert(rig.metal, part)
	end
	return part
end

-- A soft dark disc under the enemy, so it reads as standing on the floor.
local function shadow(rig: Rig, diameter: number)
	local r = rig.r
	local part = newPiece(
		rig,
		"Shadow",
		"cylinder",
		Vector3.new(SHADOW_THICKNESS, diameter * r, diameter * r),
		SHADOW_COLOR,
		Enum.Material.SmoothPlastic
	)
	part.Transparency = SHADOW_TRANSPARENCY
	attach(rig, part, GROUND, CFrame.new(0, SHADOW_THICKNESS, 0) * UPRIGHT)
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local ALONG_X = CFrame.Angles(0, math.pi / 2, 0) -- turns a cylinder's axis (X) onto -Z

-- A cylinder from `from` to `to` (units of the radius), e.g. horns and spikes.
local function rod(
	rig: Rig,
	name: string,
	from: Vector3,
	to: Vector3,
	diameter: number,
	color: Color3,
	options: PieceOptions?
): BasePart
	local length = (to - from).Magnitude
	local middle = (from + to) / 2
	local turn = CFrame.lookAt(Vector3.zero, to - from) * ALONG_X
	return piece(rig, name, "cylinder", v(length, diameter, diameter), middle, color, options, turn)
end

local function eye(rig: Rig, name: string, size: Vector3, position: Vector3, tilt: number)
	piece(rig, name, "block", size, position, rig.palette.eye, { glow = true }, CFrame.Angles(0, 0, tilt))
end

type Build = (rig: Rig) -> Gait

local BUILDERS: { [string]: Build } = {
	-- a hunched, hooded wisp with a porcelain mask and angry slit eyes, scuttling with its claws out
	Shadeling = function(rig)
		local p = rig.palette
		shadow(rig, 1.9)
		piece(
			rig,
			"Body",
			"egg",
			v(1.8, 1.7, 1.7),
			v(0, 0.95, 0.05),
			p.cloth,
			{ material = Enum.Material.Fabric, flash = true }
		)
		piece(rig, "Hood", "egg", v(1.25, 1.15, 1.3), v(0, 1.75, -0.05), p.clothDark, { flash = true })
		piece(
			rig,
			"HoodTip",
			"wedge",
			v(0.35, 0.75, 0.6),
			v(0, 2.3, 0.32),
			p.clothDark,
			{ detail = true },
			CFrame.Angles(-0.3, 0, 0)
		)
		piece(rig, "Mask", "cylinder", v(0.1, 0.9, 0.9), v(0, 1.72, -0.72), p.mask, nil, TILTED * FACING)
		piece(
			rig,
			"EyeLeft",
			"block",
			v(0.26, 0.08, 0.06),
			v(-0.2, 1.8, -0.78),
			p.eye,
			{ glow = true },
			TILTED * CFrame.Angles(0, 0, -0.35)
		)
		piece(
			rig,
			"EyeRight",
			"block",
			v(0.26, 0.08, 0.06),
			v(0.2, 1.8, -0.78),
			p.eye,
			{ glow = true },
			TILTED * CFrame.Angles(0, 0, 0.35)
		)
		piece(
			rig,
			"Amulet",
			"cylinder",
			v(0.08, 0.32, 0.32),
			v(0, 1.12, -0.86),
			p.metal,
			{ metal = true, detail = true },
			FACING
		)
		piece(
			rig,
			"ClawLeft",
			"wedge",
			v(0.18, 0.28, 0.55),
			v(-0.62, 0.78, -0.55),
			p.soot,
			{ anim = ARM_LEFT, pivot = v(-0.62, 1.1, -0.2), detail = true }
		)
		piece(
			rig,
			"ClawRight",
			"wedge",
			v(0.18, 0.28, 0.55),
			v(0.62, 0.78, -0.55),
			p.soot,
			{ anim = ARM_RIGHT, pivot = v(0.62, 1.1, -0.2), detail = true }
		)
		if p.spikes then
			piece(
				rig,
				"HornLeft",
				"wedge",
				v(0.15, 0.6, 0.35),
				v(-0.4, 2.2, -0.05),
				p.metal,
				{ metal = true },
				CFrame.Angles(0, 0, 0.45)
			)
			piece(
				rig,
				"HornRight",
				"wedge",
				v(0.15, 0.6, 0.35),
				v(0.4, 2.2, -0.05),
				p.metal,
				{ metal = true },
				CFrame.Angles(0, 0, -0.45)
			)
		end
		rig.crown = v(0, 2.75, 0.1) * rig.r
		return { stride = 5, bob = 0.12, roll = 0.12, lean = 0.25, legSwing = 0, armSwing = 0.6 }
	end,

	-- a hulking gas-masked trooper: brass chest plate and pauldrons, amber lenses, brass-knuckled fists
	Brute = function(rig)
		local p = rig.palette
		shadow(rig, 2.2)
		piece(
			rig,
			"Body",
			"egg",
			v(1.9, 1.35, 1.35),
			v(0, 1.4, 0.05),
			p.cloth,
			{ material = Enum.Material.Fabric, flash = true }
		)
		piece(rig, "Hips", "block", v(1.35, 0.45, 1), v(0, 0.8, 0.05), p.soot, { detail = true })
		piece(
			rig,
			"ChestPlate",
			"block",
			v(1.1, 0.75, 0.12),
			v(0, 1.5, -0.62),
			p.metal,
			{ metal = true },
			CFrame.Angles(-0.15, 0, 0)
		)
		piece(
			rig,
			"PauldronLeft",
			"egg",
			v(0.85, 0.55, 0.95),
			v(-1, 1.95, 0.05),
			p.metalDark,
			{ metal = true },
			CFrame.Angles(0, 0, 0.25)
		)
		piece(
			rig,
			"PauldronRight",
			"egg",
			v(0.85, 0.55, 0.95),
			v(1, 1.95, 0.05),
			p.metalDark,
			{ metal = true },
			CFrame.Angles(0, 0, -0.25)
		)
		piece(rig, "Helmet", "egg", v(0.8, 0.75, 0.8), v(0, 2.15, -0.3), p.soot, { metal = true, flash = true })
		piece(
			rig,
			"LensLeft",
			"cylinder",
			v(0.06, 0.27, 0.27),
			v(-0.17, 2.22, -0.66),
			p.eye,
			{ glow = true },
			TILTED * FACING
		)
		piece(
			rig,
			"LensRight",
			"cylinder",
			v(0.06, 0.27, 0.27),
			v(0.17, 2.22, -0.66),
			p.eye,
			{ glow = true },
			TILTED * FACING
		)
		piece(
			rig,
			"Filter",
			"cylinder",
			v(0.3, 0.28, 0.28),
			v(0, 1.98, -0.72),
			p.metal,
			{ metal = true, detail = true },
			FACING
		)
		piece(
			rig,
			"HelmetCrest",
			"wedge",
			v(0.14, 0.32, 0.75),
			v(0, 2.55, -0.2),
			p.metal,
			{ metal = true, detail = true }
		)
		piece(
			rig,
			"Tank",
			"cylinder",
			v(0.9, 0.55, 0.55),
			v(0, 1.55, 0.78),
			p.metalDark,
			{ metal = true, detail = true },
			UPRIGHT
		)
		for _, side in { -1, 1 } do
			local arm = if side < 0 then ARM_LEFT else ARM_RIGHT
			local leg = if side < 0 then LEG_LEFT else LEG_RIGHT
			local name = if side < 0 then "Left" else "Right"
			local shoulder = v(1.15 * side, 1.75, 0)
			piece(
				rig,
				`Arm{name}`,
				"block",
				v(0.45, 1, 0.5),
				v(1.15 * side, 1.2, -0.05),
				p.cloth,
				{ anim = arm, pivot = shoulder }
			)
			piece(
				rig,
				`Fist{name}`,
				"block",
				v(0.6, 0.5, 0.6),
				v(1.18 * side, 0.55, -0.12),
				p.metalDark,
				{ anim = arm, pivot = shoulder, metal = true }
			)
			piece(
				rig,
				`Leg{name}`,
				"block",
				v(0.5, 0.7, 0.55),
				v(0.42 * side, 0.35, 0.05),
				p.soot,
				{ anim = leg, pivot = v(0.42 * side, 0.7, 0.05) }
			)
			if p.spikes then
				piece(
					rig,
					`Spike{name}`,
					"wedge",
					v(0.15, 0.6, 0.4),
					v(1 * side, 2.35, 0.05),
					p.metal,
					{ metal = true },
					CFrame.Angles(0, 0, -0.3 * side)
				)
			end
		end
		rig.crown = v(0, 2.75, -0.2) * rig.r
		return { stride = 7, bob = 0.06, roll = 0.08, lean = 0.12, legSwing = 0.5, armSwing = 0.45 }
	end,

	-- a tall robed acolyte with an art-deco sunburst behind its masked head, swinging a glowing censer
	Spitter = function(rig)
		local p = rig.palette
		shadow(rig, 1.7)
		piece(
			rig,
			"Body",
			"cylinder",
			v(1.5, 1.5, 1.5),
			v(0, 0.75, 0),
			p.cloth,
			{ material = Enum.Material.Fabric, flash = true },
			UPRIGHT
		)
		piece(rig, "RobeFlare", "egg", v(1.8, 0.55, 1.8), v(0, 0.27, 0), p.clothDark)
		piece(
			rig,
			"Hem",
			"cylinder",
			v(0.1, 1.84, 1.84),
			v(0, 0.27, 0),
			p.metal,
			{ metal = true, detail = true },
			UPRIGHT
		)
		piece(rig, "Torso", "egg", v(1.05, 1.15, 0.9), v(0, 1.85, 0), p.cloth, { flash = true })
		piece(rig, "Collar", "egg", v(1.1, 0.3, 0.95), v(0, 2.35, 0), p.metal, { metal = true, detail = true })
		piece(rig, "Head", "egg", v(0.7, 0.85, 0.7), v(0, 2.85, 0), p.soot)
		piece(rig, "Mask", "egg", v(0.6, 0.75, 0.2), v(0, 2.85, -0.33), p.mask)
		piece(rig, "Mouth", "block", v(0.09, 0.32, 0.06), v(0, 2.68, -0.44), p.accent, { glow = true, detail = true })
		eye(rig, "EyeLeft", v(0.16, 0.06, 0.05), v(-0.15, 2.98, -0.44), -0.25)
		eye(rig, "EyeRight", v(0.16, 0.06, 0.05), v(0.15, 2.98, -0.44), 0.25)
		piece(rig, "Sunburst", "cylinder", v(0.06, 1.35, 1.35), v(0, 3.05, 0.4), p.metal, { metal = true }, FACING)
		piece(
			rig,
			"SunburstGlow",
			"cylinder",
			v(0.06, 0.9, 0.9),
			v(0, 3.05, 0.36),
			p.accent,
			{ glow = true, transparency = 0.4, detail = true },
			FACING
		)
		piece(rig, "Arm", "block", v(0.25, 0.8, 0.25), v(0.62, 2.1, -0.4), p.cloth, nil, CFrame.Angles(1.08, 0, 0))
		local hand = v(0.62, 1.9, -0.75)
		piece(
			rig,
			"Chain",
			"block",
			v(0.05, 0.75, 0.05),
			v(0.62, 1.5, -0.78),
			p.metal,
			{ anim = SWING, pivot = hand, metal = true, detail = true }
		)
		piece(
			rig,
			"Censer",
			"egg",
			v(0.42, 0.5, 0.42),
			v(0.62, 1.05, -0.78),
			p.accent,
			{ anim = SWING, pivot = hand, glow = true }
		)
		rig.crown = v(0, 3.95, 0.1) * rig.r
		return { stride = 6, bob = 0.04, roll = 0.06, lean = 0.08, legSwing = 0, armSwing = 0 }
	end,

	-- a low, four-legged ram with a bone mask, brass horns and a furnace on its back that flares before it rushes
	Charger = function(rig)
		local p = rig.palette
		shadow(rig, 2.2)
		piece(
			rig,
			"Body",
			"egg",
			v(1.45, 1, 2),
			v(0, 0.95, 0.15),
			p.cloth,
			{ material = Enum.Material.Fabric, flash = true }
		)
		piece(
			rig,
			"Armor",
			"block",
			v(0.9, 0.15, 1.2),
			v(0, 1.36, 0.25),
			p.metalDark,
			{ metal = true },
			CFrame.Angles(0.08, 0, 0)
		)
		piece(
			rig,
			"Furnace",
			"block",
			v(0.6, 0.1, 0.85),
			v(0, 1.43, 0.25),
			p.accent,
			{ glow = true, heat = true },
			CFrame.Angles(0.08, 0, 0)
		)
		piece(
			rig,
			"Chimney",
			"cylinder",
			v(0.35, 0.2, 0.2),
			v(0, 1.55, 0.75),
			p.metal,
			{ metal = true, detail = true },
			UPRIGHT
		)
		piece(rig, "Skull", "egg", v(0.8, 0.7, 0.85), v(0, 1, -1.05), p.mask, { flash = true })
		-- ram horns: out and up from the skull, then curling forward
		for _, side in { -1, 1 } do
			local name = if side < 0 then "Left" else "Right"
			local root, bend, tip = v(0.28 * side, 1.25, -0.95), v(0.72 * side, 1.55, -0.85), v(0.82 * side, 1.3, -1.35)
			rod(rig, `Horn{name}`, root, bend, 0.24, p.metal, { metal = true })
			rod(rig, `HornTip{name}`, bend, tip, 0.16, p.metal, { metal = true })
		end
		piece(rig, "EyeLeft", "ball", v(0.17, 0.17, 0.17), v(-0.22, 1.1, -1.47), p.eye, { glow = true, heat = true })
		piece(rig, "EyeRight", "ball", v(0.17, 0.17, 0.17), v(0.22, 1.1, -1.47), p.eye, { glow = true, heat = true })
		-- legs in diagonal pairs, like a trot
		local legs = {
			{ "LegFrontLeft", -0.48, -0.55, LEG_LEFT },
			{ "LegFrontRight", 0.48, -0.55, LEG_RIGHT },
			{ "LegBackLeft", -0.48, 0.75, LEG_RIGHT },
			{ "LegBackRight", 0.48, 0.75, LEG_LEFT },
		}
		for _, leg in legs do
			local x, z = leg[2] :: number, leg[3] :: number
			piece(
				rig,
				leg[1] :: string,
				"block",
				v(0.32, 0.6, 0.32),
				v(x, 0.3, z),
				p.soot,
				{ anim = leg[4] :: number, pivot = v(x, 0.6, z) }
			)
		end
		if p.spikes then
			piece(rig, "SpineSpike", "wedge", v(0.15, 0.5, 0.6), v(0, 1.75, 0.6), p.metal, { metal = true })
		end
		rig.crown = v(0, 2.1, -0.6) * rig.r
		return { stride = 5, bob = 0.05, roll = 0.05, lean = 0.05, legSwing = 0.6, armSwing = 0 }
	end,

	-- a cracked, waddling brood urn with brass bands, glowing cracks and three wisps peeking out of its neck
	Splitter = function(rig)
		local p = rig.palette
		shadow(rig, 1.8)
		piece(rig, "Body", "egg", v(1.55, 1.45, 1.55), v(0, 0.95, 0), p.cloth, { flash = true })
		piece(
			rig,
			"Band",
			"cylinder",
			v(0.14, 1.5, 1.5),
			v(0, 1.15, 0),
			p.metal,
			{ metal = true, detail = true },
			UPRIGHT
		)
		piece(rig, "Neck", "cylinder", v(0.4, 0.85, 0.85), v(0, 1.75, 0), p.clothDark, nil, UPRIGHT)
		piece(rig, "Lip", "cylinder", v(0.1, 1, 1), v(0, 1.95, 0), p.metal, { metal = true, detail = true }, UPRIGHT)
		eye(rig, "CrackLeft", v(0.07, 0.65, 0.05), v(-0.28, 0.95, -0.74), 0.5)
		eye(rig, "CrackRight", v(0.07, 0.65, 0.05), v(0.22, 1.05, -0.74), -0.4)
		local wisps = { v(0, 2.15, 0), v(-0.28, 2.05, 0.12), v(0.28, 2.05, 0.12) }
		for index, position in wisps do
			local options: PieceOptions = { anim = FLOAT, glow = true, detail = index > 1 }
			piece(rig, `Wisp{index}`, "ball", v(0.32, 0.32, 0.32), position, p.eye, options)
		end
		for _, side in { -1, 1 } do
			local name = if side < 0 then "FootLeft" else "FootRight"
			local leg = if side < 0 then LEG_LEFT else LEG_RIGHT
			piece(
				rig,
				name,
				"egg",
				v(0.45, 0.28, 0.6),
				v(0.42 * side, 0.14, -0.12),
				p.soot,
				{ anim = leg, pivot = v(0.42 * side, 0.3, 0) }
			)
		end
		if p.spikes then
			piece(rig, "Spike", "wedge", v(0.15, 0.5, 0.4), v(0, 2.4, 0), p.metal, { metal = true })
		end
		rig.crown = v(0, 2.6, 0) * rig.r
		return { stride = 4, bob = 0.05, roll = 0.18, lean = 0.05, legSwing = 0.5, armSwing = 0 }
	end,

	-- a little hopping teal wisp with a flame tip and a shard of porcelain mask
	Splitling = function(rig)
		local p = rig.palette
		shadow(rig, 1.6)
		piece(rig, "Body", "egg", v(1.6, 1.45, 1.6), v(0, 0.85, 0), p.cloth, { flash = true })
		piece(
			rig,
			"Flame",
			"wedge",
			v(0.4, 0.75, 0.6),
			v(0, 1.75, 0.25),
			p.eye,
			{ glow = true, transparency = 0.25 },
			CFrame.Angles(-0.3, 0, 0)
		)
		piece(rig, "MaskShard", "cylinder", v(0.08, 0.7, 0.7), v(0, 0.95, -0.74), p.mask, { detail = true }, FACING)
		eye(rig, "Eye", v(0.3, 0.08, 0.05), v(0, 1, -0.8), 0)
		rig.crown = v(0, 2.3, 0) * rig.r
		return { stride = 3, bob = 0.15, roll = 0.1, lean = 0.3, legSwing = 0, armSwing = 0 }
	end,

	-- B6: a hunched little thief in an ochre coat and porcelain mask, a fat sack of glowing coins on its back, legs going
	Looter = function(rig)
		local p = rig.palette
		shadow(rig, 1.8)
		piece(rig, "Body", "egg", v(1.4, 1.35, 1.3), v(0, 0.95, 0), p.cloth, { flash = true })
		piece(rig, "Hood", "egg", v(1, 0.95, 1.05), v(0, 1.65, -0.2), p.clothDark, { flash = true })
		piece(rig, "Mask", "cylinder", v(0.08, 0.7, 0.7), v(0, 1.62, -0.68), p.mask, nil, TILTED * FACING)
		eye(rig, "EyeLeft", v(0.18, 0.1, 0.05), v(-0.16, 1.68, -0.74), 0)
		eye(rig, "EyeRight", v(0.18, 0.1, 0.05), v(0.16, 1.68, -0.74), 0)
		piece(
			rig,
			"Sack",
			"egg",
			v(1.35, 1.3, 1.15),
			v(0, 1.45, 0.75),
			p.metalDark,
			{ material = Enum.Material.Fabric, flash = true }
		)
		piece(
			rig,
			"SackTie",
			"cylinder",
			v(0.12, 0.5, 0.5),
			v(0, 2.1, 0.75),
			p.metal,
			{ metal = true, detail = true },
			UPRIGHT
		)
		piece(rig, "Coins", "ball", v(0.4, 0.4, 0.4), v(0, 2.3, 0.75), p.eye, { glow = true })
		for _, side in { -1, 1 } do
			local name = if side < 0 then "LegLeft" else "LegRight"
			local leg = if side < 0 then LEG_LEFT else LEG_RIGHT
			piece(
				rig,
				name,
				"block",
				v(0.3, 0.55, 0.3),
				v(0.35 * side, 0.28, 0),
				p.soot,
				{ anim = leg, pivot = v(0.35 * side, 0.55, 0) }
			)
		end
		rig.crown = v(0, 2.6, 0) * rig.r
		return { stride = 3.5, bob = 0.1, roll = 0.08, lean = 0.3, legSwing = 0.8, armSwing = 0 }
	end,

	-- B9: a pale veined egg half sunk in the floor, violet light shining through cracks
	BroodEgg = function(rig)
		local p = rig.palette
		shadow(rig, 1.9)
		piece(rig, "Shell", "egg", v(1.5, 1.9, 1.5), v(0, 0.85, 0), p.cloth, { flash = true })
		piece(rig, "Base", "cylinder", v(0.3, 1.6, 1.6), v(0, 0.12, 0), p.clothDark, { flash = true }, UPRIGHT)
		piece(
			rig,
			"Crack",
			"block",
			v(0.08, 0.9, 0.06),
			v(0.2, 1, -0.74),
			p.eye,
			{ glow = true },
			CFrame.Angles(0, 0, 0.4)
		)
		piece(rig, "CrackSide", "block", v(0.06, 0.7, 0.06), v(-0.7, 1.1, 0.1), p.eye, { glow = true, detail = true })
		piece(rig, "Spot", "ball", v(0.3, 0.3, 0.3), v(-0.3, 1.45, -0.55), p.clothDark, { detail = true })
		rig.crown = v(0, 2, 0) * rig.r
		return { stride = 5, bob = 0, roll = 0, lean = 0, legSwing = 0, armSwing = 0 }
	end,

	-- B6: a gnarled dead-dark tree with a dusky crown and three lantern fruits; it never moves
	Tree = function(rig)
		local p = rig.palette
		shadow(rig, 2)
		piece(rig, "Trunk", "cylinder", v(2.3, 0.6, 0.6), v(0, 1.15, 0), p.cloth, { flash = true }, UPRIGHT)
		rod(rig, "BranchLeft", v(0, 1.8, 0), v(-0.75, 2.55, 0.1), 0.22, p.cloth)
		rod(rig, "BranchRight", v(0, 1.6, 0), v(0.7, 2.4, -0.2), 0.2, p.cloth)
		rod(rig, "Root", v(0, 0.3, 0), v(0.6, 0.05, 0.35), 0.2, p.clothDark, { detail = true })
		piece(
			rig,
			"Crown",
			"egg",
			v(2, 1.3, 2),
			v(0, 2.85, 0),
			p.accent,
			{ material = Enum.Material.Grass, flash = true }
		)
		local fruits = { v(-0.65, 2.45, -0.55), v(0.7, 2.6, -0.3), v(0.1, 2.35, 0.75) }
		for index, position in fruits do
			piece(
				rig,
				`Fruit{index}`,
				"ball",
				v(0.32, 0.32, 0.32),
				position,
				p.eye,
				{ glow = true, detail = index > 2 }
			)
		end
		rig.crown = v(0, 3.6, 0) * rig.r
		return { stride = 5, bob = 0, roll = 0, lean = 0, legSwing = 0, armSwing = 0 }
	end,
	-- WP10: a hulking furnace beast on two short legs, walking on its knuckles
	LanternEater = function(rig)
		local p = rig.palette
		shadow(rig, 2.3)
		piece(
			rig,
			"Body",
			"egg",
			v(2, 1.6, 1.7),
			v(0, 1.45, 0.1),
			p.cloth,
			{ material = Enum.Material.Metal, flash = true }
		)
		piece(rig, "Grate", "cylinder", v(0.1, 1.05, 1.05), v(0, 1.35, -0.78), p.metal, { metal = true }, FACING)
		piece(
			rig,
			"Fire",
			"cylinder",
			v(0.1, 0.8, 0.8),
			v(0, 1.35, -0.8),
			p.accent,
			{ glow = true, heat = true },
			FACING
		)
		for index, x in { -0.18, 0.18 } do -- two bars keep it within the elite part budget
			piece(
				rig,
				`GrateBar{index}`,
				"block",
				v(0.07, 0.9, 0.06),
				v(x, 1.35, -0.86),
				p.metalDark,
				{ metal = true, detail = true }
			)
		end
		piece(rig, "Head", "egg", v(1.1, 0.8, 1), v(0, 2.25, -0.45), p.soot, { flash = true })
		piece(rig, "Jaw", "egg", v(1.15, 0.45, 0.6), v(0, 1.95, -0.85), p.mask)
		piece(rig, "Maw", "block", v(0.8, 0.08, 0.1), v(0, 1.97, -1.13), p.accent, { glow = true })
		eye(rig, "EyeLeft", v(0.24, 0.09, 0.06), v(-0.25, 2.38, -0.92), -0.3)
		eye(rig, "EyeRight", v(0.24, 0.09, 0.06), v(0.25, 2.38, -0.92), 0.3)
		for _, side in { -1, 1 } do
			local name = if side < 0 then "Left" else "Right"
			rod(
				rig,
				`Horn{name}`,
				v(0.4 * side, 2.55, -0.4),
				v(0.85 * side, 3.05, -0.2),
				0.16,
				p.metal,
				{ metal = true }
			)
			local arm = if side < 0 then ARM_LEFT else ARM_RIGHT
			local leg = if side < 0 then LEG_LEFT else LEG_RIGHT
			local shoulder = v(1.2 * side, 1.95, -0.1)
			piece(
				rig,
				`Arm{name}`,
				"block",
				v(0.5, 1.4, 0.55),
				v(1.3 * side, 1.25, -0.25),
				p.cloth,
				{ anim = arm, pivot = shoulder, metal = true }
			)
			piece(
				rig,
				`Fist{name}`,
				"block",
				v(0.7, 0.55, 0.7),
				v(1.35 * side, 0.35, -0.35),
				p.metalDark,
				{ anim = arm, pivot = shoulder, metal = true }
			)
			piece(
				rig,
				`Leg{name}`,
				"block",
				v(0.6, 0.65, 0.6),
				v(0.5 * side, 0.33, 0.25),
				p.soot,
				{ anim = leg, pivot = v(0.5 * side, 0.65, 0.25) }
			)
		end
		-- lanterns caged on its back
		for index, x in { -0.55, 0, 0.55 } do
			local y = if index == 2 then 2.45 else 2.2
			piece(rig, `Cage{index}`, "block", v(0.42, 0.55, 0.42), v(x, y, 0.75), p.metalDark, { metal = true })
			piece(
				rig,
				`Lantern{index}`,
				"ball",
				v(0.3, 0.3, 0.3),
				v(x, y, 0.75),
				p.accent,
				{ glow = true, heat = true, detail = index ~= 2 }
			)
		end
		rig.crown = v(0, 3.2, -0.2) * rig.r
		return { stride = 9, bob = 0.05, roll = 0.07, lean = 0.12, legSwing = 0.45, armSwing = 0.5 }
	end,
	-- WP10: a tall veiled oracle hovering over the floor, one great eye, a spinning brass halo with candle flames
	HollowSeer = function(rig)
		local p = rig.palette
		shadow(rig, 1.8)
		piece(
			rig,
			"Body",
			"cylinder",
			v(2.2, 1.3, 1.3),
			v(0, 1.5, 0),
			p.cloth,
			{ material = Enum.Material.Fabric, flash = true },
			UPRIGHT
		)
		piece(rig, "Veil", "egg", v(1.7, 0.7, 1.7), v(0, 0.55, 0), p.clothDark, nil)
		piece(
			rig,
			"Hem",
			"cylinder",
			v(0.1, 1.72, 1.72),
			v(0, 0.55, 0),
			p.metal,
			{ metal = true, detail = true },
			UPRIGHT
		)
		piece(rig, "Hood", "egg", v(1.1, 1.2, 1.1), v(0, 2.85, 0), p.clothDark, { flash = true })
		piece(rig, "Mask", "egg", v(0.8, 0.95, 0.25), v(0, 2.8, -0.45), p.mask, nil)
		piece(rig, "Eye", "cylinder", v(0.08, 0.45, 0.45), v(0, 2.88, -0.6), p.eye, { glow = true }, TILTED * FACING)
		piece(rig, "Tear", "block", v(0.06, 0.4, 0.04), v(0, 2.45, -0.58), p.accent, { glow = true, detail = true })
		local halo = v(0, 3.25, 0.35)
		piece(
			rig,
			"Halo",
			"cylinder",
			v(0.08, 2.1, 2.1),
			halo,
			p.metal,
			{ metal = true, anim = SPIN, pivot = halo, transparency = 0.1 },
			UPRIGHT
		)
		for index = 0, 3 do
			local angle = index * math.pi / 2
			piece(
				rig,
				`Flame{index}`,
				"ball",
				v(0.22, 0.32, 0.22),
				halo + v(math.cos(angle) * 1.05, 0.15, math.sin(angle) * 1.05),
				p.accent,
				{ glow = true, anim = SPIN, pivot = halo, detail = index % 2 == 1 }
			)
		end
		for _, side in { -1, 1 } do
			local name = if side < 0 then "Left" else "Right"
			piece(
				rig,
				`Sleeve{name}`,
				"block",
				v(0.35, 1.1, 0.4),
				v(0.8 * side, 1.85, -0.3),
				p.cloth,
				nil,
				CFrame.Angles(0.5, 0, -0.35 * side)
			)
			piece(rig, `Hand{name}`, "ball", v(0.3, 0.3, 0.3), v(0.95 * side, 1.35, -0.6), p.mask, { anim = FLOAT })
		end
		rig.crown = v(0, 3.9, 0) * rig.r
		return { stride = 8, bob = 0.03, roll = 0.03, lean = 0.05, legSwing = 0, armSwing = 0 }
	end,
	-- WP10 part 2, the champions. A brass-plated ram on four legs with curled horns and a glowing forehead plate
	BrassRam = function(rig)
		local p = rig.palette
		shadow(rig, 2.1)
		piece(rig, "Body", "egg", v(1.5, 1.25, 2), v(0, 1.25, 0.1), p.cloth, { flash = true })
		piece(rig, "Plate", "block", v(1.2, 0.15, 1.5), v(0, 1.88, 0.1), p.metal, { metal = true })
		piece(rig, "Head", "egg", v(0.85, 0.85, 1), v(0, 1.45, -1.05), p.soot, { flash = true })
		piece(rig, "Brow", "block", v(0.7, 0.35, 0.12), v(0, 1.65, -1.52), p.accent, { glow = true }, TILTED)
		eye(rig, "EyeLeft", v(0.16, 0.08, 0.05), v(-0.22, 1.42, -1.53), -0.25)
		eye(rig, "EyeRight", v(0.16, 0.08, 0.05), v(0.22, 1.42, -1.53), 0.25)
		for _, side in { -1, 1 } do
			local name = if side < 0 then "Left" else "Right"
			rod(
				rig,
				`Horn{name}`,
				v(0.35 * side, 1.8, -1.1),
				v(0.9 * side, 2.05, -0.75),
				0.22,
				p.metal,
				{ metal = true }
			)
			rod(
				rig,
				`HornTip{name}`,
				v(0.9 * side, 2.05, -0.75),
				v(0.85 * side, 1.5, -1.25),
				0.16,
				p.metalDark,
				{ metal = true, detail = true }
			)
			for index, z in { -0.55, 0.7 } do
				local anim = if (index == 1) == (side < 0) then LEG_LEFT else LEG_RIGHT
				piece(
					rig,
					`Leg{name}{index}`,
					"block",
					v(0.35, 0.8, 0.35),
					v(0.5 * side, 0.4, z),
					p.soot,
					{ anim = anim, pivot = v(0.5 * side, 0.8, z) }
				)
			end
		end
		rig.crown = v(0, 2.3, 0) * rig.r
		return { stride = 7, bob = 0.06, roll = 0.04, lean = 0.15, legSwing = 0.6, armSwing = 0 }
	end,
	-- a hooded butcher in a leather apron, porcelain mask, a huge glowing cleaver in one hand
	Flayer = function(rig)
		local p = rig.palette
		shadow(rig, 2)
		piece(rig, "Body", "egg", v(1.8, 1.9, 1.5), v(0, 1.35, 0.05), p.cloth, { flash = true })
		piece(
			rig,
			"Apron",
			"block",
			v(1.2, 1.4, 0.1),
			v(0, 1.1, -0.72),
			p.clothDark,
			{ material = Enum.Material.Fabric }
		)
		piece(rig, "Hood", "egg", v(0.95, 1, 0.95), v(0, 2.5, -0.1), p.soot, { flash = true })
		piece(rig, "Mask", "egg", v(0.65, 0.75, 0.2), v(0, 2.45, -0.5), p.mask, nil)
		eye(rig, "EyeLeft", v(0.15, 0.06, 0.04), v(-0.15, 2.55, -0.6), -0.2)
		eye(rig, "EyeRight", v(0.15, 0.06, 0.04), v(0.15, 2.55, -0.6), 0.2)
		local shoulderRight = v(1, 1.95, 0)
		piece(
			rig,
			"ArmRight",
			"block",
			v(0.45, 1.2, 0.45),
			v(1.1, 1.35, -0.1),
			p.cloth,
			{ anim = ARM_RIGHT, pivot = shoulderRight }
		)
		piece(
			rig,
			"Cleaver",
			"block",
			v(0.1, 1.1, 1.4),
			v(1.15, 0.9, -0.75),
			p.accent,
			{ anim = ARM_RIGHT, pivot = shoulderRight, glow = true }
		)
		piece(
			rig,
			"Handle",
			"block",
			v(0.14, 0.14, 0.5),
			v(1.15, 0.9, -0.05),
			p.metalDark,
			{ anim = ARM_RIGHT, pivot = shoulderRight, metal = true, detail = true }
		)
		local shoulderLeft = v(-1, 1.95, 0)
		piece(
			rig,
			"ArmLeft",
			"block",
			v(0.45, 1.2, 0.45),
			v(-1.1, 1.35, -0.1),
			p.cloth,
			{ anim = ARM_LEFT, pivot = shoulderLeft }
		)
		piece(
			rig,
			"Hook",
			"block",
			v(0.12, 0.45, 0.12),
			v(-1.1, 0.6, -0.15),
			p.metal,
			{ anim = ARM_LEFT, pivot = shoulderLeft, metal = true }
		)
		for _, side in { -1, 1 } do
			local name = if side < 0 then "Left" else "Right"
			local leg = if side < 0 then LEG_LEFT else LEG_RIGHT
			piece(
				rig,
				`Leg{name}`,
				"block",
				v(0.5, 0.6, 0.5),
				v(0.45 * side, 0.3, 0.1),
				p.soot,
				{ anim = leg, pivot = v(0.45 * side, 0.6, 0.1) }
			)
		end
		rig.crown = v(0, 3.15, 0) * rig.r
		return { stride = 8, bob = 0.05, roll = 0.08, lean = 0.1, legSwing = 0.45, armSwing = 0.6 }
	end,
	-- a tall abbot in a hooded robe with two burning eyes, a crooked staff and an orb floating over his hand
	Abbot = function(rig)
		local p = rig.palette
		shadow(rig, 1.8)
		piece(
			rig,
			"Body",
			"cylinder",
			v(2.2, 1.3, 1.3),
			v(0, 1.1, 0),
			p.cloth,
			{ material = Enum.Material.Fabric, flash = true },
			UPRIGHT
		)
		piece(rig, "Mantle", "egg", v(1.6, 0.6, 1.4), v(0, 2.2, 0), p.clothDark, nil)
		piece(
			rig,
			"Sash",
			"cylinder",
			v(0.12, 1.34, 1.34),
			v(0, 1.4, 0),
			p.metal,
			{ metal = true, detail = true },
			UPRIGHT
		)
		piece(rig, "Hood", "egg", v(1, 1.15, 1), v(0, 2.75, 0), p.clothDark, { flash = true })
		piece(rig, "Face", "egg", v(0.6, 0.7, 0.2), v(0, 2.7, -0.42), p.soot, nil)
		eye(rig, "EyeLeft", v(0.13, 0.13, 0.05), v(-0.13, 2.78, -0.52), 0)
		eye(rig, "EyeRight", v(0.13, 0.13, 0.05), v(0.13, 2.78, -0.52), 0)
		rod(rig, "Staff", v(0.85, 0.1, -0.4), v(0.85, 3.4, -0.4), 0.12, p.metalDark, { metal = true })
		piece(rig, "StaffHead", "ball", v(0.35, 0.35, 0.35), v(0.85, 3.5, -0.4), p.accent, { glow = true })
		piece(rig, "Orb", "ball", v(0.4, 0.4, 0.4), v(-0.85, 1.9, -0.6), p.eye, { glow = true, anim = FLOAT })
		piece(rig, "HandLeft", "ball", v(0.28, 0.28, 0.28), v(-0.75, 1.55, -0.5), p.mask, nil)
		rig.crown = v(0, 3.6, 0) * rig.r
		return { stride = 7, bob = 0.03, roll = 0.03, lean = 0.08, legSwing = 0, armSwing = 0 }
	end,
	-- a long, low swamp lizard with brass-capped scales, a toothy snout and a heavy tail
	MireJaw = function(rig)
		local p = rig.palette
		shadow(rig, 2.3)
		piece(rig, "Body", "egg", v(1.4, 0.8, 2.4), v(0, 0.75, 0.2), p.cloth, { flash = true })
		piece(rig, "Snout", "block", v(0.8, 0.45, 1.2), v(0, 0.75, -1.4), p.clothDark, { flash = true })
		piece(rig, "Jaw", "block", v(0.75, 0.2, 1.1), v(0, 0.45, -1.35), p.mask, nil)
		for index = 1, 3 do
			piece(
				rig,
				`Teeth{index}`,
				"block",
				v(0.7, 0.08, 0.08),
				v(0, 0.58, -0.95 - index * 0.25),
				p.mask,
				{ detail = index ~= 3 }
			)
		end
		eye(rig, "EyeLeft", v(0.16, 0.1, 0.12), v(-0.3, 1.1, -0.9), 0)
		eye(rig, "EyeRight", v(0.16, 0.1, 0.12), v(0.3, 1.1, -0.9), 0)
		piece(rig, "Ridge", "block", v(0.3, 0.2, 1.8), v(0, 1.15, 0.2), p.metal, { metal = true })
		piece(
			rig,
			"Tail",
			"wedge",
			v(0.6, 0.45, 1.6),
			v(0, 0.5, 1.95),
			p.cloth,
			{ anim = SWING, pivot = v(0, 0.6, 1.2) }
		)
		for _, side in { -1, 1 } do
			local name = if side < 0 then "Left" else "Right"
			for index, z in { -0.5, 0.8 } do
				local anim = if (index == 1) == (side < 0) then LEG_LEFT else LEG_RIGHT
				piece(
					rig,
					`Leg{name}{index}`,
					"block",
					v(0.35, 0.4, 0.4),
					v(0.75 * side, 0.2, z),
					p.soot,
					{ anim = anim, pivot = v(0.75 * side, 0.4, z) }
				)
			end
		end
		rig.crown = v(0, 1.6, 0) * rig.r
		return { stride = 6, bob = 0.03, roll = 0.1, lean = 0.05, legSwing = 0.7, armSwing = 0 }
	end,
	-- a walking obelisk of cracked dark stone, glowing runes and stones orbiting its top
	Monolith = function(rig)
		local p = rig.palette
		shadow(rig, 2)
		piece(
			rig,
			"Body",
			"block",
			v(1.3, 2.6, 1.3),
			v(0, 1.6, 0),
			p.cloth,
			{ flash = true, material = Enum.Material.Slate }
		)
		piece(
			rig,
			"Cap",
			"wedge",
			v(1.35, 0.6, 1.35),
			v(0, 3.2, 0),
			p.clothDark,
			{ flash = true, material = Enum.Material.Slate }
		)
		piece(rig, "Base", "block", v(1.6, 0.35, 1.6), v(0, 0.2, 0), p.metalDark, { metal = true })
		for index, y in { 1.1, 1.8, 2.5 } do
			piece(
				rig,
				`Rune{index}`,
				"block",
				v(0.5, 0.12, 0.05),
				v(0, y, -0.67),
				p.accent,
				{ glow = true, detail = index == 2 }
			)
		end
		eye(rig, "Eye", v(0.4, 0.14, 0.05), v(0, 2.85, -0.67), 0)
		local top = v(0, 2.9, 0)
		for index = 0, 2 do
			local angle = index * 2 * math.pi / 3
			piece(
				rig,
				`Stone{index}`,
				"block",
				v(0.35, 0.35, 0.35),
				top + v(math.cos(angle) * 1.25, 0, math.sin(angle) * 1.25),
				p.clothDark,
				{ anim = SPIN, pivot = top, material = Enum.Material.Slate },
				CFrame.Angles(0.6, angle, 0.4)
			)
		end
		rig.crown = v(0, 3.8, 0) * rig.r
		return { stride = 10, bob = 0.04, roll = 0.06, lean = 0.03, legSwing = 0, armSwing = 0 }
	end,
	-- a thin, stalking wraith with a narrow head, two great brass sickles for arms and bent legs
	SickleWraith = function(rig)
		local p = rig.palette
		shadow(rig, 1.8)
		piece(rig, "Body", "egg", v(0.9, 1.7, 0.9), v(0, 1.65, 0.1), p.cloth, { flash = true })
		piece(rig, "Abdomen", "egg", v(0.9, 0.8, 1.4), v(0, 1.1, 0.8), p.clothDark, { flash = true })
		piece(rig, "Head", "egg", v(0.75, 0.5, 0.6), v(0, 2.6, -0.2), p.mask, nil)
		eye(rig, "EyeLeft", v(0.22, 0.2, 0.12), v(-0.3, 2.65, -0.35), -0.3)
		eye(rig, "EyeRight", v(0.22, 0.2, 0.12), v(0.3, 2.65, -0.35), 0.3)
		for _, side in { -1, 1 } do
			local name = if side < 0 then "Left" else "Right"
			local arm = if side < 0 then ARM_LEFT else ARM_RIGHT
			local leg = if side < 0 then LEG_LEFT else LEG_RIGHT
			local shoulder = v(0.45 * side, 2.2, -0.2)
			rod(rig, `Arm{name}`, shoulder, v(0.7 * side, 2.4, -1), 0.16, p.soot, { anim = arm, pivot = shoulder })
			rod(
				rig,
				`Sickle{name}`,
				v(0.7 * side, 2.4, -1),
				v(0.6 * side, 1.2, -1.3),
				0.14,
				p.metal,
				{ anim = arm, pivot = shoulder, metal = true }
			)
			rod(
				rig,
				`Leg{name}`,
				v(0.35 * side, 1.2, 0.2),
				v(0.8 * side, 0, 0.3),
				0.14,
				p.soot,
				{ anim = leg, pivot = v(0.35 * side, 1.2, 0.2) }
			)
		end
		rig.crown = v(0, 3.1, 0) * rig.r
		return { stride = 9, bob = 0.04, roll = 0.04, lean = 0.2, legSwing = 0.5, armSwing = 0.3 }
	end,
	-- a bloated mother with a glowing egg-sac abdomen, a small masked head and short clawed legs
	BroodMatron = function(rig)
		local p = rig.palette
		shadow(rig, 2.2)
		piece(rig, "Body", "egg", v(1.9, 1.6, 2), v(0, 1.2, 0.35), p.cloth, { flash = true })
		piece(rig, "Thorax", "egg", v(1.1, 1, 1), v(0, 1.45, -0.75), p.clothDark, { flash = true })
		piece(rig, "Head", "egg", v(0.7, 0.6, 0.6), v(0, 1.85, -1.25), p.mask, nil)
		eye(rig, "EyeLeft", v(0.14, 0.08, 0.05), v(-0.15, 1.9, -1.55), -0.2)
		eye(rig, "EyeRight", v(0.14, 0.08, 0.05), v(0.15, 1.9, -1.55), 0.2)
		for index, offset in { v(-0.55, 1.75, 0.3), v(0.55, 1.7, 0.5), v(0, 1.95, 0.75), v(0, 1.3, 1.25) } do
			piece(rig, `Sac{index}`, "ball", v(0.45, 0.45, 0.45), offset, p.accent, { glow = true, detail = index > 2 })
		end
		piece(rig, "Collar", "cylinder", v(0.1, 1.15, 1.15), v(0, 1.45, -0.55), p.metal, { metal = true }, FACING)
		for _, side in { -1, 1 } do
			local name = if side < 0 then "Left" else "Right"
			for index, z in { -0.7, 0.4 } do
				local anim = if (index == 1) == (side < 0) then LEG_LEFT else LEG_RIGHT
				rod(
					rig,
					`Leg{name}{index}`,
					v(0.6 * side, 0.9, z),
					v(1.1 * side, 0, z - 0.1),
					0.16,
					p.soot,
					{ anim = anim, pivot = v(0.6 * side, 0.9, z) }
				)
			end
		end
		rig.crown = v(0, 2.4, 0) * rig.r
		return { stride = 7, bob = 0.05, roll = 0.06, lean = 0.05, legSwing = 0.5, armSwing = 0 }
	end,
	-- a crouching stone gargoyle with spread wings, horns and a glowing gold mouth
	StoneSeraph = function(rig)
		local p = rig.palette
		shadow(rig, 2)
		piece(
			rig,
			"Body",
			"egg",
			v(1.4, 1.5, 1.3),
			v(0, 1.2, 0.1),
			p.cloth,
			{ flash = true, material = Enum.Material.Slate }
		)
		piece(
			rig,
			"Head",
			"egg",
			v(0.9, 0.8, 0.85),
			v(0, 2.1, -0.45),
			p.cloth,
			{ flash = true, material = Enum.Material.Slate }
		)
		piece(rig, "Mouth", "block", v(0.45, 0.1, 0.08), v(0, 1.92, -0.85), p.accent, { glow = true })
		eye(rig, "EyeLeft", v(0.15, 0.08, 0.05), v(-0.2, 2.2, -0.85), -0.25)
		eye(rig, "EyeRight", v(0.15, 0.08, 0.05), v(0.2, 2.2, -0.85), 0.25)
		for _, side in { -1, 1 } do
			local name = if side < 0 then "Left" else "Right"
			local arm = if side < 0 then ARM_LEFT else ARM_RIGHT
			local leg = if side < 0 then LEG_LEFT else LEG_RIGHT
			rod(
				rig,
				`Horn{name}`,
				v(0.3 * side, 2.4, -0.4),
				v(0.55 * side, 2.85, -0.1),
				0.14,
				p.metal,
				{ metal = true }
			)
			local root = v(0.55 * side, 1.7, 0.5)
			piece(
				rig,
				`Wing{name}`,
				"wedge",
				v(0.12, 1.4, 1.6),
				v(1.2 * side, 2.1, 0.7),
				p.clothDark,
				{ anim = arm, pivot = root, material = Enum.Material.Slate },
				CFrame.Angles(0, 0, -0.5 * side)
			)
			piece(
				rig,
				`Leg{name}`,
				"block",
				v(0.45, 0.55, 0.55),
				v(0.45 * side, 0.28, 0.15),
				p.soot,
				{ anim = leg, pivot = v(0.45 * side, 0.55, 0.15) }
			)
		end
		piece(
			rig,
			"Tail",
			"block",
			v(0.2, 0.2, 1.1),
			v(0, 0.55, 0.95),
			p.clothDark,
			{ anim = SWING, pivot = v(0, 0.7, 0.5), detail = true }
		)
		rig.crown = v(0, 3, 0) * rig.r
		return { stride = 8, bob = 0.06, roll = 0.05, lean = 0.12, legSwing = 0.4, armSwing = 0.35 }
	end,
}

-- Magenta cube for a typeId the client does not know (should never happen; shows up clearly in tests).
local function buildUnknown(rig: Rig): Gait
	piece(rig, "Body", "block", v(2, 2, 2), v(0, 1, 0), UNKNOWN_COLOR, { flash = true })
	return { stride = 5, bob = 0, roll = 0, lean = 0, legSwing = 0, armSwing = 0 }
end

-- A flat ring or disc on the floor around the enemy, hidden until it winds up or pulses (B9: a Reaper's cut, a
-- Herald's or Mender's ring). `radius` in studs, not scaled with the model.
local function addDisc(rig: Rig, name: string, radius: number, color: Color3): BasePart
	local disc =
		newPiece(rig, name, "cylinder", Vector3.new(RING_THICKNESS, 2 * radius, 2 * radius), color, Enum.Material.Neon)
	disc.Transparency = 1
	attach(rig, disc, GROUND, CFrame.new(0, 0.06, 0) * UPRIGHT)
	return disc
end

-- Red strip on the floor in front of a charger, as long as its rush (hidden until it winds up).
local function addTelegraph(rig: Rig, length: number): BasePart
	local r = rig.r
	local strip =
		newPiece(rig, "RushPath", "block", Vector3.new(1.6 * r, 0.12, length), TELEGRAPH_COLOR, Enum.Material.Neon)
	strip.Transparency = 1
	attach(rig, strip, GROUND, CFrame.new(0, 0.08, -(r + length / 2)))
	return strip
end

local function paletteFor(enemy: any): Palette
	local base = PALETTES[enemy.id] or PALETTES[EnemyKinds.lookOf(enemy)] or PALETTES.Shadeling
	if not enemy.elite then
		return base
	end
	local elite = table.clone(base)
	elite.cloth = ELITE_CLOTH
	elite.clothDark = ELITE_CLOTH_DARK
	elite.metal = ELITE_GOLD
	elite.metalDark = ELITE_GOLD_DARK
	elite.eye = ELITE_EYE_COLOR
	return elite
end

type EliteParts = {
	hpBar: Frame,
	affixLabel: TextLabel,
	glow: PointLight,
	trail: Trail,
	affixParts: { [number]: { BasePart } },
}

-- A spinning sunburst crown, glow, an affix name, an HP bar and the affix looks on top of a gilded model.
local function makeElite(rig: Rig): EliteParts
	local r = rig.r
	local crown = (rig.crown or Vector3.new(0, rig.top + 0.2 * r, 0)) / r
	for index = 0, 2 do
		piece(
			rig,
			`CrownRay{index}`,
			"block",
			v(1.3, 0.06, 0.12),
			crown,
			ELITE_GOLD,
			{ anim = SPIN, pivot = crown, glow = true, transparency = 0.15 },
			CFrame.Angles(0, index * math.pi / 3, 0)
		)
	end
	-- Summoning: two wisps circling the body
	local summonColor = AFFIX_COLORS.Summoner
	local summoners = {}
	for index = 0, 1 do
		local angle = index * math.pi
		local wisp = piece(
			rig,
			`SummonWisp{index}`,
			"ball",
			v(0.35, 0.35, 0.35),
			v(math.cos(angle) * 1.3, crown.Y * 0.55, math.sin(angle) * 1.3),
			summonColor,
			{ anim = SPIN, pivot = v(0, crown.Y * 0.55, 0), glow = true, transparency = 1 }
		)
		table.insert(summoners, wisp)
	end

	local body = rig.flash[1] or rig.parts[1]
	local light = Instance.new("PointLight")
	light.Color = ELITE_GLOW_COLOR
	light.Brightness = ELITE_GLOW_BRIGHTNESS
	light.Range = ELITE_GLOW_RANGE
	light.Parent = body

	-- Swift: a trail behind the body
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, body.Size.Y * 0.4, 0)
	top.Parent = body
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -body.Size.Y * 0.4, 0)
	bottom.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(AFFIX_COLORS.Swift)
	trail.LightEmission = 1
	trail.Lifetime = TRAIL_SECONDS
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.Enabled = false
	trail.Parent = body

	local gui = Instance.new("BillboardGui")
	gui.Name = "HpBar"
	gui.Size = UDim2.fromOffset(HP_BAR_WIDTH * 2, AFFIX_TEXT_SIZE + HP_BAR_HEIGHT_PIXELS + 2)
	gui.StudsOffsetWorldSpace =
		Vector3.new(0, rig.top - rig.offsets[table.find(rig.parts, body) or 1].Position.Y + HP_BAR_HEIGHT, 0)
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

	local affixParts: { [number]: { BasePart } } = {}
	for index, info in Config.Enemies.elite.affixes do
		if info.id == "Summoner" then
			affixParts[index] = summoners
		end
	end
	return { hpBar = fill, affixLabel = label, glow = light, trail = trail, affixParts = affixParts }
end

local function colorsOf(parts: { BasePart }): { Color3 }
	local colors = {}
	for index, part in parts do
		colors[index] = part.Color
	end
	return colors
end

function Models.build(typeId: number): Visual
	local enemy = EnemyKinds.byTypeId(typeId)
	local model = Instance.new("Model")
	model.Name = if enemy then (if enemy.elite then `Elite{enemy.id}` else enemy.id) else `Unknown{typeId}`
	local r = if enemy then enemy.radius else 1.5
	local palette = if enemy then paletteFor(enemy) else PALETTES.Shadeling
	local rig = newRig(model, r, palette)
	local look = enemy and EnemyKinds.lookOf(enemy)
	local builder = look and BUILDERS[look]
	local gait = if builder then builder(rig) else buildUnknown(rig)
	local telegraph: BasePart? = nil
	if enemy and enemy.charge then
		telegraph = addTelegraph(rig, enemy.charge.maxDistance)
	elseif enemy and enemy.slash then
		telegraph = addDisc(rig, "CutArea", enemy.slash.radius + Config.Simulation.playerRadius, TELEGRAPH_COLOR)
	elseif enemy and enemy.pulse then
		local color = if enemy.pulse.heal then HEAL_RING_COLOR else BUFF_RING_COLOR
		telegraph = addDisc(rig, "PulseRing", enemy.pulse.radius, color)
	end
	local elite = if enemy and enemy.elite then makeElite(rig) else nil
	local body = rig.flash[1] or rig.parts[1]
	if enemy and enemy.boss then
		local light = Instance.new("PointLight")
		light.Color = BOSS_GLOW_COLOR
		light.Brightness = BOSS_GLOW_BRIGHTNESS
		light.Range = BOSS_GLOW_RANGE
		light.Parent = body
	end
	local hidden = {}
	for index, part in rig.parts do
		hidden[index] = part.Transparency >= 1
	end
	return {
		model = model,
		parts = rig.parts,
		anims = rig.anims,
		pivots = rig.pivots,
		offsets = rig.offsets,
		hidden = hidden,
		details = rig.details,
		lowDetail = false,
		gait = gait,
		radius = r,
		speed = if enemy then enemy.speed else 10,
		body = body,
		bodyColor = body.Color,
		glowColor = palette.eye,
		flashParts = rig.flash,
		flashColors = colorsOf(rig.flash),
		heatParts = rig.heat,
		heatColors = colorsOf(rig.heat),
		metalParts = rig.metal,
		metalColors = colorsOf(rig.metal),
		affixParts = if elite then elite.affixParts else {},
		trail = elite and elite.trail,
		hpBar = elite and elite.hpBar,
		affixLabel = elite and elite.affixLabel,
		glow = elite and elite.glow,
		telegraph = telegraph,
		windupTint = enemy ~= nil and enemy.pulse == nil,
		mode = 0,
		affix = 0,
		flashing = false,
		burning = false,
		slowed = false,
		buffed = false,
	}
end

-- Looks ------------------------------------------------------------------------------------------------------------

local function isCharging(mode: number): boolean
	return mode == Models.MODE_WINDUP or mode == Models.MODE_RUSH
end

-- Marks a part of `visual` as invisible (not posed) or visible again; it is placed again on the next pose.
local function setHidden(visual: Visual, part: BasePart, hidden: boolean)
	local index = table.find(visual.parts, part)
	if index then
		visual.hidden[index] = hidden
	end
end

-- Colors of the parts that react to hits and to a charger's mode.
local function paint(visual: Visual)
	local charging = visual.windupTint and isCharging(visual.mode)
	local tint = if visual.burning
		then BURN_COLOR
		elseif visual.slowed then FROST_COLOR
		elseif visual.buffed then BUFF_COLOR
		else nil
	for index, part in visual.flashParts do
		local own = visual.flashColors[index]
		part.Color = if visual.flashing
			then FLASH_COLOR
			elseif charging and part == visual.body then RUSH_COLOR
			elseif tint then own:Lerp(tint, STATUS_TINT)
			else own
	end
	for index, part in visual.heatParts do
		part.Color = if charging then HOT_COLOR elseif visual.burning then BURN_COLOR else visual.heatColors[index]
	end
end

-- White flash on hits (on = true) or back to its own colors.
function Models.setFlash(visual: Visual, on: boolean)
	if visual.flashing == on then
		return
	end
	visual.flashing = on
	paint(visual)
end

-- Burning (ember-red), slowed (frost-blue) and since B9 buffed (gold) looks; burning wins, then slowed (B5).
function Models.setStatus(visual: Visual, burning: boolean, slowed: boolean, buffed: boolean?)
	local isBuffed = buffed == true
	if visual.burning == burning and visual.slowed == slowed and visual.buffed == isBuffed then
		return
	end
	visual.burning, visual.slowed, visual.buffed = burning, slowed, isBuffed
	paint(visual)
end

-- Shows a charger's mode (0 walk, 1 wind-up, 2 rush, 3 recover): red body and white-hot furnace and eyes from the
-- wind-up through the rush, the rush path on the floor only during the wind-up.
function Models.setMode(visual: Visual, mode: number)
	if visual.mode == mode then
		return
	end
	visual.mode = mode
	paint(visual)
	local telegraph = visual.telegraph
	if telegraph then
		local shown = mode == Models.MODE_WINDUP
		telegraph.Transparency = if shown then TELEGRAPH_TRANSPARENCY else 1
		setHidden(visual, telegraph, not shown)
	end
end

-- Shows an elite's affix (0 = none, else index into Config.Enemies.elite.affixes): a colored name and glow, and its
-- look (Swift trail, Armored steel, Summoning wisps).
function Models.setAffix(visual: Visual, affix: number)
	local label, glow = visual.affixLabel, visual.glow
	if visual.affix == affix or not (label and glow) then
		return
	end
	visual.affix = affix
	local info = Config.Enemies.elite.affixes[affix]
	local id = if info then info.id else nil
	local color = if id then AFFIX_COLORS[id] or ELITE_GLOW_COLOR else ELITE_GLOW_COLOR
	label.Visible = info ~= nil
	label.Text = if info then string.upper(info.displayName) else ""
	label.TextColor3 = color
	glow.Color = color
	local trail = visual.trail
	if trail then
		trail.Enabled = id == "Swift"
		trail:Clear()
	end
	for index, part in visual.metalParts do
		part.Color = if id == "Armored" then STEEL else visual.metalColors[index]
	end
	for index, parts in visual.affixParts do
		for _, part in parts do
			part.Transparency = if index == affix then 0 else 1
			setHidden(visual, part, index ~= affix)
		end
	end
end

-- Low detail (on = true) hides the small trims and stops moving them; off brings them back.
function Models.setDetail(visual: Visual, on: boolean)
	if visual.lowDetail == on then
		return
	end
	visual.lowDetail = on
	for index, part in visual.parts do
		if visual.details[index] then
			part.LocalTransparencyModifier = if on then 1 else 0
		end
	end
end

-- Puts a pooled model back to its plain look.
function Models.reset(visual: Visual)
	visual.flashing = false
	visual.burning, visual.slowed, visual.buffed = false, false, false
	Models.setMode(visual, 0)
	paint(visual)
	local trail = visual.trail
	if trail then
		trail:Clear()
	end
end

-- Pose -------------------------------------------------------------------------------------------------------------

-- Queues every visible part of `visual` for this frame, standing at `base` (floor point, facing its walking direction).
-- `phase` counts step cycles in radians (it advances with the distance walked), `move` is 0 (standing) to 1 (full
-- speed), `seed` spreads idle motions between enemies. Returns the new list length.
function Models.pose(
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
	local bob = gait.bob * r * move * math.abs(s)
	local roll = gait.roll * move * s
	local lean = gait.lean * move
	local shift = 0
	if mode == Models.MODE_WINDUP then
		bob -= WINDUP_CROUCH * r
		shift = WINDUP_TREMBLE * r * math.sin(now * WINDUP_TREMBLE_SPEED)
		lean = -WINDUP_REAR
	elseif mode == Models.MODE_RUSH then
		lean = RUSH_LEAN
	elseif mode == Models.MODE_RECOVER then
		lean = RECOVER_SLUMP
		roll = 0
	end
	local body = base * CFrame.new(shift, bob, 0) * CFrame.Angles(-lean, 0, roll)
	local legAngle = gait.legSwing * move * s
	local armAngle = gait.armSwing * move * s
	local legLeft, legRight = CFrame.Angles(legAngle, 0, 0), CFrame.Angles(-legAngle, 0, 0)
	local armLeft, armRight = CFrame.Angles(-armAngle, 0, 0), CFrame.Angles(armAngle, 0, 0)

	local anims, pivots, offsets = visual.anims, visual.pivots, visual.offsets
	local hidden, details, low = visual.hidden, visual.details, visual.lowDetail
	for k, part in visual.parts do
		if hidden[k] or (low and details[k]) then
			continue
		end
		local anim = anims[k]
		local cframe
		if anim == BODY then
			cframe = body * offsets[k]
		elseif anim == GROUND then
			cframe = base * offsets[k]
		elseif anim == LEG_LEFT then
			cframe = base * pivots[k] * legLeft * offsets[k]
		elseif anim == LEG_RIGHT then
			cframe = base * pivots[k] * legRight * offsets[k]
		elseif anim == ARM_LEFT then
			cframe = body * pivots[k] * armLeft * offsets[k]
		elseif anim == ARM_RIGHT then
			cframe = body * pivots[k] * armRight * offsets[k]
		elseif anim == SWING then
			cframe = body
				* pivots[k]
				* CFrame.Angles(SWING_ANGLE * math.sin(now * SWING_SPEED + seed), 0, 0)
				* offsets[k]
		elseif anim == SPIN then
			cframe = body * pivots[k] * CFrame.Angles(0, now * SPIN_SPEED + seed, 0) * offsets[k]
		else -- FLOAT
			cframe = body * CFrame.new(0, FLOAT_HEIGHT * r * math.sin(now * FLOAT_SPEED + seed + k), 0) * offsets[k]
		end
		count += 1
		parts[count] = part
		cframes[count] = cframe
	end
	return count
end

return Models
