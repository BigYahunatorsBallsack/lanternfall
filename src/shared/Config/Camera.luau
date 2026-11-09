--!strict
-- Fixed top-down camera (DESIGN.md section 4). Read by CameraController.

local Stats = require(script.Parent.Stats)

local FIELD_OF_VIEW = 40
local VIEW_HEIGHT_STUDS = 1080 * Stats.range.studsPerPoint -- Brotato's project height (display/window/size/height)

return table.freeze({
	-- Looks almost straight down, like Brotato (Paket 25, Owner). Not exactly 90: sprites further south must stay a little
	-- nearer to the camera, that keeps them in front of what stands north of them.
	pitchDegrees = 89.5, -- angle between the view direction and the floor (90 = straight down; 50 until Paket 25)
	-- Studs from the character to the camera: shows Brotato's screen, 1920 x 1080 px (1080 px = 108 studs tall at 0.1
	-- studs per pixel), at this field of view (since 09.11.2026; 90 before, set from the owner's screenshot so the
	-- character was 7.7 % of the screen height: now it is 7.5 of 108 studs = 6.9 %, Brotato's own share).
	distance = VIEW_HEIGHT_STUDS / 2 / math.tan(math.rad(FIELD_OF_VIEW) / 2),
	fieldOfView = FIELD_OF_VIEW, -- vertical, degrees
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
