--!strict
-- Draws enemy and boss projectiles (DESIGN.md section 7) from the server's EnemyShots events: each one is a Brotato
-- style enemy bullet (a solid red ball with a white center in a soft red glow, no trail) that flies in server time
-- from where it was fired and vanishes at its range or where an "ended" entry says it hit a player or an obstacle.
-- Parts are pooled (WeaponRenderer/VisualKit) and moved with one workspace:BulkMoveTo per frame. Active only while
-- the local player is in a running run (RunStateController). The server decides every hit. BossController draws the
-- embers circling a boss with the same look (EnemyShotRenderer.bullet).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local ShotFeed = require(Shared:WaitForChild("Net"):WaitForChild("ShotFeed"))

local RunStateController = require(script.Parent.RunStateController)
local VisualKit = require(script.Parent.WeaponRenderer.VisualKit)
local WorldSprite = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("WorldSprite")
)

local FOLDER_NAME = "LanternfallEnemyShots"
-- The enemy bullet look, measured in Brotato 1.2.0.1 (bullet_enemy picture and its two-color shader, 09.11.2026): a
-- faint red glow out to 29 px, a solid red ball of 20.5 px radius that turns pinkish towards the middle, and a white
-- core of 9.5 px radius. The hit circle there is 17 px. Shares are of the whole picture (58 px, glow included); the
-- pinkish ring is one flat step instead of Brotato's smooth blend. Drawn with plain discs (no picture of theirs).
local PICTURE_PX = 58
local HIT_RADIUS_PX = 17
local GLOW_COLOR = Color3.fromRGB(255, 0, 0)
local GLOW_TRANSPARENCY = 0.55
local BALL_COLOR = Color3.fromRGB(255, 0, 0)
local BALL_SHARE = 41 / PICTURE_PX
local INNER_COLOR = Color3.fromRGB(255, 80, 80)
local INNER_SHARE = 26 / PICTURE_PX
local CORE_COLOR = Color3.fromRGB(255, 255, 255)
local CORE_SHARE = 19 / PICTURE_PX
-- Spitter shots all hit with the same circle; the picture keeps Brotato's size against it.
local spitter = Config.Enemies.types.Spitter
local SHOT_HIT_RADIUS = if spitter and spitter.ranged then spitter.ranged.projectileRadius else 0.6
local HEIGHT = 2 -- studs above the floor
local FADE_STUDS = 4 -- the last studs before the range fade out

export type Bullet = { sprite: WorldSprite.Sprite, discs: { Frame } }
type ShotParts = { bullet: Bullet, core: BasePart }

type Shot = {
	parts: ShotParts?,
	x: number,
	z: number,
	dx: number,
	dz: number,
	speed: number,
	range: number,
	at: number,
	stopAt: number?, -- studs; set by an "ended" entry
}

local EnemyShotRenderer = {}

local shots: { [number]: Shot } = {}
local enabled = false
local folder: Folder? = nil
local floorY = Config.Map.arena.center.Y

-- A round disc of `share` of the picture, drawn crisp (no image, so no upload and no blur).
local function disc(sprite: WorldSprite.Sprite, share: number, color: Color3, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Disc"
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(share, share)
	frame.ZIndex = order
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = sprite.picture
	return frame
end

-- Picture side in studs for a bullet whose hit circle has `hitRadius` studs.
function EnemyShotRenderer.pictureStuds(hitRadius: number): number
	return hitRadius * PICTURE_PX / HIT_RADIUS_PX
end

-- An enemy bullet of `studs` (picture side, glow included) with its own anchor part (Sprite.anchor).
function EnemyShotRenderer.bullet(name: string, studs: number): Bullet
	local sprite = WorldSprite.create({ name = name, image = Config.Sprites.images.glow, studs = studs })
	sprite.picture.ImageColor3 = GLOW_COLOR
	sprite.picture.ImageTransparency = GLOW_TRANSPARENCY
	local discs = {
		disc(sprite, BALL_SHARE, BALL_COLOR, 2),
		disc(sprite, INNER_SHARE, INNER_COLOR, 3),
		disc(sprite, CORE_SHARE, CORE_COLOR, 4),
	}
	return { sprite = sprite, discs = discs }
end

-- Fades a bullet (0 = solid, 1 = gone).
function EnemyShotRenderer.fadeBullet(bullet: Bullet, transparency: number)
	bullet.sprite.picture.ImageTransparency = GLOW_TRANSPARENCY + (1 - GLOW_TRANSPARENCY) * transparency
	for _, frame in bullet.discs do
		frame.BackgroundTransparency = transparency
	end
end

local pool = VisualKit.objectPool(function(): ShotParts
	local bullet = EnemyShotRenderer.bullet("EnemyShot", EnemyShotRenderer.pictureStuds(SHOT_HIT_RADIUS))
	return { bullet = bullet, core = bullet.sprite.anchor :: BasePart }
end, function(parts: ShotParts): { BasePart }
	return { parts.core }
end)

local partList: { BasePart } = {}
local cframeList: { CFrame } = {}
local listLength = 0

local function getFolder(): Folder
	local current = folder
	if current then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = workspace
	folder = created
	return created
end

local function remove(id: number, shot: Shot)
	if shot.parts then
		pool:release(shot.parts)
	end
	shots[id] = nil
end

local function clear()
	for id, shot in shots do
		remove(id, shot)
	end
end

local function onEvents(packet: any)
	if not enabled or typeof(packet) ~= "buffer" then
		return
	end
	local events = ShotFeed.decode(packet)
	if events.reset then
		clear()
	end
	for _, fired in events.fired do
		shots[fired.id] = {
			parts = nil,
			x = fired.x,
			z = fired.z,
			dx = fired.dx,
			dz = fired.dz,
			speed = fired.speed,
			range = fired.range,
			at = fired.at,
			stopAt = nil,
		}
	end
	local ended = events.ended
	for k = 1, #ended, 2 do
		local shot = shots[ended[k]]
		if shot then
			shot.stopAt = ended[k + 1]
		end
	end
end

local function render()
	if not enabled then
		return
	end
	local now = workspace:GetServerTimeNow()
	local count = 0
	for id, shot in shots do
		local distance = math.max(0, shot.speed * (now - shot.at))
		local stop = math.min(shot.range, shot.stopAt or math.huge)
		if distance >= stop then
			remove(id, shot) -- an enemy bullet just vanishes where it hits, as in Brotato
			continue
		end
		local parts = shot.parts
		if not parts then
			local created = pool:acquire(getFolder())
			shot.parts = created
			parts = created
		end
		local current = parts :: ShotParts
		local fade = math.clamp(1 - (shot.range - distance) / FADE_STUDS, 0, 1)
		EnemyShotRenderer.fadeBullet(current.bullet, fade)
		local cframe = CFrame.new(shot.x + shot.dx * distance, floorY + HEIGHT, shot.z + shot.dz * distance)
		count += 1
		partList[count] = current.core
		cframeList[count] = cframe
	end
	for k = count + 1, listLength do
		partList[k] = nil
		cframeList[k] = nil
	end
	listLength = count
	if count > 0 then
		workspace:BulkMoveTo(partList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function setEnabled(value: boolean)
	if value == enabled then
		return
	end
	enabled = value
	if not value then
		clear()
	end
end

-- Lifecycle -------------------------------------------------------------------------

function EnemyShotRenderer.init()
	Net.onClient("EnemyShots", onEvents)
	RunStateController.Changed:Connect(function()
		setEnabled(RunStateController.getView() == "Run")
	end)
end

function EnemyShotRenderer.start()
	setEnabled(RunStateController.getView() == "Run")
	RunService.RenderStepped:Connect(render)
end

-- Queries ---------------------------------------------------------------------------

-- Enemy projectiles on screen right now.
function EnemyShotRenderer.getCount(): number
	local count = 0
	for _ in shots do
		count += 1
	end
	return count
end

return EnemyShotRenderer
