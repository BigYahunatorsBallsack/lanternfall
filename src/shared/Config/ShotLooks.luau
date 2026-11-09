--!strict
-- Look of every flying weapon shot (own drawings in Brotato's style, no copied art): shape, size in studs, colors,
-- spin, trail and muzzle flash per weapon behavior. Read by WeaponRenderer/B7ProjectileVisual and ShotShapes.
-- Presentation only: speed, range, piercing and hits stay on the server (WeaponService).
--
-- Shapes (all drawn pointing right, along the flight): bullet, pellet, laser, lightning, orb, fireball, flame, icicle,
-- arrow, dart, harpoon, thorn, rock, potato, shuriken, rocket, grenade. Sizes are estimates from Brotato gameplay
-- footage relative to the figure (Sprites.character.bodyStuds 5.4); Brotato's own sprite sizes are not public.

export type RGB = { number }

export type Look = {
	shape: string,
	length: number, -- studs along the flight
	width: number, -- studs across
	color: RGB, -- main color (body, halo)
	core: RGB?, -- inner/highlight color
	accent: RGB?, -- third color (fins, fletching, spots)
	rim: boolean?, -- thin dark outline: solid shots only, glowing shots stay without (Sprites.outline)
	spin: number?, -- degrees per second the shape turns instead of pointing along the flight
	trail: number?, -- trail width in studs, nil for none
	trailSeconds: number?,
	muzzle: boolean?, -- short flash at the barrel when fired
	hit: RGB?, -- spark color where it ends, default `color`
}

local YELLOW = { 255, 214, 74 }
local BULLET_CORE = { 255, 250, 205 }
local ORANGE = { 255, 140, 40 }

local function bullet(length: number, width: number): Look
	return {
		shape = "bullet",
		length = length,
		width = width,
		color = ORANGE,
		core = YELLOW,
		accent = BULLET_CORE,
		rim = true,
		trail = width * 0.5,
		trailSeconds = 0.06,
		muzzle = true,
		hit = YELLOW,
	}
end

local function laser(length: number, width: number, color: RGB): Look
	return {
		shape = "laser",
		length = length,
		width = width,
		color = color,
		core = { 245, 255, 255 },
		trail = width * 0.6,
		trailSeconds = 0.08,
		muzzle = true,
	}
end

local function lightning(color: RGB): Look
	return { shape = "lightning", length = 2.6, width = 1, color = color, core = { 255, 255, 240 } }
end

local ShotLooks = {
	-- Short white-yellow star at the barrel, `seconds` long, `studs` across.
	muzzleFlash = table.freeze({ seconds = 0.07, studs = 1.6, color = { 255, 236, 150 }, core = { 255, 255, 240 } }),
	-- Used for any behavior without an entry below.
	default = bullet(1.6, 0.6),
	rimColor = { 40, 22, 14 },
	rimPixels = 2, -- UIStroke thickness; the camera distance is fixed (Config/Camera), so pixels stay comparable
	height = 2, -- studs above the floor
	hitSparks = 5,
	-- Flames grow from `flameStart` to `flameEnd` times their size over the flight and fade out at the end.
	flameStart = 0.55,
	flameEnd = 1.5,
	flameFadeFrom = 0.55, -- share of the range after which a flame starts to fade
	byBehavior = {} :: { [string]: Look },
}

ShotLooks.byBehavior = {
	-- Firearms: yellow-orange bullets.
	WatchmanPistol = bullet(1.7, 0.65), -- Pistol
	RattleRepeater = bullet(1.4, 0.55), -- SMG
	Minigun = bullet(1.4, 0.55),
	ChainGun = bullet(1.5, 0.6),
	Machinegun = bullet(1.4, 0.55),
	Revolver = bullet(1.8, 0.7),
	SniperGun = bullet(2.4, 0.75),
	ShrapnelOrgan = bullet(1.6, 0.65), -- Shredder
	ScatterBell = { -- Double Barrel Shotgun: short round pellets
		shape = "pellet",
		length = 0.9,
		width = 0.75,
		color = ORANGE,
		core = YELLOW,
		rim = true,
		trail = 0.35,
		trailSeconds = 0.05,
		muzzle = true,
		hit = YELLOW,
	},
	CombatShotgun = {
		shape = "pellet",
		length = 0.9,
		width = 0.75,
		color = ORANGE,
		core = YELLOW,
		rim = true,
		trail = 0.35,
		trailSeconds = 0.05,
		muzzle = true,
		hit = YELLOW,
	},
	Blunderbuss = {
		shape = "pellet",
		length = 0.9,
		width = 0.8,
		color = { 150, 150, 160 },
		core = { 225, 225, 230 },
		rim = true,
		muzzle = true,
	},

	-- Energy weapons: long glowing bolts.
	LaserGun = laser(3, 0.6, { 70, 170, 255 }),
	CathedralEngine = laser(2.2, 0.45, { 80, 190, 255 }), -- Gatling Laser
	Railgun = laser(4.2, 0.55, { 90, 235, 255 }),
	Obliterator = laser(4.6, 1.1, { 255, 70, 120 }),
	LeechCarbine = laser(2.4, 0.5, { 90, 240, 110 }), -- Medical Gun
	ParticleAccelerator = laser(2.6, 0.6, { 190, 110, 255 }),
	DEXtroyer = laser(2.6, 0.6, { 255, 90, 60 }),

	-- Electric: zigzag sparks.
	GalvanicFork = lightning({ 255, 225, 70 }), -- Taser
	ThunderSword = lightning({ 120, 210, 255 }),
	ChainLightning = lightning({ 120, 210, 255 }), -- Lightning Shiv

	-- Magic: round glowing orbs.
	SparkBolt = {
		shape = "orb",
		length = 1.2,
		width = 1.2,
		color = { 175, 95, 255 },
		core = { 250, 235, 255 },
		trail = 0.6,
	}, -- Wand
	GhostScepter = {
		shape = "orb",
		length = 1.3,
		width = 1.3,
		color = { 160, 230, 255 },
		core = { 245, 255, 255 },
		trail = 0.7,
		trailSeconds = 0.2,
	},
	PanFlute = {
		shape = "orb",
		length = 1,
		width = 1,
		color = { 255, 140, 200 },
		core = { 255, 240, 250 },
		trail = 0.5,
	},
	Fireball = {
		shape = "fireball",
		length = 2,
		width = 1.3,
		color = { 255, 110, 30 },
		core = { 255, 230, 110 },
		trail = 0.9,
		trailSeconds = 0.14,
	},
	CinderBreath = { -- Flamethrower: puffs that grow and fade
		shape = "flame",
		length = 1.5,
		width = 1.5,
		color = { 255, 105, 30 },
		core = { 255, 220, 90 },
		hit = { 255, 140, 40 },
	},
	WinterNeedle = { -- Icicle
		shape = "icicle",
		length = 2,
		width = 0.6,
		color = { 150, 220, 255 },
		core = { 240, 252, 255 },
		rim = true,
		trail = 0.3,
		trailSeconds = 0.08,
	},

	-- Thrown and launched solids.
	BoomerangAxe = { -- Crossbow
		shape = "arrow",
		length = 2.4,
		width = 0.6,
		color = { 150, 100, 55 },
		core = { 190, 195, 205 },
		accent = { 235, 70, 60 },
		rim = true,
	},
	Javelin = {
		shape = "harpoon",
		length = 3,
		width = 0.55,
		color = { 160, 110, 60 },
		core = { 200, 205, 215 },
		rim = true,
	},
	HarpoonGun = {
		shape = "harpoon",
		length = 2.8,
		width = 0.6,
		color = { 120, 125, 135 },
		core = { 210, 215, 225 },
		rim = true,
	},
	Blowgun = {
		shape = "dart",
		length = 1.4,
		width = 0.4,
		color = { 200, 200, 210 },
		accent = { 120, 220, 90 },
		rim = true,
	},
	TranqRifle = {
		shape = "dart",
		length = 1.6,
		width = 0.45,
		color = { 200, 200, 210 },
		accent = { 255, 210, 70 },
		rim = true,
		muzzle = true,
	},
	CactiClub = {
		shape = "thorn",
		length = 1.3,
		width = 0.35,
		color = { 90, 170, 70 },
		core = { 230, 240, 190 },
		rim = true,
	},
	Slingshot = {
		shape = "rock",
		length = 0.95,
		width = 0.95,
		color = { 135, 130, 125 },
		core = { 185, 180, 172 },
		rim = true,
		spin = 360,
	},
	PotatoThrower = {
		shape = "potato",
		length = 1.4,
		width = 1.05,
		color = { 200, 150, 85 },
		core = { 225, 185, 120 },
		accent = { 140, 95, 50 },
		rim = true,
		spin = 300,
	},
	Shuriken = {
		shape = "shuriken",
		length = 1.4,
		width = 1.4,
		color = { 160, 165, 175 },
		core = { 70, 72, 80 },
		rim = true,
		spin = 900,
	},
	MortarLantern = { -- Rocket Launcher
		shape = "rocket",
		length = 2.2,
		width = 0.8,
		color = { 210, 210, 215 },
		core = { 225, 60, 50 },
		accent = { 255, 170, 50 },
		rim = true,
		trail = 0.6,
		trailSeconds = 0.2,
		hit = { 255, 160, 60 },
	},
	NuclearLauncher = {
		shape = "rocket",
		length = 3,
		width = 1.15,
		color = { 225, 200, 60 },
		core = { 50, 50, 55 },
		accent = { 255, 170, 50 },
		rim = true,
		trail = 0.9,
		trailSeconds = 0.25,
		hit = { 255, 160, 60 },
	},
	GrenadeLauncher = {
		shape = "grenade",
		length = 1.1,
		width = 1.1,
		color = { 85, 110, 60 },
		core = { 130, 155, 95 },
		accent = { 60, 60, 65 },
		rim = true,
		spin = 420,
	},
}

for _, look in ShotLooks.byBehavior do
	table.freeze(look)
end
table.freeze(ShotLooks.byBehavior)
table.freeze(ShotLooks.default)
return table.freeze(ShotLooks)
