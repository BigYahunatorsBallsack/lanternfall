--!strict
--!native
-- What the fixed camera (CameraController, Config.Camera) can see, for skipping work on things off the screen
-- (Paket 22). The camera never turns: it sits south of its focus point, tilted down by the pitch, so the view is a
-- frustum with known axes and a point test needs no Roblox calls. Used by EnemyRenderer every frame; pure, with
-- unit tests (tests/ViewBounds.spec.luau).

export type ViewBounds = {
	cameraX: number,
	cameraY: number,
	cameraZ: number,
	-- view axes: look (into the screen), up (on the screen); right is +X
	lookY: number,
	lookZ: number,
	upY: number,
	upZ: number,
	tanHalfHeight: number,
	tanHalfWidth: number,
	-- 1 / cos of the half angles: a sphere of radius m is in view while it is m * sec past the edge plane
	secHalfHeight: number,
	secHalfWidth: number,
	valid: boolean,
}

local ViewBounds = {}

function ViewBounds.new(): ViewBounds
	return {
		cameraX = 0,
		cameraY = 0,
		cameraZ = 0,
		lookY = 0,
		lookZ = -1,
		upY = 1,
		upZ = 0,
		tanHalfHeight = 1,
		tanHalfWidth = 1,
		secHalfHeight = 1,
		secHalfWidth = 1,
		valid = false,
	}
end

-- Places the view for a camera `distance` studs from `focus` (x, y, z), tilted down by `pitchDegrees` and looking
-- north (-Z), with a vertical field of view of `fovDegrees` and a screen `aspect` (width / height).
function ViewBounds.update(
	self: ViewBounds,
	focusX: number,
	focusY: number,
	focusZ: number,
	pitchDegrees: number,
	distance: number,
	fovDegrees: number,
	aspect: number
)
	local pitch = math.rad(pitchDegrees)
	local sin, cos = math.sin(pitch), math.cos(pitch)
	self.cameraX = focusX
	self.cameraY = focusY + sin * distance
	self.cameraZ = focusZ + cos * distance
	-- look = (0, -sin, -cos), up = (0, cos, -sin)
	self.lookY, self.lookZ = -sin, -cos
	self.upY, self.upZ = cos, -sin
	self.tanHalfHeight = math.tan(math.rad(fovDegrees) / 2)
	self.tanHalfWidth = self.tanHalfHeight * math.max(aspect, 0.1)
	self.secHalfHeight = math.sqrt(1 + self.tanHalfHeight * self.tanHalfHeight)
	self.secHalfWidth = math.sqrt(1 + self.tanHalfWidth * self.tanHalfWidth)
	self.valid = true
end

-- Whether a point, grown by `margin` studs in every direction, is (partly) on the screen. Without a valid view
-- (no camera yet) everything counts as visible.
function ViewBounds.contains(self: ViewBounds, x: number, y: number, z: number, margin: number): boolean
	if not self.valid then
		return true
	end
	local dx, dy, dz = x - self.cameraX, y - self.cameraY, z - self.cameraZ
	local depth = dy * self.lookY + dz * self.lookZ
	if depth < -margin then
		return false -- behind the camera
	end
	local reach = math.max(depth, 0)
	local side = dx -- right axis is +X
	if math.abs(side) > reach * self.tanHalfWidth + margin * self.secHalfWidth then
		return false
	end
	local height = dy * self.upY + dz * self.upZ
	return math.abs(height) <= reach * self.tanHalfHeight + margin * self.secHalfHeight
end

return ViewBounds
