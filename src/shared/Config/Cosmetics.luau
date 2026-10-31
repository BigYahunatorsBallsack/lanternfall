--!strict
-- Cosmetics bought with Embers in the Ember shop (Paket 17, DESIGN.md sections 10 and 14): a lantern that floats next
-- to the player and a trail behind them. Look only, no gameplay. VIP-only entries are owned while the player has the
-- VIP pass and can not be bought with Embers. Read by Util/EmberShopRules (server and client), CosmeticService (builds
-- them on the character) and EmberShopController (lobby window). Colors are RGB tables (pure specs load Config).

export type Rgb = { number } -- { r, g, b } 0-255

export type Lantern = {
	id: string,
	slot: "Lantern",
	name: string, -- game text
	price: number, -- Embers; 0 = everyone owns it
	vip: boolean?, -- owned with the VIP pass only (not for Embers)
	style: "Cage" | "Orb" | "Spire", -- shape of the model (CosmeticService)
	frame: Rgb, -- brass, silver, obsidian ...
	metal: boolean, -- Metal material for the frame, else SmoothPlastic
	glow: Rgb, -- the neon core and the light
}

export type Trail = {
	id: string,
	slot: "Trail",
	name: string,
	price: number,
	vip: boolean?,
	colors: { Rgb }, -- start and end color of the trail
}

export type Cosmetic = Lantern | Trail

local lanterns: { Lantern } = {
	{
		id = "BrassLantern",
		slot = "Lantern",
		name = "Brass Lantern",
		price = 0,
		style = "Cage",
		frame = { 181, 142, 76 },
		metal = true,
		glow = { 255, 196, 87 },
	},
	{
		id = "JadeCenser",
		slot = "Lantern",
		name = "Jade Censer",
		price = 750,
		style = "Orb",
		frame = { 120, 96, 60 },
		metal = true,
		glow = { 96, 230, 150 },
	},
	{
		id = "CrimsonVigil",
		slot = "Lantern",
		name = "Crimson Vigil",
		price = 1000,
		style = "Spire",
		frame = { 40, 34, 40 },
		metal = true,
		glow = { 255, 72, 64 },
	},
	{
		id = "Moonglass",
		slot = "Lantern",
		name = "Moonglass Lantern",
		price = 1500,
		style = "Cage",
		frame = { 196, 200, 214 },
		metal = true,
		glow = { 150, 205, 255 },
	},
	{
		id = "VoidLamp",
		slot = "Lantern",
		name = "Void Lamp",
		price = 2500,
		style = "Spire",
		frame = { 26, 20, 34 },
		metal = false,
		glow = { 176, 96, 255 },
	},
	{
		id = "GildedSunburst",
		slot = "Lantern",
		name = "Gilded Sunburst",
		price = 0,
		vip = true,
		style = "Orb",
		frame = { 245, 197, 66 },
		metal = true,
		glow = { 255, 236, 170 },
	},
}

local trails: { Trail } = {
	{
		id = "EmberTrail",
		slot = "Trail",
		name = "Ember Trail",
		price = 750,
		colors = { { 255, 170, 60 }, { 200, 50, 30 } },
	},
	{
		id = "SpectralTrail",
		slot = "Trail",
		name = "Spectral Trail",
		price = 1000,
		colors = { { 160, 240, 255 }, { 60, 140, 255 } },
	},
	{
		id = "VenomTrail",
		slot = "Trail",
		name = "Venom Trail",
		price = 1000,
		colors = { { 180, 255, 90 }, { 40, 150, 70 } },
	},
	{
		id = "RoyalTrail",
		slot = "Trail",
		name = "Royal Trail",
		price = 2000,
		colors = { { 176, 96, 255 }, { 245, 197, 66 } },
	},
	{
		id = "GildedTrail",
		slot = "Trail",
		name = "Gilded Trail",
		price = 0,
		vip = true,
		colors = { { 245, 197, 66 }, { 245, 197, 66 } },
	},
}

for _, list in { lanterns, trails } :: { { any } } do
	for _, entry in list do
		table.freeze(entry)
	end
end

return table.freeze({
	slots = table.freeze({ "Lantern", "Trail" }),
	lanterns = table.freeze(lanterns),
	trails = table.freeze(trails),
	-- What a slot shows while the player never picked anything: VIP players their VIP entry (Paket 16's golden trail),
	-- everyone else this (nil = nothing).
	defaults = table.freeze({ Lantern = "BrassLantern" }) :: { [string]: string },
	vipDefaults = table.freeze({ Lantern = "GildedSunburst", Trail = "GildedTrail" }) :: { [string]: string },
	none = "None", -- equipped id that shows nothing in a slot
	-- The lantern model (CosmeticService): where it floats next to the HumanoidRootPart (studs, right/up/back), its
	-- size and its light
	lantern = table.freeze({
		offset = table.freeze({ 1.7, 1.4, 0.6 }),
		scale = 1, -- size multiplier of the whole model
		lightRange = 10,
		lightBrightness = 1.2,
	}),
	trail = table.freeze({
		lifetime = 0.45, -- seconds
		width = 1.8, -- studs between the two attachments
	}),
})
