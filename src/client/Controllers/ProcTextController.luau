--!strict
-- Feedback when an item effect pays out (DESIGN.md sections 6 and 13, since B4): each EffectProcs packet from
-- EffectService becomes short texts over the local character during a wave ("+50 HP" green, "+1 Shard" teal, "+2 HP
-- Regeneration" blue, "Blocked!", "Spark Bolt II!"), rising and fading. What pays out at the wave end or in the shop
-- comes as a Notify toast from the server instead; a packet that arrives when the arena is not shown becomes one
-- toast here (NotifyController). Texts from Util/EffectText. The server decides every effect;
-- this only shows them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local EffectText = require(Shared:WaitForChild("Util"):WaitForChild("EffectText"))

local NotifyController = require(script.Parent.NotifyController)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)

local LIFETIME = 1.2 -- seconds a text rises and fades
local RISE = 2.5 -- studs it rises
local START_HEIGHT = 3.5 -- studs above the character's root
local STACK_STEP = 0.9 -- studs between texts that start together
local FADE_FROM = 0.55 -- share of the lifetime after which it fades
local MAX_VISIBLE = 6
local TEXT_SIZE = 22
local STROKE_COLOR = Color3.fromRGB(20, 12, 30)
local COLORS: { [string]: Color3 } = {
	Heal = Theme.success,
	Shards = Color3.fromRGB(120, 230, 210), -- the shop's Shards teal
	Stats = Theme.tiers[2],
	Blocked = Theme.text,
	Weapon = Theme.accent,
}

type Shown = { gui: BillboardGui, label: TextLabel, startedAt: number, lift: number }

local ProcTextController = {}

local shown: { Shown } = {} -- oldest first
local pool: { Shown } = {}

local function build(): Shown
	local gui = Instance.new("BillboardGui")
	gui.Name = "ProcText"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(240, TEXT_SIZE + 6)
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = TEXT_SIZE
	label.TextStrokeColor3 = STROKE_COLOR
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	return { gui = gui, label = label, startedAt = 0, lift = 0 }
end

local function release(entry: Shown)
	entry.gui.Adornee = nil
	entry.gui.Parent = nil
	table.insert(pool, entry)
end

local function showOver(root: BasePart, text: string, color: Color3, lift: number)
	if #shown >= MAX_VISIBLE then
		release(table.remove(shown, 1) :: Shown)
	end
	local entry = table.remove(pool) or build()
	entry.label.Text = text
	entry.label.TextColor3 = color
	entry.label.TextTransparency = 0
	entry.label.TextStrokeTransparency = 0.2
	entry.startedAt = os.clock()
	entry.lift = lift
	entry.gui.StudsOffset = Vector3.new(0, START_HEIGHT + lift, 0)
	entry.gui.Adornee = root
	entry.gui.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	table.insert(shown, entry)
end

local function update()
	if #shown == 0 then
		return
	end
	local time = os.clock()
	for index = #shown, 1, -1 do
		local entry = shown[index]
		local age = (time - entry.startedAt) / LIFETIME
		if age >= 1 then
			table.remove(shown, index)
			release(entry)
		else
			entry.gui.StudsOffset = Vector3.new(0, START_HEIGHT + entry.lift + RISE * age, 0)
			local fade = math.clamp((age - FADE_FROM) / (1 - FADE_FROM), 0, 1)
			entry.label.TextTransparency = fade
			entry.label.TextStrokeTransparency = 0.2 + 0.8 * fade
		end
	end
end

local function onProcs(procs: { Types.EffectProc })
	local state = RunStateController.get()
	local fighting = state ~= nil and (state.phase == "Running" or state.phase == "Boss")
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if fighting and root and root:IsA("BasePart") then
		for index, proc in procs do
			showOver(root, EffectText.proc(proc), COLORS[proc.kind] or Theme.text, (index - 1) * STACK_STEP)
		end
		return
	end
	local lines = {}
	for _, proc in procs do
		table.insert(lines, EffectText.procWithItem(proc))
	end
	if #lines > 0 then
		NotifyController.push(table.concat(lines, "\n"))
	end
end

-- Lifecycle -------------------------------------------------------------------------

function ProcTextController.init()
	Net.onClient("EffectProcs", onProcs)
end

function ProcTextController.start()
	RunService.Heartbeat:Connect(update)
end

-- Queries ---------------------------------------------------------------------------

-- Texts over the character right now (smoke test).
function ProcTextController.getShown(): { string }
	local texts = {}
	for _, entry in shown do
		table.insert(texts, entry.label.Text)
	end
	return texts
end

return ProcTextController
