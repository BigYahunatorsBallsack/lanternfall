--!strict
-- Fixed top-down camera (DESIGN.md section 4). Read by CameraController.

return table.freeze({
	-- Looks almost straight down, like Brotato (Paket 25, Owner). Not exactly 90: sprites further south must stay a little
	-- nearer to the camera, that keeps them in front of what stands north of them.
	pitchDegrees = 89.5, -- angle between the view direction and the floor (90 = straight down; 50 until Paket 25)
	-- Studs from the character to the camera. 90 since 08.11.2026: on the owner's Brotato screenshot the character is
	-- about 7.7 % of the screen height, at 115 it was about 6 %. (115 until then, 100 until Paket 25, 70 until B9)
	distance = 90,
	fieldOfView = 40, -- vertical, degrees
	followSharpness = 12, -- how quickly the camera catches up with the character (higher = tighter)
	targetHeightOffset = 0, -- studs above the HumanoidRootPart the camera looks at
})
