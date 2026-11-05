--!strict
-- The one way to draw something 2D in the world (DESIGN.md section 14): a picture that always faces the camera, stands
-- with its ground line on an anchor point and is hidden by walls in front of it (no AlwaysOnTop). Used by the character,
-- enemy, pickup, orb, shot, chest and structure renderers and on the server by CosmeticService and LobbyArtService (their
-- sprites replicate to everyone). Moving a sprite means moving its anchor part, so renderers
-- keep using workspace:BulkMoveTo; pose() squashes, turns and mirrors the picture without touching the anchor.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Look = require(Shared:WaitForChild("Config"):WaitForChild("Sprites"))

export type Spec = {
	name: string,
	image: string,
	studs: number,
	ground: number?, -- default 0.5: the anchor is the middle of the picture
	center: number?, -- default 0.5
	pixels: number?, -- image side in pixels, needed by setFlip
}

export type Sprite = {
	anchor: BasePart?, -- nil when attached to a part of someone else
	gui: BillboardGui,
	picture: ImageLabel,
	studs: number,
	ground: number,
	center: number,
	pixels: number?,
	flipped: boolean,
	scaleX: number,
	scaleY: number,
	rotation: number,
	layers: { ImageLabel },
}

local WorldSprite = {}

-- Size and placement of billboard and picture for the sprite's size; pose() scales around the ground point.
local function layout(sprite: Sprite)
	local side = sprite.studs * Look.canvasMargin
	local padding = (side - sprite.studs) / 2
	local groundFromBottom = padding + sprite.ground * sprite.studs
	sprite.gui.Size = UDim2.fromScale(side, side)
	sprite.gui.StudsOffset = Vector3.new(0, side / 2 - groundFromBottom, Look.depthBias)
	sprite.picture.Position = UDim2.fromScale(0.5, 1 - groundFromBottom / side)
end

local function anchorPoint(sprite: Sprite): Vector2
	return Vector2.new(if sprite.flipped then 1 - sprite.center else sprite.center, 1 - sprite.ground)
end

local function resize(sprite: Sprite)
	local share = 1 / Look.canvasMargin
	sprite.picture.Size = UDim2.fromScale(share * sprite.scaleX, share * sprite.scaleY)
end

local function build(adornee: BasePart, spec: Spec): Sprite
	local gui = Instance.new("BillboardGui")
	gui.Name = spec.name
	gui.Adornee = adornee
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.Image = spec.image
	picture.ScaleType = Enum.ScaleType.Stretch
	picture.Parent = gui
	local sprite: Sprite = {
		anchor = nil,
		gui = gui,
		picture = picture,
		studs = spec.studs,
		ground = spec.ground or 0.5,
		center = spec.center or 0.5,
		pixels = spec.pixels,
		flipped = false,
		scaleX = 1,
		scaleY = 1,
		rotation = 0,
		layers = {},
	}
	picture.AnchorPoint = anchorPoint(sprite)
	layout(sprite)
	resize(sprite)
	return sprite
end

-- A sprite with its own invisible anchor part (parent the anchor to show it, move the anchor to move it).
function WorldSprite.create(spec: Spec): Sprite
	local anchor = Instance.new("Part")
	anchor.Name = spec.name
	anchor.Size = Vector3.new(0.12, 0.12, 0.12)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	local sprite = build(anchor, spec)
	sprite.anchor = anchor
	sprite.gui.Parent = anchor
	return sprite
end

-- A sprite that follows a part it does not own; `drop` lowers the ground line below the part (a character's feet).
function WorldSprite.attach(adornee: BasePart, parent: Instance, spec: Spec, drop: number?): Sprite
	local sprite = build(adornee, spec)
	sprite.gui.StudsOffsetWorldSpace = Vector3.new(0, -(drop or 0), 0)
	sprite.gui.Parent = parent
	return sprite
end

-- A second picture in the same sprite, centered on the first, `share` as large (a white core inside a glow).
function WorldSprite.addLayer(sprite: Sprite, image: string, share: number, color: Color3?, order: number?): ImageLabel
	local layer = Instance.new("ImageLabel")
	layer.Name = "Layer"
	layer.BackgroundTransparency = 1
	layer.Image = image
	layer.AnchorPoint = Vector2.new(0.5, 0.5)
	layer.Position = UDim2.fromScale(0.5, 0.5)
	layer.Size = UDim2.fromScale(share, share)
	layer.ImageColor3 = color or Color3.new(1, 1, 1)
	layer.ZIndex = order or 2
	layer.Parent = sprite.picture
	table.insert(sprite.layers, layer)
	return layer
end

function WorldSprite.setImage(sprite: Sprite, spec: Spec)
	sprite.picture.Image = spec.image
	sprite.studs = spec.studs
	sprite.ground = spec.ground or 0.5
	sprite.center = spec.center or 0.5
	sprite.pixels = spec.pixels
	sprite.picture.AnchorPoint = anchorPoint(sprite)
	layout(sprite)
	WorldSprite.applyFlip(sprite)
end

-- A new size in studs at runtime (growing blasts, XP orbs of different value).
function WorldSprite.setStuds(sprite: Sprite, studs: number)
	if sprite.studs ~= studs then
		sprite.studs = studs
		layout(sprite)
	end
end

-- Writes the mirrored or plain image rectangle (a negative rectangle draws the image mirrored).
function WorldSprite.applyFlip(sprite: Sprite)
	local pixels = sprite.pixels
	if not pixels then
		return
	end
	if sprite.flipped then
		sprite.picture.ImageRectOffset = Vector2.new(pixels, 0)
		sprite.picture.ImageRectSize = Vector2.new(-pixels, pixels)
	else
		sprite.picture.ImageRectOffset = Vector2.zero
		sprite.picture.ImageRectSize = Vector2.new(pixels, pixels)
	end
	sprite.picture.AnchorPoint = anchorPoint(sprite)
end

function WorldSprite.setFlip(sprite: Sprite, flipped: boolean)
	if sprite.flipped ~= flipped then
		sprite.flipped = flipped
		WorldSprite.applyFlip(sprite)
	end
end

-- Squash, stretch and sway around the ground point. Writes only what changed noticeably, so crowds stay cheap.
function WorldSprite.pose(sprite: Sprite, scaleX: number, scaleY: number, rotation: number)
	if
		math.abs(scaleX - sprite.scaleX) >= Look.poseScaleStep
		or math.abs(scaleY - sprite.scaleY) >= Look.poseScaleStep
	then
		sprite.scaleX, sprite.scaleY = scaleX, scaleY
		resize(sprite)
	end
	if math.abs(rotation - sprite.rotation) >= Look.poseRotationStep then
		sprite.rotation = rotation
		sprite.picture.Rotation = rotation
	end
end

-- Multiplies the picture with `color`; `brightness` above 1 washes it out towards white (hit flashes).
function WorldSprite.setTint(sprite: Sprite, color: Color3, brightness: number?)
	sprite.picture.ImageColor3 = color
	sprite.gui.Brightness = brightness or 1
end

function WorldSprite.setVisible(sprite: Sprite, visible: boolean)
	sprite.gui.Enabled = visible
end

-- Rotation in degrees that turns a picture pointing right towards world direction (dx, dz) as seen on the screen.
function WorldSprite.screenAngle(dx: number, dz: number): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 0
	end
	local frame = camera.CFrame
	local facing = Vector3.new(dx, 0, dz)
	return math.deg(math.atan2(-facing:Dot(frame.UpVector), facing:Dot(frame.RightVector)))
end

-- A soft glowing dot of `studs` in `color` with a white-hot core: bolts, shots, wisps, blasts.
function WorldSprite.glow(name: string, studs: number, color: Color3, coreShare: number?): Sprite
	local sprite = WorldSprite.create({ name = name, image = Look.images.glow, studs = studs })
	sprite.picture.ImageColor3 = color
	if coreShare then
		WorldSprite.addLayer(sprite, Look.images.glow, coreShare)
	end
	return sprite
end

-- Fades the picture and its layers (0 = solid, 1 = gone); layers keep their relative strength to the picture.
function WorldSprite.setFade(sprite: Sprite, transparency: number)
	sprite.picture.ImageTransparency = transparency
	for _, layer in sprite.layers do
		layer.ImageTransparency = transparency
	end
end

function WorldSprite.destroy(sprite: Sprite)
	local anchor = sprite.anchor
	if anchor then
		anchor:Destroy()
	else
		sprite.gui:Destroy()
	end
end

return WorldSprite
