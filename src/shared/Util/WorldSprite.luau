--!strict
-- The one way to draw something 2D in the world (DESIGN.md section 14): a picture that always faces the camera, stands
-- with its ground line on an anchor point and is hidden by walls in front of it (no AlwaysOnTop). Used by the character,
-- enemy, pickup, orb, shot, chest and structure renderers and on the server by CosmeticService and LobbyArtService (their
-- sprites replicate to everyone). Moving a sprite means moving its anchor part, so renderers
-- keep using workspace:BulkMoveTo; pose() squashes, turns and mirrors the picture without touching the anchor.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Look = require(Shared:WaitForChild("Config"):WaitForChild("Sprites"))
local Outline = Look.outline
local OUTLINE_COLOR = Color3.fromRGB(table.unpack(Outline.color))
local OUTLINE_ORDER = 0 -- behind every picture (feet 1, bodies and items 2)
local OUTLINE_COPIED = { "Image", "ImageRectOffset", "ImageRectSize", "ImageTransparency", "ScaleType" }

-- Unit steps around a circle, one per dark copy of an outline.
local outlineSteps: { Vector2 } = {}
for index = 1, Outline.directions do
	local angle = (index - 1) / Outline.directions * 2 * math.pi
	table.insert(outlineSteps, Vector2.new(math.cos(angle), math.sin(angle)))
end

export type Spec = {
	name: string,
	image: string,
	studs: number,
	ground: number?, -- default 0.5: the anchor is the middle of the picture
	center: number?, -- default 0.5
	pixels: number?, -- image side in pixels, needed by setFlip
	depth: number?, -- studs towards the camera, default Config/Sprites depthBias; less draws it behind other sprites
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
	lift: number, -- studs up the screen, a hop
	layers: { ImageLabel },
	outline: { ImageLabel }?, -- dark copies behind the picture, see WorldSprite.outline
	depth: number, -- studs towards the camera
}

local WorldSprite = {}

-- Side of the billboard in studs and how far the ground line is above its bottom.
local function canvas(sprite: Sprite): (number, number)
	local side = sprite.studs * Look.canvasMargin
	return side, (side - sprite.studs) / 2 + sprite.ground * sprite.studs
end

-- Puts the picture on the ground line. A picture turns around its middle, so the middle moves along to keep the feet
-- where they are.
local function place(sprite: Sprite)
	local side, groundFromBottom = canvas(sprite)
	local angle = math.rad(sprite.rotation)
	local toMiddle = sprite.studs * (0.5 - sprite.ground) * sprite.scaleY
	local shiftX = math.sin(angle) * toMiddle
	local shiftDown = (1 - math.cos(angle)) * toMiddle
	sprite.picture.Position =
		UDim2.fromScale(0.5 + shiftX / side, 1 - groundFromBottom / side + (shiftDown - sprite.lift) / side)
end

-- Size and placement of billboard and picture for the sprite's size; pose() scales around the ground point.
local function layout(sprite: Sprite)
	local side, groundFromBottom = canvas(sprite)
	sprite.gui.Size = UDim2.fromScale(side, side)
	sprite.gui.StudsOffset = Vector3.new(0, side / 2 - groundFromBottom, sprite.depth)
	place(sprite)
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
	picture.ZIndex = 2
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
		lift = 0,
		layers = {},
		outline = nil,
		depth = spec.depth or Look.depthBias,
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
	WorldSprite.spreadOutline(sprite.outline, Outline.studs / sprite.studs)
end

-- A new size in studs at runtime (growing blasts, XP orbs of different value).
function WorldSprite.setStuds(sprite: Sprite, studs: number)
	if sprite.studs ~= studs then
		sprite.studs = studs
		layout(sprite)
		WorldSprite.spreadOutline(sprite.outline, Outline.studs / studs)
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

-- Squash, stretch and sway around the ground point, `lift` studs up the screen. Writes only what changed noticeably, so
-- crowds stay cheap.
function WorldSprite.pose(sprite: Sprite, scaleX: number, scaleY: number, rotation: number, lift: number?)
	local moved = false
	if
		math.abs(scaleX - sprite.scaleX) >= Look.poseScaleStep
		or math.abs(scaleY - sprite.scaleY) >= Look.poseScaleStep
	then
		sprite.scaleX, sprite.scaleY = scaleX, scaleY
		resize(sprite)
		moved = true
	end
	if math.abs(rotation - sprite.rotation) >= Look.poseRotationStep then
		sprite.rotation = rotation
		sprite.picture.Rotation = rotation
		moved = true
	end
	local up = lift or 0
	if math.abs(up - sprite.lift) >= Look.poseScaleStep then
		sprite.lift = up
		moved = true
	end
	if moved then
		place(sprite)
	end
end

-- Where a point of the ground line lies on the billboard, as UDim2 scale: `x` studs to the side, `up` studs above it.
function WorldSprite.groundPoint(sprite: Sprite, x: number, up: number): UDim2
	local side, groundFromBottom = canvas(sprite)
	return UDim2.fromScale(0.5 + x / side, 1 - (groundFromBottom + up) / side)
end

-- `studs` as a share of the billboard, for pictures placed on it by hand.
function WorldSprite.share(sprite: Sprite, studs: number): number
	return studs / (sprite.studs * Look.canvasMargin)
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
function WorldSprite.glow(name: string, studs: number, color: Color3, coreShare: number?, depth: number?): Sprite
	local sprite = WorldSprite.create({ name = name, image = Look.images.glow, studs = studs, depth = depth })
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

-- Places the dark copies of an outline `share` of the picture's size away from it.
function WorldSprite.spreadOutline(labels: { ImageLabel }?, share: number)
	if not labels then
		return
	end
	for index, label in labels do
		local step = outlineSteps[index]
		label.Position = UDim2.fromScale(0.5 + step.X * share, 0.5 + step.Y * share)
	end
end

-- Thick dark outline behind any picture: dark copies of it shifted in a ring, `share` of its size away. The copies are
-- its children, so they move, scale and turn with it wherever it is posed; image, mirroring and fade are copied
-- whenever they change. Its billboard switches to global ZIndex so the copies draw behind every picture on it.
function WorldSprite.outlinePicture(picture: ImageLabel, share: number): { ImageLabel }
	local gui = picture:FindFirstAncestorWhichIsA("LayerCollector")
	if gui then
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	end
	local labels: { ImageLabel } = {}
	for _ = 1, #outlineSteps do
		local label = Instance.new("ImageLabel")
		label.Name = "Outline"
		label.BackgroundTransparency = 1
		label.ImageColor3 = OUTLINE_COLOR
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromScale(1, 1)
		label.ZIndex = OUTLINE_ORDER
		label.Parent = picture
		table.insert(labels, label)
	end
	WorldSprite.spreadOutline(labels, share)
	local function copy(property: string)
		local value = (picture :: any)[property]
		for _, label in labels do
			(label :: any)[property] = value
		end
	end
	for _, property in OUTLINE_COPIED do
		copy(property)
		picture:GetPropertyChangedSignal(property):Connect(function()
			copy(property)
		end)
	end
	return labels
end

-- Gives a sprite the thick dark outline (Config/Sprites outline); sizes and images set later keep it right.
function WorldSprite.outline(sprite: Sprite)
	if not sprite.outline then
		sprite.outline = WorldSprite.outlinePicture(sprite.picture, Outline.studs / sprite.studs)
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
