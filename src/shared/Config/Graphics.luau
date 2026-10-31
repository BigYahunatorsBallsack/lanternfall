--!strict
-- Graphics quality (Paket 22, DESIGN.md section 15): the settings menu offers Auto, High and Low (Config.Settings,
-- saved in the profile). Low is what phones always got (fewer enemy trims, death sparks, ember puffs and damage
-- numbers: the *Touch values in Config.Feedback) plus no bloom, no optional lights (decor lanterns and the lanterns
-- of other players; your own stays lit) and fewer floating embers over the arena. Auto picks Low on phones and
-- tablets, when Roblox's own graphics slider is turned down, or when a run stays below lowFps for a while (then for
-- the rest of the session). Read by GraphicsController; the renderers ask it which values to use.

return table.freeze({
	choices = table.freeze({ "Auto", "High", "Low" }),
	auto = table.freeze({
		lowOnTouch = true, -- phones and tablets (touch without a keyboard) start with Low
		robloxQualityLowAtOrBelow = 4, -- Roblox's graphics quality slider (Esc menu, 1-10) at or below this = Low
		lowFps = 28, -- average frames per second in a run below this ...
		lowFpsSeconds = 6, -- ... for this long switches Auto to Low until the player leaves (assumption)
		-- Studio playtests (several clients on one PC) are slower than the real game, so the FPS check is off there
		fpsCheckInStudio = false,
	}),
	low = table.freeze({
		bloom = false, -- the arena's bloom (Lighting.LanternfallBloom) costs a full-screen pass
		optionalLights = false, -- lights tagged optionalLightTag (decor lanterns, other players' lanterns)
		motesShare = 0.4, -- share of the arena's floating embers (Config.Map.decor.motes.rate)
	}),
	optionalLightTag = "LanternfallOptionalLight", -- CollectionService tag the server puts on lights Low turns off
	motesTag = "LanternfallMotes", -- tag of the arena's ember emitter
	-- Enemies off the screen are not posed (EnemyRenderer, Util/ViewBounds). A model counts as on the screen while a
	-- circle of radius * cullMarginRadii + cullMarginStuds around it is (camera shake, a frame of lag).
	cullOffscreen = true,
	cullMarginRadii = 2,
	cullMarginStuds = 3,
})
