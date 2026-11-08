--!strict
-- Approved shop palette and chunky rounded typography (Fredoka One, owner choice 2026-11-08). Used by Widgets and all menu/HUD controllers.
-- Used by UI/Widgets and the UI controllers.

return table.freeze({
	canvas = Color3.fromRGB(64, 64, 64),
	surface = Color3.fromRGB(77, 88, 93),
	shards = Color3.fromRGB(112, 220, 92),
	panel = Color3.fromRGB(29, 29, 29),
	panelTransparency = 0,
	stroke = Color3.fromRGB(7, 7, 7),
	text = Color3.fromRGB(250, 250, 250),
	textDim = Color3.fromRGB(212, 212, 212),
	accent = Color3.fromRGB(242, 242, 242),
	accentText = Color3.fromRGB(7, 7, 7),
	button = Color3.fromRGB(10, 10, 10),
	gloom = Color3.fromRGB(152, 102, 218), -- violet: enemies and defeat
	success = Color3.fromRGB(0, 230, 0),
	danger = Color3.fromRGB(246, 22, 22),
	statLabel = Color3.fromRGB(220, 216, 163),
	price = Color3.fromRGB(30, 30, 30),
	hp = Color3.fromRGB(192, 0, 0),
	xp = Color3.fromRGB(52, 211, 49),
	cardSurfaces = table.freeze({
		Color3.fromRGB(8, 8, 8),
		Color3.fromRGB(18, 33, 40),
		Color3.fromRGB(37, 22, 43),
		Color3.fromRGB(46, 22, 22),
	}),
	-- rarity tiers 1..4 (Config.Items.tiers): Common, Uncommon, Rare, Legendary
	tiers = table.freeze({
		Color3.fromRGB(250, 250, 250),
		Color3.fromRGB(85, 184, 235),
		Color3.fromRGB(202, 114, 239),
		Color3.fromRGB(241, 77, 77),
	}),
	font = Enum.Font.FredokaOne,
	fontBold = Enum.Font.FredokaOne,
	corner = UDim.new(0, 6),
	textSize = 18,
	titleSize = 34,
	shopMaxWidth = 1120,
	hudTextScale = 1.25, -- in-run text (HUD, damage numbers, labels over enemies) is 25 % larger than menu text
})
