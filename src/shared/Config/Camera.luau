--!strict
-- Fixed top-down camera (DESIGN.md section 4). Read by CameraController.

local Stats = require(script.Parent.Stats)

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
	-- Brotato's camera (main.gd EDGE_SIZE 96, my_camera.gd): it stops where its view would leave the zone grown by
	-- 96 px left, right and south and 192 px north, and stays centered on an axis the view already shows whole.
	edgeStuds = table.freeze({
		west = 96 * Stats.range.studsPerPoint,
		east = 96 * Stats.range.studsPerPoint,
		north = 192 * Stats.range.studsPerPoint,
		south = 96 * Stats.range.studsPerPoint,
	}),
})
