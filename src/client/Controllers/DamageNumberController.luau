--!strict
-- Damage numbers of the local player's own hits (DESIGN.md section 14, hit feedback): each DamageNumbers packet
-- (Net/HitNumbers, one per simulation step) becomes small white numbers over the hit enemies, critical hits big and
-- golden with a "!", burn ticks orange (B5). They rise and fade (Config.Feedback.damageNumbers); at most maxVisible at once (fewer on touch
-- devices), the oldest makes room. BillboardGuis from a pool sit on one anchor part, so moving a number is one
-- property. Active only while the local player is in a running run (RunStateController). The server decides
-- every hit; this only shows them. Since Paket 14 the settings menu can switch them off (SettingsController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local HitNumbers = require(Shared:WaitForChild("Net"):WaitForChild("HitNumbers"))

local RunStateController = require(script.Parent.RunStateController)
local SettingsController = require(script.Parent.SettingsController)

local FOLDER_NAME = "LanternfallDamageNumbers"
local HEIGHT = 3.2 -- studs above the floor where a number starts (the anchor sits on the floor)
local JITTER = 0.8 -- studs of random sideways offset, so numbers on one spot do not cover each other
local TEXT_SIZE = 20
local CRIT_TEXT_SIZE = 32
local CRIT_POP = 0.35 -- a critical number starts this much bigger and shrinks to its size
local NORMAL_COLOR = Color3.fromRGB(255, 255, 255)
local CRIT_COLOR = Color3.fromRGB(255, 205, 70)
local BURN_COLOR = Color3.fromRGB(255, 130, 50)
local STROKE_COLOR = Color3.fromRGB(20, 12, 30)
local GUI_WIDTH = 90
local FADE_FROM = 0.5 -- share of the lifetime after which a number fades out

type Shown = { gui: BillboardGui, label: TextLabel, startedAt: number, x: number, z: number, crit: boolean }

local DamageNumberController = {}

local Settings = Config.Feedback.damageNumbers
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local maxVisible = if touch then Settings.maxVisibleTouch else Settings.maxVisible
local anchorPosition = Vector3.new(0, Config.Map.arena.center.Y, 0)
local rng = Random.new()

local anchor: BasePart? = nil
local shown: { Shown } = {} -- oldest first
local pool: { Shown } = {}
local enabled = false

local function getAnchor(): BasePart
	local current = anchor
	if current then
		return current
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
	local part = Instance.new("Part")
	part.Name = "Anchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.CFrame = CFrame.new(anchorPosition)
	part.Parent = folder
	anchor = part
	return part
end

local function build(): Shown
	local gui = Instance.new("BillboardGui")
	gui.Name = "DamageNumber"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(GUI_WIDTH, CRIT_TEXT_SIZE)
	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextStrokeColor3 = STROKE_COLOR
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	return { gui = gui, label = label, startedAt = 0, x = 0, z = 0, crit = false }
end

local function release(entry: Shown)
	entry.gui.Enabled = false
	table.insert(pool, entry)
end

local function clear()
	for _, entry in shown do
		release(entry)
	end
	table.clear(shown)
end

local function show(hit: HitNumbers.Hit, now: number)
	local entry: Shown
	if #shown >= maxVisible then
		entry = table.remove(shown, 1) :: Shown
	else
		entry = table.remove(pool) or build()
	end
	local parent = getAnchor()
	if entry.gui.Parent ~= parent then
		entry.gui.Parent = parent
	end
	entry.startedAt = now
	entry.crit = hit.crit
	entry.x = hit.x + (rng:NextNumber() * 2 - 1) * JITTER
	entry.z = hit.z + (rng:NextNumber() * 2 - 1) * JITTER
	local label = entry.label
	label.Text = if hit.crit then `{hit.amount}!` else tostring(hit.amount)
	label.TextColor3 = if hit.crit then CRIT_COLOR elseif hit.burn then BURN_COLOR else NORMAL_COLOR
	label.TextSize = if hit.crit then CRIT_TEXT_SIZE else TEXT_SIZE
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.2
	entry.gui.StudsOffsetWorldSpace = Vector3.new(entry.x, HEIGHT, entry.z) - anchorPosition
	entry.gui.Enabled = true
	table.insert(shown, entry)
end

local function onPacket(packet: any)
	if not (enabled and Settings.enabled and SettingsController.get().damageNumbers and typeof(packet) == "buffer") then
		return
	end
	local now = os.clock()
	for _, hit in HitNumbers.decode(packet) do
		show(hit, now)
	end
end

local function render()
	if #shown == 0 then
		return
	end
	local now = os.clock()
	local index = 1
	while index <= #shown do
		local entry = shown[index]
		local t = (now - entry.startedAt) / Settings.seconds
		if t >= 1 then
			table.remove(shown, index)
			release(entry)
			continue
		end
		entry.gui.StudsOffsetWorldSpace = Vector3.new(entry.x, HEIGHT + Settings.riseStuds * t, entry.z)
			- anchorPosition
		local fade = math.clamp((t - FADE_FROM) / (1 - FADE_FROM), 0, 1)
		entry.label.TextTransparency = fade
		entry.label.TextStrokeTransparency = 0.2 + 0.8 * fade
		if entry.crit then
			entry.label.TextSize = CRIT_TEXT_SIZE * (1 + CRIT_POP * math.max(0, 1 - t * 4))
		end
		index += 1
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

function DamageNumberController.init()
	Net.onClient("DamageNumbers", onPacket)
	RunStateController.Changed:Connect(function()
		setEnabled(RunStateController.getView() == "Run")
	end)
end

function DamageNumberController.start()
	setEnabled(RunStateController.getView() == "Run")
	RunService.RenderStepped:Connect(render)
end

-- Queries ---------------------------------------------------------------------------

-- Damage numbers on screen right now.
function DamageNumberController.getCount(): number
	return #shown
end

return DamageNumberController
