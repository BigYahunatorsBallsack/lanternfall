--!strict
-- Cosmetics on the character (Paket 17, DESIGN.md section 14): the lantern that floats next to the player and the
-- trail behind them, from what the player picked in the Ember shop (Util/EmberShopRules.shown; VIP players get the VIP
-- lantern and trail until they pick something else). Built on the server as a 2D sprite welded to the
-- HumanoidRootPart, so everyone sees them; look only (no collision, no queries, massless). Rebuilt on spawn, when the
-- data loads or changes and when pass perks change. Called by EmberShopService (refresh after a buy or equip).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local CosmeticsConfig = require(Shared.Config.Cosmetics)
local EmberShopRules = require(Shared.Util.EmberShopRules)
local WorldSprite = require(Shared.Util.WorldSprite)

local MonetizationService = require(script.Parent.MonetizationService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local FOLDER_NAME = "LanternfallCosmetics"
local TRAIL_TOP = "CosmeticTrailTop"
local TRAIL_BOTTOM = "CosmeticTrailBottom"
local ROOT_WAIT_SECONDS = 5

local Cosmetics = Config.Cosmetics

local CosmeticService = {}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function clear(character: Model)
	local folder = character:FindFirstChild(FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	for _, name in { TRAIL_TOP, TRAIL_BOTTOM } do
		local attachment = root and root:FindFirstChild(name)
		if attachment then
			attachment:Destroy()
		end
	end
end

-- One sprite welded beside the character: the glowing core with the frame in front of it, tinted per lantern.
local function buildLantern(folder: Folder, root: BasePart, lantern: CosmeticsConfig.Lantern)
	local style = Cosmetics.lantern
	local offset = style.offset
	local images = Config.Sprites.images :: any
	local sprite = WorldSprite.create({
		name = "Lantern",
		image = images[`lantern{lantern.style}Glow`],
		studs = Config.Sprites.lantern.studs * style.scale,
	})
	sprite.picture.ImageColor3 = rgb(lantern.glow)
	WorldSprite.addLayer(sprite, images[`lantern{lantern.style}Frame`], 1, rgb(lantern.frame))
	local part = sprite.anchor :: BasePart
	part.Anchored = false
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(offset[1], offset[2], offset[3])
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
end

local function buildTrail(folder: Folder, root: BasePart, trail: CosmeticsConfig.Trail)
	local style = Cosmetics.trail
	local top = Instance.new("Attachment")
	top.Name = TRAIL_TOP
	top.Position = Vector3.new(0, style.width / 2, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = TRAIL_BOTTOM
	bottom.Position = Vector3.new(0, -style.width / 2, 0)
	bottom.Parent = root
	local effect = Instance.new("Trail")
	effect.Name = "Trail"
	effect.Attachment0 = top
	effect.Attachment1 = bottom
	effect.Color = ColorSequence.new(rgb(trail.colors[1]), rgb(trail.colors[#trail.colors]))
	effect.Transparency = NumberSequence.new(0.25, 1)
	effect.Lifetime = style.lifetime
	effect.LightEmission = 0.6
	effect.FaceCamera = true -- flat from straight above otherwise
	effect.Parent = folder
end

-- The cosmetic ids the player's slots show now (nil = nothing), from the saved picks and the VIP pass.
function CosmeticService.shownFor(player: Player): { [string]: string }
	local data = PlayerDataService.get(player)
	local shown = {}
	if not data then
		return shown
	end
	local vip = MonetizationService.owns(player, "VIP")
	for _, slot in Cosmetics.slots do
		shown[slot] = EmberShopRules.shown(slot, data.cosmetics.equipped, data.cosmetics.owned, vip)
	end
	return shown
end

-- Rebuilds the player's cosmetics on their character (nothing until the data is loaded). Skips the work when the
-- character already shows the same ones.
function CosmeticService.refresh(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root and root:IsA("BasePart")) or not PlayerDataService.isLoaded(player) then
		return
	end
	local shown = CosmeticService.shownFor(player)
	local existing = character:FindFirstChild(FOLDER_NAME)
	if
		existing
		and existing:GetAttribute("Lantern") == (shown.Lantern or "")
		and existing:GetAttribute("Trail") == (shown.Trail or "")
	then
		return
	end
	clear(character)
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute("Lantern", shown.Lantern or "")
	folder:SetAttribute("Trail", shown.Trail or "")
	local lantern = shown.Lantern and EmberShopRules.cosmetic(shown.Lantern)
	if lantern then
		buildLantern(folder, root, lantern :: any)
	end
	local trail = shown.Trail and EmberShopRules.cosmetic(shown.Trail)
	if trail then
		buildTrail(folder, root, trail :: any)
	end
	folder.Parent = character
end

local function onCharacter(player: Player, character: Model)
	if not character:FindFirstChild("HumanoidRootPart") then
		character:WaitForChild("HumanoidRootPart", ROOT_WAIT_SECONDS)
	end
	if player.Character == character then
		CosmeticService.refresh(player)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(onCharacter, player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

function CosmeticService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	PlayerDataService.Loaded:Connect(CosmeticService.refresh)
	PlayerDataService.Changed:Connect(CosmeticService.refresh)
	MonetizationService.PerksChanged:Connect(CosmeticService.refresh)
end

return CosmeticService
