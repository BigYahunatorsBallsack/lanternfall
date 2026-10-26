--!strict
-- Colors and fonts of the prototype UI (DESIGN.md section 14: players warm yellow, enemies violet).
-- Used by UI/Widgets and the UI controllers.

return table.freeze({
	panel = Color3.fromRGB(24, 20, 34),
	panelTransparency = 0.12,
	stroke = Color3.fromRGB(92, 72, 124),
	text = Color3.fromRGB(245, 238, 222),
	textDim = Color3.fromRGB(176, 166, 192),
	accent = Color3.fromRGB(255, 196, 87), -- lantern yellow
	accentText = Color3.fromRGB(45, 30, 8),
	button = Color3.fromRGB(58, 50, 78),
	gloom = Color3.fromRGB(152, 102, 218), -- violet: enemies and defeat
	success = Color3.fromRGB(126, 214, 136),
	danger = Color3.fromRGB(236, 96, 96),
	font = Enum.Font.GothamMedium,
	fontBold = Enum.Font.GothamBold,
	corner = UDim.new(0, 12),
	textSize = 20,
	titleSize = 30,
})
