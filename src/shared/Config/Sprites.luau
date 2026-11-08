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

	-- Thick dark outline around every figure, weapon and drop so it stands out from the floor and the crowd (owner,
	-- 08.11.2026, after his Brotato screenshots: "um alles im Spiel"). Drawn as dark copies of the picture shifted
	-- `directions` ways by `studs` behind it (Util/WorldSprite.outline). Glows, beams and shots stay without.
	outline = table.freeze({ studs = 0.32, directions = 8, color = { 18, 14, 16 } }),

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
		-- The waddle: the body tips over its feet from side to side, flattens while tipped and stretches and lifts when it is
		-- upright. Rhythm measured from frames of Brotato's Steam clip: one flatten-and-stretch takes about 0.3 s, which is
		-- half a waddle. The strengths are estimates, the clip is small and busy; owner found them too bouncy, so they were
		-- roughly halved and the rhythm slowed (06.11.2026).
		walkCycleSeconds = 0.75, -- one step left and right (calmed from 0.6 on 06.11.2026)
		walkTiltDegrees = 4, -- was 7
		walkSquash = 0.045, -- was 0.09
		walkHopStuds = 0.1, -- was 0.25
		-- Two feet in alternating steps; `image` is drawn behind the body.
		foot = table.freeze({ studs = 1.5, spread = 0.95, lift = 0.3, stride = 0.3 }), -- lift was 0.45
		movingThreshold = 0.2, -- studs/s
		blendSharpness = 8, -- how softly the walk starts and ends
		attackSeconds = 0.16,
		attackScale = 0.09,
		hitSeconds = 0.12,
		hitBrightness = 4,
		downRotationDegrees = 78,
		downTint = { 166, 166, 180 },
		outTint = { 96, 96, 112 },
		classes = Images.characters,
	}),

	-- The red crosses on the floor where enemies will appear (SpawnMarkerRenderer): a thick brush-like X with a dark
	-- outline, about as wide as an enemy (owner, 08.11.2026: bigger and in the game's style). Studs unless noted;
	-- colors are { red, green, blue }. Each cross gets a small random tilt and bar length so a group looks hand drawn.
	spawnMarker = table.freeze({
		size = 5.6, -- tip to tip of one bar; the X is then about 4.5 studs wide, a bit wider than a character
		barStuds = 1.05, -- thickness of the red bar
		outlineStuds = 0.32, -- dark rim around it
		color = { 226, 52, 46 },
		outlineColor = { 30, 14, 14 },
		tiltDegrees = 10, -- the whole cross turns up to this much either way
		lengthJitter = 0.1, -- each bar is up to this share shorter or longer
		popSeconds = 0.18, -- grows in from popScale when it appears
		popScale = 0.4,
		-- Blinks between solid and pale until the enemies come. Pale is a lighter color, not see-through: two see-through
		-- bars would show a dark patch where they cross.
		pulsesPerSecond = 2.5,
		paleColor = { 238, 150, 140 },
		paleOutlineColor = { 128, 96, 90 },
		paleShare = 0.75, -- how far towards the pale colors the blink goes
		pixelsPerStud = 40,
		maxShown = 200, -- more at once are not drawn (performance budget)
	}),

	-- Weapons float around the middle of the figure, clear of its body. Only what the eye sees: shots keep the server's
	-- path (Util/WeaponPose) and start at the barrel on the screen.
	heldWeapons = table.freeze({
		lift = 2.7, -- studs north of the feet: the figure's middle on the screen
		clearance = 3.2, -- studs from that middle to the inner end of a weapon
	}),

	-- Shared pictures; their white parts take the color of the object.
	images = Images.shared,

	-- Looks of enemy sprites that are not in the images themselves.
	enemy = table.freeze({
		figureWidth = 2.6, -- width of the figure, times the enemy's radius
		figureWidths = table.freeze({}) :: { [string]: number }, -- other widths by enemy id
		-- One step cycle: studs walked, hop (share of the radius), sway and lean (radians).
		gait = table.freeze({ stride = 7.5, bob = 0.04, roll = 0.05, lean = 0.065 }), -- was stride 6, bob 0.1, roll 0.1
		-- Hit flash: the picture is multiplied with flashTint and brightened by flashBrightness. Red as in the owner's
		-- Brotato screenshot (08.11.2026): a hit enemy keeps its red and loses about 60 % of green and blue. Was white
		-- with brightness 5 before.
		flashTint = { 255, 102, 92 },
		flashBrightness = 1,
		statusTint = 0.55,
		rushTint = { 255, 120, 110 },
		steelTint = { 190, 200, 216 },
		crownStuds = 2.6, -- times the radius
		crownSpinDegrees = 90, -- per second
		wispStuds = 0.8, -- times the radius
		wispOrbit = 1.3, -- times the radius
		wispSpeed = 1.6, -- radians/s
		squash = 0.04, -- was 0.08
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
	-- Original green materials: the source icon has transparent margins. Value affects size, never its color.
	material = table.freeze({
		hover = 0.4,
		-- Every lying shard gets one of these pictures (own art, assets/loot/shards, tools/art2d/draw_shards.py), turned,
		-- mirrored and resized a little by its id (Util/MaterialLook). Empty would fall back to images.material.
		variants = table.freeze({
			"rbxassetid://87489429273732", -- Shard1
			"rbxassetid://138534309544212", -- Shard2
			"rbxassetid://122404990704565", -- Shard3
			"rbxassetid://121436964172051", -- Shard4
			"rbxassetid://101335597185731", -- Shard5
			"rbxassetid://94963330299874", -- Shard6
		}) :: { string },
		pixels = 256, -- side of every material picture, for mirroring
		turn = 180, -- degrees either way
		sizeJitter = 0.12, -- share either way
		tiers = table.freeze({
			{ minValue = 0, size = 1.6 },
			{ minValue = 4, size = 2 },
			{ minValue = 20, size = 2.5 },
		}),
	}),
	-- Bolts and shots: picture size against the former halo.
	glowScale = 1.5,
}

return table.freeze(Sprites)
