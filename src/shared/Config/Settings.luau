--!strict
-- Player settings (Paket 14, DESIGN.md section 13): what the settings menu offers, the defaults new players start
-- with and how the client saves changes. Saved per player in the profile (schema v4, PlayerDataService). Read by
-- SettingsController, the SaveSettings remote and ProfileTemplate. Sounds use the volumes through the SoundGroups
-- "Music" and "Effects" (Paket 21 puts its sounds there).

return table.freeze({
	defaults = table.freeze({
		shake = true, -- camera shake (Config.Feedback.shake)
		damageNumbers = true, -- own damage numbers over enemies
		music = 0.6, -- volume 0..1
		effects = 0.8, -- volume 0..1
		graphics = "Auto", -- Paket 22: "Auto", "High" or "Low" (Config.Graphics)
	}),
	volumeStep = 0.1, -- the - and + buttons of a volume
	saveDelaySeconds = 1, -- the client sends the settings this long after the last change (one save per burst)
	tooltip = table.freeze({
		touchSeconds = 4, -- a tooltip opened by a tap closes after this long (or with the next tap)
		width = 300, -- pixels on the 1280x720 reference screen
	}),
	-- Screens smaller than this (pixels, after the Roblox top bar) get the compact HUD and results (phones)
	compactWidth = 900,
	compactHeight = 560,
})
