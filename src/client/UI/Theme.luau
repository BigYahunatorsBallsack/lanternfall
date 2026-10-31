--!strict
-- Shared high-contrast UI palette: warm charcoal, parchment text and lantern-gold actions.
-- Used by UI/Widgets and the UI controllers.

return table.freeze({
	canvas = Color3.fromRGB(23, 25, 25),
	surface = Color3.fromRGB(47, 49, 46),
	shards = Color3.fromRGB(151, 225, 132),
	panel = Color3.fromRGB(35, 38, 36),
	panelTransparency = 0,
	stroke = Color3.fromRGB(100, 103, 88),
	text = Color3.fromRGB(245, 238, 222),
	textDim = Color3.fromRGB(190, 191, 176),
	accent = Color3.fromRGB(255, 196, 87), -- lantern yellow
	accentText = Color3.fromRGB(45, 30, 8),
	button = Color3.fromRGB(58, 62, 55),
	gloom = Color3.fromRGB(152, 102, 218), -- violet: enemies and defeat
	success = Color3.fromRGB(126, 214, 136),
	danger = Color3.fromRGB(236, 96, 96),
	-- rarity tiers 1..4 (Config.Items.tiers): Common, Uncommon, Rare, Legendary
	tiers = table.freeze({
		Color3.fromRGB(214, 206, 196),
		Color3.fromRGB(96, 168, 255),
		Color3.fromRGB(184, 110, 255),
		Color3.fromRGB(255, 98, 82),
	}),
	font = Enum.Font.GothamMedium,
	fontBold = Enum.Font.GothamBold,
	corner = UDim.new(0, 5),
	textSize = 20,
	titleSize = 30,
})
