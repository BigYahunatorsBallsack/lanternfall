--!strict
-- Gives every player's character one 2D sprite on this device and hides the avatar once the sprite image has loaded (the
-- avatar stays visible if it never does); called by CharacterAnimationController.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Look = require(Shared.Config.Sprites).character
local ShadowLook = require(Shared.Config.Sprites).shadow
local Foot = Look.foot
local FootImage = require(Shared.Config.Sprites).images.foot
local WorldSprite = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("WorldSprite")
)

local CLASS_ATTRIBUTE = "LanternfallClassId"
local HOLDER_NAME = "LanternfallCharacterSprites"
local SHADOW_FOLDER_NAME = "LanternfallCharacterShadows"
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

export type Entry = {
	character: Model,
	root: BasePart,
	humanoid: Humanoid?,
	sprite: WorldSprite.Sprite,
	shadow: BasePart,
	feet: { ImageLabel },
	drop: number, -- from the root part down to the feet
	classId: string?, -- the class the sprite shows
	loading: string?, -- the class being loaded
	ready: boolean,
	attempts: number,
	nextTry: number,
	hidden: { [Instance]: number },
	connection: RBXScriptConnection?,
}

local entries: { [Player]: Entry } = {}
local holder: Folder? = nil
local shadowFolder: Folder? = nil
local Visibility = {}

local nativeNames: { [string]: boolean } = {
	Head = true,
	UpperTorso = true,
	LowerTorso = true,
	Torso = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}

local function getHolder(): Folder
	local current = holder
	if current then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = HOLDER_NAME
	created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	holder = created
	return created
end

-- The flat disc under a character, like the enemies' (shown once the sprite is, moved by placeShadow).
local function makeShadow(): BasePart
	local folder = shadowFolder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = SHADOW_FOLDER_NAME
		folder.Parent = workspace
		shadowFolder = folder
	end
	local look = ShadowLook
	local part = Instance.new("Part")
	part.Name = "CharacterShadow"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(look.thickness, Look.shadowStuds, Look.shadowStuds)
	part.Color = Color3.fromRGB(table.unpack(look.color))
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder
	return part
end

local function makeFoot(sprite: WorldSprite.Sprite, name: string): ImageLabel
	local foot = Instance.new("ImageLabel")
	foot.Name = name
	foot.BackgroundTransparency = 1
	foot.Image = FootImage
	foot.AnchorPoint = Vector2.new(0.5, 0.5)
	foot.ZIndex = 1 -- behind the body
	foot.Parent = sprite.gui
	return foot
end

-- Keeps the feet under the character: `phase` is the step (radians), `amount` 0 when standing and 1 when walking.
function Visibility.poseFeet(entry: Entry, phase: number, amount: number, shown: boolean)
	local sprite = entry.sprite
	local share = WorldSprite.share(sprite, Foot.studs)
	local wave, swing = math.sin(phase), math.cos(phase)
	for index, foot in entry.feet do
		foot.Visible = shown
		local side = if index == 1 then -1 else 1
		local step = wave * side
		local up = math.max(0, step) * Foot.lift * amount
		local x = side * Foot.spread + swing * side * Foot.stride * amount
		foot.Size = UDim2.fromScale(share, share)
		foot.Position = WorldSprite.groundPoint(sprite, x, up)
	end
end

local function hideNative(entry: Entry, instance: Instance)
	if instance:IsA("BasePart") then
		if
			(instance.Parent == entry.character and nativeNames[instance.Name])
			or instance:FindFirstAncestorWhichIsA("Accessory")
		then
			if entry.hidden[instance] == nil then
				entry.hidden[instance] = instance.LocalTransparencyModifier
			end
			instance.LocalTransparencyModifier = 1
		end
	elseif instance:IsA("Decal") and instance.Parent and instance.Parent.Name == "Head" then
		if entry.hidden[instance] == nil then
			entry.hidden[instance] = instance.Transparency
		end
		instance.Transparency = 1
	end
end

function Visibility.forget(player: Player)
	local entry = entries[player]
	if not entry then
		return
	end
	entries[player] = nil
	if entry.connection then
		entry.connection:Disconnect()
	end
	WorldSprite.destroy(entry.sprite)
	entry.shadow:Destroy()
	for instance, value in entry.hidden do
		if instance.Parent then
			if instance:IsA("BasePart") then
				instance.LocalTransparencyModifier = value
			elseif instance:IsA("Decal") then
				instance.Transparency = value
			end
		end
	end
end

-- The sprite values of a class: its image is square, the figure is `bodyStuds` tall on every class.
function Visibility.specOf(classId: string): WorldSprite.Spec?
	local entry = Look.classes[classId]
	if not entry then
		return nil
	end
	return {
		name = "CharacterSprite",
		image = entry.image,
		studs = Look.bodyStuds / entry.height,
		ground = entry.ground,
		center = entry.center,
		pixels = entry.pixels,
	}
end

local function show(entry: Entry, classId: string, spec: WorldSprite.Spec)
	WorldSprite.setImage(entry.sprite, spec)
	WorldSprite.setVisible(entry.sprite, true)
	entry.classId = classId
	entry.ready = true
	entry.shadow.Transparency = ShadowLook.transparency
	for _, instance in entry.character:GetDescendants() do
		hideNative(entry, instance)
	end
end

local function load(player: Player, entry: Entry, classId: string)
	local spec = Visibility.specOf(classId)
	if not spec then
		entry.attempts = Look.loadAttempts
		return
	end
	entry.loading = classId
	entry.attempts += 1
	task.spawn(function()
		local probe = Instance.new("ImageLabel")
		probe.Image = spec.image
		local failed = false
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ probe }, function(_id, status)
				if status ~= Enum.AssetFetchStatus.Success then
					failed = true
				end
			end)
		end)
		probe:Destroy()
		if entries[player] ~= entry or entry.loading ~= classId then
			return
		end
		entry.loading = nil
		if ok and not failed then
			entry.attempts = 0
			show(entry, classId, spec)
		else
			entry.nextTry = os.clock() + Look.retrySeconds
		end
	end)
end

local function floorDrop(root: BasePart, humanoid: Humanoid?): number
	local hip = if humanoid then humanoid.HipHeight else 2
	return hip + root.Size.Y / 2
end

function Visibility.update()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local entry = entries[player]
		if entry and (entry.character ~= character or entry.root ~= root) then
			Visibility.forget(player)
			entry = nil
		end
		if not (character and root and root:IsA("BasePart")) then
			continue
		end
		local classId = character:GetAttribute(CLASS_ATTRIBUTE)
		if typeof(classId) ~= "string" then
			continue
		end
		if not entry then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local spec: WorldSprite.Spec = Visibility.specOf(classId)
				or { name = "CharacterSprite", image = "", studs = Look.bodyStuds }
			local drop = floorDrop(root, humanoid)
			local sprite = WorldSprite.attach(root, getHolder(), spec, drop)
			WorldSprite.setVisible(sprite, false)
			local created: Entry = {
				character = character,
				root = root,
				humanoid = humanoid,
				sprite = sprite,
				shadow = makeShadow(),
				feet = { makeFoot(sprite, "FootLeft"), makeFoot(sprite, "FootRight") },
				drop = drop,
				classId = nil,
				loading = nil,
				ready = false,
				attempts = 0,
				nextTry = 0,
				hidden = {},
			}
			created.connection = character.DescendantAdded:Connect(function(instance)
				if created.ready then
					hideNative(created, instance)
				end
			end)
			entries[player] = created
			entry = created
		end
		local current = entry :: Entry
		-- Roblox can load the humanoid after the root; the height of the feet depends on it.
		if not current.humanoid then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				current.humanoid = humanoid
				current.drop = floorDrop(root, humanoid)
				current.sprite.gui.StudsOffsetWorldSpace = Vector3.new(0, -current.drop, 0)
			end
		end
		if
			current.classId ~= classId
			and current.loading ~= classId
			and current.attempts < Look.loadAttempts
			and os.clock() >= current.nextTry
		then
			load(player, current, classId)
		end
	end
end

-- Keeps the shadow under the character's feet.
function Visibility.placeShadow(entry: Entry)
	local position = entry.root.Position
	entry.shadow.CFrame = CFrame.new(position.X, position.Y - entry.drop + ShadowLook.thickness, position.Z) * UPRIGHT
end

function Visibility.get(player: Player): Entry?
	return entries[player]
end

return Visibility
