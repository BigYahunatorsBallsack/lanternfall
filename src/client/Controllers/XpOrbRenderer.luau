--!strict
-- Draws materials from the server's XpOrbs events (ExperienceService): pooled green shard sprites
-- on the floor, sized by how much XP they hold, each with its own picture, turn and mirror (Util/MaterialLook),
-- that fly into the player who picked them up. Lying materials are placed once; only flying ones move each frame, together in one workspace:BulkMoveTo. A material that
-- took from the bag lies 1.25 times bigger (XpOrbEvents.bagOrbs); one that counted more than once (bag or Double Orbs,
-- XpOrbEvents.boosted) shows a small green "X2" where it reaches the
-- player, like Brotato (Config.Feedback.materialBoost). The server decides every pickup; this only shows it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Theme = require(script.Parent.Parent.UI.Theme)
local VisualKit = require(script.Parent.WeaponRenderer.VisualKit)
local MaterialLook = require(Shared:WaitForChild("Util"):WaitForChild("MaterialLook"))
local WorldSprite = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("WorldSprite")
)

local FOLDER_NAME = "LanternfallXpOrbs"
local FLY_SECONDS = 0.25
local HOVER = Config.Sprites.material.hover
-- Looks by XP value: the last tier with minValue <= value applies.
local TIERS = Config.Sprites.material.tiers
local LOOK = Config.Sprites.material
local VARIANTS: { string } = if #LOOK.variants > 0 then LOOK.variants else { Config.Sprites.images.material }

local BOOST = Config.Feedback.materialBoost
local BOOST_COLOR = Color3.fromRGB(BOOST.color[1], BOOST.color[2], BOOST.color[3])

type Orb = { part: BasePart, x: number, z: number, scale: number, bag: boolean }
type Flight = { part: BasePart, from: Vector3, userId: number, startedAt: number, factor: number }
type Popup = {
	gui: BillboardGui,
	label: TextLabel,
	stroke: UIStroke,
	scale: UIScale,
	startedAt: number,
	dx: number,
	dy: number,
}

local XpOrbRenderer = {}

local floorY = Config.Map.arena.center.Y
local folder: Folder? = nil
local spriteOf: { [BasePart]: WorldSprite.Sprite } = {}
local pool = VisualKit.pool(function(): BasePart
	local sprite = WorldSprite.create({
		name = "XpOrb",
		image = Config.Sprites.images.material,
		studs = TIERS[1].size,
		depth = LOOK.depthBias,
	})
	WorldSprite.outline(sprite)
	local anchor = sprite.anchor :: BasePart
	spriteOf[anchor] = sprite
	return anchor
end)
local orbs: { [number]: Orb } = {}
local flights: { Flight } = {}
local factorOf: { [number]: number } = {} -- reused: orb id -> how often it counted (XpOrbEvents.boosted)
local bagIds: { [number]: boolean } = {} -- reused: ids in XpOrbEvents.bagOrbs
local popups: { Popup } = {} -- oldest first
local popupPool: { Popup } = {}
local popupAnchor: BasePart? = nil
local popupAnchorPosition = Vector3.new(0, floorY, 0)
local rng = Random.new()

-- Reused lists for workspace:BulkMoveTo.
local partList: { BasePart } = {}
local cframeList: { CFrame } = {}

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

local function tierOf(value: number)
	local chosen = TIERS[1]
	for _, tier in TIERS do
		if value >= tier.minValue then
			chosen = tier
		end
	end
	return chosen
end

local function rootPosition(userId: number): Vector3?
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

-- Robert Penner's elastic easing as Godot's Tween uses it (TRANS_ELASTIC), for a time 0..1 and duration 1.
local ELASTIC_PERIOD = 0.3
local function elasticOut(t: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	local s = ELASTIC_PERIOD / 4
	return 2 ^ (-10 * t) * math.sin((t - s) * 2 * math.pi / ELASTIC_PERIOD) + 1
end

local function elasticInOut(t: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	local period = ELASTIC_PERIOD * 1.5
	local s = period / 4
	local u = t * 2 - 1
	if u < 0 then
		return -0.5 * 2 ^ (10 * u) * math.sin((u - s) * 2 * math.pi / period)
	end
	return 0.5 * 2 ^ (-10 * u) * math.sin((u - s) * 2 * math.pi / period) + 1
end

local function getPopupAnchor(): BasePart
	local current = popupAnchor
	if current then
		return current
	end
	local part = Instance.new("Part")
	part.Name = "BoostTextAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.CFrame = CFrame.new(popupAnchorPosition)
	part.Parent = getFolder()
	popupAnchor = part
	return part
end

local function buildPopup(): Popup
	local gui = Instance.new("BillboardGui")
	gui.Name = "BoostText"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 0.5)
	label.Font = Theme.fontBold
	label.TextColor3 = BOOST_COLOR
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Parent = label
	return { gui = gui, label = label, stroke = stroke, scale = scale, startedAt = 0, dx = 0, dy = 0 }
end

-- Pooled texts stay enabled and parented and hide their label: a BillboardGui switched back on is drawn a few frames
-- at its old position (engine quirk).
local function releasePopup(popup: Popup)
	popup.label.Visible = false
	table.insert(popupPool, popup)
end

-- Brotato's FloatingText: jumps risePixels up (turned within the spread) with an elastic ease, then shrinks and fades.
local function showBoost(at: Vector3, factor: number)
	if not BOOST.enabled then
		return
	end
	if #popups >= BOOST.maxVisible then
		releasePopup(table.remove(popups, 1) :: Popup)
	end
	local camera = workspace.CurrentCamera
	local pixel = (if camera then camera.ViewportSize.Y else BOOST.referenceHeight) / BOOST.referenceHeight
	local popup = table.remove(popupPool) or buildPopup()
	local anchor = getPopupAnchor()
	local side = (BOOST.risePixels + BOOST.textSize) * pixel * 2
	popup.gui.Size = UDim2.fromOffset(side, side)
	popup.gui.StudsOffsetWorldSpace = at - popupAnchorPosition
	popup.gui.Adornee = anchor
	popup.label.Text = `X{factor}`
	popup.label.TextSize = BOOST.textSize * pixel
	popup.label.TextTransparency = 0
	popup.label.Position = UDim2.fromScale(0.5, 0.5)
	popup.stroke.Thickness = BOOST.outline * pixel
	popup.stroke.Transparency = 0
	popup.scale.Scale = 1
	local turn = math.rad(rng:NextNumber(-BOOST.spreadDegrees / 2, BOOST.spreadDegrees / 2))
	popup.dx = BOOST.risePixels * pixel * math.sin(turn)
	popup.dy = -BOOST.risePixels * pixel * math.cos(turn)
	popup.startedAt = os.clock()
	if popup.gui.Parent == nil then
		popup.gui.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end
	popup.label.Visible = true
	table.insert(popups, popup)
end

local function animatePopups()
	if #popups == 0 then
		return
	end
	local now = os.clock()
	for i = #popups, 1, -1 do
		local popup = popups[i]
		local t = (now - popup.startedAt) / BOOST.seconds
		if t >= 2 then
			table.remove(popups, i)
			releasePopup(popup)
		elseif t < 1 then
			local f = elasticOut(t)
			popup.label.Position = UDim2.new(0.5, popup.dx * f, 0.5, popup.dy * f)
		else
			local fade = t - 1
			popup.label.Position = UDim2.new(0.5, popup.dx, 0.5, popup.dy)
			popup.scale.Scale = math.max(0, 1 - elasticInOut(fade))
			popup.label.TextTransparency = fade
			popup.stroke.Transparency = fade
		end
	end
end

local function clear()
	for _, orb in orbs do
		pool:release(orb.part)
	end
	for _, flight in flights do
		pool:release(flight.part)
	end
	table.clear(orbs)
	table.clear(flights)
end

local function flushMoves()
	if #partList > 0 then
		workspace:BulkMoveTo(partList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(partList)
		table.clear(cframeList)
	end
end

local function onEvents(events: Types.XpOrbEvents)
	if typeof(events) ~= "table" then
		return
	end
	if events.reset then
		clear()
	end
	table.clear(bagIds)
	local bagOrbs = events.bagOrbs
	if typeof(bagOrbs) == "table" then
		for _, id in bagOrbs do
			bagIds[id] = true
		end
	end
	local list = events.orbs
	for i = 1, #list - 3, 4 do
		local id, x, z, value = list[i], list[i + 1], list[i + 2], list[i + 3]
		local orb = orbs[id]
		local sprite
		if not orb then
			local look = MaterialLook.of(id, #VARIANTS, LOOK)
			orb = { part = pool:acquire(getFolder()), x = x, z = z, scale = look.scale, bag = false }
			orbs[id] = orb
			sprite = spriteOf[orb.part]
			sprite.picture.Image = VARIANTS[look.variant]
			sprite.pixels = LOOK.pixels
			WorldSprite.setFlip(sprite, look.flipped)
			WorldSprite.applyFlip(sprite)
			WorldSprite.pose(sprite, 1, 1, look.rotation)
		else
			sprite = spriteOf[orb.part]
		end
		if bagIds[id] then
			orb.bag = true
		end
		local tier = tierOf(value)
		local bagScale = if orb.bag then BOOST.bagOrbScale else 1
		WorldSprite.setStuds(sprite, tier.size * Config.Sprites.orbScale * orb.scale * bagScale)
		sprite.picture.ImageColor3 = Color3.new(1, 1, 1)
		table.insert(partList, orb.part)
		table.insert(cframeList, CFrame.new(x, floorY + HOVER + tier.size / 2, z))
	end
	flushMoves()
	local now = workspace:GetServerTimeNow()
	table.clear(factorOf)
	local boosted = events.boosted
	if typeof(boosted) == "table" then
		for i = 1, #boosted - 1, 2 do
			factorOf[boosted[i]] = boosted[i + 1]
		end
	end
	local collected = events.collected
	for i = 1, #collected - 1, 2 do
		local id, userId = collected[i], collected[i + 1]
		local orb = orbs[id]
		if orb then
			orbs[id] = nil
			table.insert(flights, {
				part = orb.part,
				from = orb.part.Position,
				userId = userId,
				startedAt = now,
				factor = factorOf[id] or 1,
			})
		end
	end
end

local function render()
	animatePopups()
	if #flights == 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	for i = #flights, 1, -1 do
		local flight = flights[i]
		local t = (now - flight.startedAt) / FLY_SECONDS
		local target = rootPosition(flight.userId)
		if t >= 1 or not target then
			if target and flight.factor > 1 then
				showBoost(target, flight.factor)
			end
			pool:release(flight.part)
			table.remove(flights, i)
		else
			table.insert(partList, flight.part)
			table.insert(cframeList, CFrame.new(flight.from + (target - flight.from) * (t * t)))
		end
	end
	flushMoves()
end

-- Lifecycle -------------------------------------------------------------------------

function XpOrbRenderer.init()
	Net.onClient("XpOrbs", onEvents)
end

function XpOrbRenderer.start()
	RunService.RenderStepped:Connect(render)
end

-- How many lying materials are drawn bigger because they took from the bag (tests).
function XpOrbRenderer.getBagOrbCount(): number
	local count = 0
	for _, orb in orbs do
		if orb.bag then
			count += 1
		end
	end
	return count
end

-- Texts of the "X2" popups showing right now (tests).
function XpOrbRenderer.getBoostTexts(): { string }
	local texts = {}
	for _, popup in popups do
		table.insert(texts, popup.label.Text)
	end
	return texts
end

-- Orbs lying on the floor and orbs flying to a player (smoke test).
function XpOrbRenderer.getCounts(): (number, number)
	local lying = 0
	for _ in orbs do
		lying += 1
	end
	return lying, #flights
end

return XpOrbRenderer
