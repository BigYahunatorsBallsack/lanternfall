--!strict
-- A small HP bar above every fighting player's head, as in Brotato: red fill on a dark track, shown only while the
-- player is hurt (hidden at full HP, while down/out and outside a wave). Reads PlayerStateController (HP) and
-- RunStateController (phase, Alive/Down); started by the client Loader.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local PlayerStateController = require(script.Parent.PlayerStateController)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)

local Sprites = Config.Sprites
local BAR_WIDTH = 3.4 -- studs, a bit narrower than the figure
local BAR_HEIGHT = 0.5 -- studs
local BAR_GAP = 0.5 -- studs between the top of the figure and the bar
local BORDER_PIXELS = 2
local TRACK_COLOR = Color3.fromRGB(40, 40, 40)
local FIGHT_PHASES: { [string]: boolean } = { Running = true, Boss = true }

type Bar = { gui: BillboardGui, fill: Frame }

local PlayerHpBarController = {}

local bars: { [number]: Bar } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function build(userId: number): Bar
	local gui = Instance.new("BillboardGui")
	gui.Name = `HpBar{userId}`
	gui.Size = UDim2.new(BAR_WIDTH, 0, BAR_HEIGHT, 0)
	-- StudsOffset is in camera space: Y is "up" on screen, where the sprite's head is (it leans back with the camera).
	gui.StudsOffset = Vector3.new(0, Sprites.character.bodyStuds + BAR_GAP, Sprites.depthBias)
	gui.AlwaysOnTop = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.fromScale(1, 1)
	track.BackgroundColor3 = TRACK_COLOR
	track.BorderSizePixel = 0
	track.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.stroke
	stroke.Thickness = BORDER_PIXELS
	stroke.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Theme.hp
	fill.BorderSizePixel = 0
	fill.Parent = track
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return { gui = gui, fill = fill }
end

local function remove(userId: number)
	local bar = bars[userId]
	if bar then
		bar.gui:Destroy()
		bars[userId] = nil
	end
end

local function refresh(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	local vitals: Types.PlayerVitals? = PlayerStateController.get(userId)
	local state = RunStateController.get()
	local info = RunStateController.getPlayer(userId)
	local root = player and rootOf(player)
	local show = vitals ~= nil
		and root ~= nil
		and state ~= nil
		and FIGHT_PHASES[state.phase] == true
		and info ~= nil
		and info.participant == true
		and info.state == "Alive"
		and vitals.maxHp > 0
		and vitals.hp > 0
		and vitals.hp < vitals.maxHp
	if not (show and vitals and root) then
		local bar = bars[userId]
		if bar then
			bar.gui.Enabled = false
		end
		return
	end
	local bar = bars[userId] or build(userId)
	bars[userId] = bar
	bar.gui.Adornee = root
	bar.fill.Size = UDim2.fromScale(math.clamp(vitals.hp / vitals.maxHp, 0, 1), 1)
	bar.gui.Enabled = true
end

local function refreshAll()
	for _, player in Players:GetPlayers() do
		refresh(player.UserId)
	end
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		refresh(player.UserId)
	end)
end

function PlayerHpBarController.init()
	PlayerStateController.Changed:Connect(function(userId: number)
		refresh(userId)
	end)
	RunStateController.Changed:Connect(refreshAll)
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		remove(player.UserId)
	end)
end

function PlayerHpBarController.start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	refreshAll()
end

return PlayerHpBarController
