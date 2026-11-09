--!strict
-- Thick dark outline around the game's pictures in every menu and HUD (portraits, weapons, items, stats, crates,
-- shards), like the world sprites (owner, 09.11.2026). Watches the PlayerGui and outlines any ImageLabel or ImageButton
-- that shows one of those pictures; loaded by the client controller loader. World billboards are left to WorldSprite.
--
-- Screens use sibling ZIndex, where children always draw over their parent. So the outline is drawn on top of the
-- picture as its own children: dark copies shifted in a ring, then one plain copy over them that hides the picture's
-- own drawing in the middle. Image, crop, color and fade of the picture are copied whenever they change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SpriteImages = require(Shared:WaitForChild("Config"):WaitForChild("SpriteImages"))
local UI = script.Parent.Parent:WaitForChild("UI")

local Look = Config.Sprites.outline
local OUTLINE_COLOR = Color3.fromRGB(table.unpack(Look.color))
local RING_NAME = "UiOutline"
local FACE_NAME = "UiOutlineFace"
local RING_ORDER = -2 -- below any child the picture already has (badges, counters)
local FACE_ORDER = -1
local SHAPE = { "Image", "ImageRectOffset", "ImageRectSize", "ScaleType", "SliceCenter", "ResampleMode" }
local FACE_ONLY = { "ImageColor3" }
local SHARED = { "ImageTransparency" }

local UiOutlineController = {}

local outlined: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local wanted: { [string]: boolean } = {}

local function want(value: any)
	if typeof(value) == "string" and value ~= "" then
		wanted[value] = true
	elseif typeof(value) == "table" then
		for _, inner in value do
			want(if typeof(inner) == "table" and inner.image then inner.image else inner)
		end
	end
end

local function collect()
	for _, name in { "CharacterPortraits", "WeaponImages", "ItemImages", "StatImages", "PrimaryStatArt" } do
		local module = UI:FindFirstChild(name)
		if module then
			local ok, images = pcall(require, module)
			if ok then
				want(images)
			end
		end
	end
	want(SpriteImages.pickups)
	want(SpriteImages.structures)
	want(Config.Sprites.images.material)
	want(Config.Sprites.material.variants)
end

-- Unit steps around a circle, one per dark copy.
local steps: { Vector2 } = {}
for index = 1, Look.directions do
	local angle = (index - 1) / Look.directions * 2 * math.pi
	table.insert(steps, Vector2.new(math.cos(angle), math.sin(angle)))
end

local function copyLabel(name: string, order: number, color: Color3?): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.ZIndex = order
	if color then
		label.ImageColor3 = color
	end
	return label
end

local function outline(picture: ImageLabel | ImageButton)
	outlined[picture] = true
	local ring: { ImageLabel } = {}
	for _, step in steps do
		local label = copyLabel(RING_NAME, RING_ORDER, OUTLINE_COLOR)
		label.Position = UDim2.fromScale(0.5 + step.X * Look.uiShare, 0.5 + step.Y * Look.uiShare)
		label.Parent = picture
		table.insert(ring, label)
	end
	local face = copyLabel(FACE_NAME, FACE_ORDER)
	face.Parent = picture
	local all = table.clone(ring)
	table.insert(all, face)

	local function copy(property: string, targets: { ImageLabel })
		local value = (picture :: any)[property]
		for _, label in targets do
			(label :: any)[property] = value
		end
	end
	local function refresh()
		local shown = wanted[picture.Image] == true
		for _, label in all do
			label.Visible = shown
		end
	end
	for _, property in SHAPE do
		copy(property, all)
		picture:GetPropertyChangedSignal(property):Connect(function()
			copy(property, all)
		end)
	end
	for _, property in SHARED do
		copy(property, all)
		picture:GetPropertyChangedSignal(property):Connect(function()
			copy(property, all)
		end)
	end
	for _, property in FACE_ONLY do
		copy(property, { face })
		picture:GetPropertyChangedSignal(property):Connect(function()
			copy(property, { face })
		end)
	end
	refresh()
	picture:GetPropertyChangedSignal("Image"):Connect(refresh)
end

local function inWorld(instance: Instance): boolean
	return instance:FindFirstAncestorWhichIsA("BillboardGui") ~= nil
		or instance:FindFirstAncestorWhichIsA("SurfaceGui") ~= nil
end

local function consider(instance: Instance)
	if not (instance:IsA("ImageLabel") or instance:IsA("ImageButton")) then
		return
	end
	if outlined[instance] or instance.Name == RING_NAME or instance.Name == FACE_NAME or inWorld(instance) then
		return
	end
	local picture = instance :: ImageLabel | ImageButton
	if wanted[picture.Image] then
		outline(picture)
		return
	end
	-- Pictures are often filled in after they are made.
	local connection: RBXScriptConnection? = nil
	connection = picture:GetPropertyChangedSignal("Image"):Connect(function()
		if wanted[picture.Image] and not outlined[picture] then
			if connection then
				connection:Disconnect()
			end
			outline(picture)
		end
	end)
end

function UiOutlineController.start()
	collect()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, instance in playerGui:GetDescendants() do
		consider(instance)
	end
	playerGui.DescendantAdded:Connect(consider)
end

-- Pictures that carry an outline right now (tests).
function UiOutlineController.getCount(): number
	local count = 0
	for _ in outlined do
		count += 1
	end
	return count
end

return UiOutlineController
