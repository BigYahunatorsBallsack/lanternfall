--!strict
-- Shared cartoon UI palette: warm stone, ink outlines, ivory text and green primary actions.
-- Used by UI/Widgets and the UI controllers.

return table.freeze({
	canvas = Color3.fromRGB(53, 52, 47),
	surface = Color3.fromRGB(86, 84, 74),
	shards = Color3.fromRGB(177, 228, 107),
	panel = Color3.fromRGB(67, 66, 58),
	panelTransparency = 0,
	stroke = Color3.fromRGB(24, 23, 20),
	text = Color3.fromRGB(255, 250, 229),
	textDim = Color3.fromRGB(204, 202, 185),
	accent = Color3.fromRGB(174, 211, 111),
	accentText = Color3.fromRGB(27, 34, 20),
	button = Color3.fromRGB(90, 88, 76),
	gloom = Color3.fromRGB(152, 102, 218), -- violet: enemies and defeat
	success = Color3.fromRGB(158, 213, 104),
	danger = Color3.fromRGB(236, 96, 96),
	-- rarity tiers 1..4 (Config.Items.tiers): Common, Uncommon, Rare, Legendary
	tiers = table.freeze({
		Color3.fromRGB(214, 206, 196),
		Color3.fromRGB(96, 168, 255),
		Color3.fromRGB(184, 110, 255),
		Color3.fromRGB(255, 98, 82),
	}),
	font = Enum.Font.GothamBold,
	fontBold = Enum.Font.FredokaOne,
	corner = UDim.new(0, 8),
	textSize = 18,
	titleSize = 34,
	shopMaxWidth = 1120,
})
