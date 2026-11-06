--!strict
-- Values of the 2D presentation (DESIGN.md section 14): sizes and motion of every world sprite; the pictures and their
-- shares come from the generated Config/SpriteImages (tools/art2d/import_sprites.py). Read by Util/WorldSprite, the
-- renderers and the server services that place lobby and cosmetic sprites. Only looks: nothing here changes hit radii,
-- speeds or other gameplay values.

-- `studs` is the side of the square image in the world. `ground` is the empty share below the figure's ground line
-- (0.5 = the anchor is the middle of the picture) and `center` the share of the figure's horizontal middle.
export type Art = {
	image: string,
	studs: number,
	ground: number?,
	center: number?,
	pixels: number?, -- image side in pixels; needed to mirror it
}

-- Motion of one enemy sprite, per enemy kind (taken from its former model rig).
export type EnemyArt = Art & {
	stride: number, -- studs per step cycle
	bob: number, -- hop per step, share of the radius
	roll: number, -- radians of side-to-side sway
	lean: number, -- radians leaning into the walk
	glow: Color3?, -- eyes and lenses: its death burst
}

local Images: any = require(script.Parent.SpriteImages)

-- The world values of a picture whose figure is `height` studs tall.
local function fit(entry: any, height: number): Art
	return table.freeze({
		image = entry.image,
		studs = height / entry.height,
		ground = entry.ground,
		center = entry.center,
		pixels = entry.pixels,
	})
end

local function fitAll(entries: any, heights: { [string]: number }): { [string]: Art }
	local result: { [string]: Art } = {}
	for name, entry in entries do
		result[name] = fit(entry, heights[name] or heights.default)
	end
	return table.freeze(result)
end

local Sprites = {
	-- Moves every sprite this many studs towards the camera, so flat floor marks do not cut a figure's feet. All sprites
	-- use the same value, which keeps their order front to back. More shifts pictures off their shadows at the screen edge.
	depthBias = 1.5,
	-- The billboard is larger than the picture by this factor, so squash and sway never clip at its edge.
	canvasMargin = 1.25,
	-- Pose changes below these are not written to the picture (saves work with big crowds).
	poseScaleStep = 0.004,
	poseRotationStep = 0.25,

	-- The flat dark disc under figures. Colors are { red, green, blue }.
	shadow = table.freeze({ color = { 0, 0, 0 }, transparency = 0.6, thickness = 0.05 }),

	-- Player characters.
	character = table.freeze({
		bodyStuds = 5.4, -- height of the figure (the character's collision stays the same)
		shadowStuds = 3.6, -- width of its shadow
		retrySeconds = 5,
		loadAttempts = 3,
		idleSpeed = 2.4, -- radians/s
		idleSquash = 0.018,
		walkStride = 5, -- studs per step cycle
		walkHop = 0.07, -- share of the body height
		walkSquash = 0.035,
		walkRollDegrees = 4,
		movingThreshold = 0.2, -- studs/s
		blendSharpness = 12,
		attackSeconds = 0.16,
		attackScale = 0.09,
		hitSeconds = 0.12,
		hitBrightness = 4,
		downRotationDegrees = 78,
		downTint = { 166, 166, 180 },
		outTint = { 96, 96, 112 },
		classes = Images.characters,
	}),

	-- Shared pictures; their white parts take the color of the object.
	images = Images.shared,

	-- Looks of enemy sprites that are not in the images themselves.
	enemy = table.freeze({
		figureWidth = 2.6, -- width of the figure, times the enemy's radius
		figureWidths = table.freeze({}) :: { [string]: number }, -- other widths by enemy id
		-- One step cycle: studs walked, hop (share of the radius), sway and lean (radians).
		gait = table.freeze({ stride = 4.8, bob = 0.045, roll = 0.055, lean = 0.065 }),
		flashBrightness = 5,
		statusTint = 0.55,
		rushTint = { 255, 120, 110 },
		steelTint = { 190, 200, 216 },
		crownStuds = 2.6, -- times the radius
		crownSpinDegrees = 90, -- per second
		wispStuds = 0.8, -- times the radius
		wispOrbit = 1.3, -- times the radius
		wispSpeed = 1.6, -- radians/s
		squash = 0.05,
		windupScale = 0.88,
		tremble = 0.05, -- share of the radius
		trembleSpeed = 70,
		rushDegrees = 14,
		recoverDegrees = 6,
		idleSpeed = 2.2,
		idleSquash = 0.015,
		lowDetailStep = 3, -- crowds: only every n-th frame poses the picture
	}),

	-- One picture per enemy kind; a Gloom Elite uses its kind's picture, larger and with a crown.
	enemyImages = Images.enemies,

	-- Fruit and crates (PickupRenderer): figure heights in studs.
	pickups = fitAll(Images.pickups, { default = 2.6, Fruit = 2.2, Crate = 3, LegendaryCrate = 3.6 }),

	-- Hub lobby props (LobbyArtService).
	lobby = fitAll(Images.lobby, { default = 10, Arch = 20, Beacon = 14, Lamp = 10, CornerRuin = 12 }),
	lobbyParapetHeight = 0.12, -- the old low wall, now a flat band

	-- Floor pictures: `studs` is the side of one tile (MapService).
	floors = table.freeze({
		Arena = table.freeze({ image = Images.floors.Arena, studs = 40 }),
		Lobby = table.freeze({ image = Images.floors.Lobby, studs = 40 }),
	}),

	-- Cosmetic lanterns float beside the character (CosmeticService).
	lantern = table.freeze({ studs = 2.2 }),
	-- Elite chests.
	chest = table.freeze({ art = fit(Images.world.Chest, 3.2) }),
	-- Sentries and companions (StructureRenderer): one picture per kind, figure heights in studs, some float.
	structures = fitAll(Images.structures, {
		default = 4.5,
		RuneMine = 1.8,
		MoonGarden = 2.8,
		OrbitWisp = 1.8,
		StormFamiliar = 2.4,
	}),
	structureHover = table.freeze({ Orbit = 2, Radial = 2 }) :: { [string]: number },
	-- XP orbs are this much larger than their former balls, because a soft edge reads smaller.
	orbScale = 1.2,
	-- Bolts and shots: picture size against the former halo.
	glowScale = 1.5,
}

return table.freeze(Sprites)
