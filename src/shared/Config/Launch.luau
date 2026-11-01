--!strict
-- Launch package (Paket 24, DESIGN.md section 22): the launch check (what is still missing before the game goes
-- public) and the capture mode for icons, thumbnails and clips. Read by LaunchService and Util/LaunchRules (server),
-- CaptureController and CameraController (client) and AdminService ("Showcase").

export type CameraShot = {
	name: string, -- shown in the capture hint
	pitchDegrees: number, -- like Config.Camera.pitchDegrees; the camera still looks north
	distance: number, -- studs from the focus point
	fieldOfView: number,
}

return table.freeze({
	check = table.freeze({
		printInStudio = true, -- one summary line in Studio's Output at server start
		warnLive = true, -- live servers warn about open "must" items (Developer Console, F9)
	}),

	-- Capture mode (admins only, see CaptureController): hides every on-screen menu and Roblox's own buttons, so the
	-- picture shows only the game; another key cycles camera shots for thumbnails and clips.
	capture = table.freeze({
		toggleKey = "F6", -- capture mode on/off (an Enum.KeyCode name)
		shotKey = "F7", -- next camera shot
		hintSeconds = 2.5, -- the small hint after a key press, then the screen is clean
		-- The first shot is the normal game camera (Config.Camera); the others are closer or flatter.
		shots = table.freeze({
			table.freeze({ name = "Game camera", pitchDegrees = 0, distance = 0, fieldOfView = 0 }),
			table.freeze({ name = "Close", pitchDegrees = 55, distance = 38, fieldOfView = 50 }),
			table.freeze({ name = "Low hero", pitchDegrees = 28, distance = 30, fieldOfView = 55 }),
			table.freeze({ name = "Wide", pitchDegrees = 70, distance = 110, fieldOfView = 50 }),
		}) :: { CameraShot },
	}),

	-- Debug command "Showcase": a scene to film. Stops the wave timer, fills the admin's weapon slots, raises every
	-- weapon to `weaponTier` and spawns `enemies` around the admin (the alive cap still applies).
	showcase = table.freeze({
		enemies = 70,
		weaponTier = 3,
	}),
})
