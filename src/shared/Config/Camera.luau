--!strict
-- Fixed top-down camera (DESIGN.md section 4). Read by CameraController.

return table.freeze({
	pitchDegrees = 50, -- angle between the view direction and the floor (90 = straight down)
	distance = 70, -- studs from the character to the camera
	fieldOfView = 40, -- vertical, degrees
	followSharpness = 12, -- how quickly the camera catches up with the character (higher = tighter)
	targetHeightOffset = 0, -- studs above the HumanoidRootPart the camera looks at
})
