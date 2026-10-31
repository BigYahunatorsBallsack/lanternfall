--!strict
-- Graphics quality on this device (Paket 22, Config.Graphics): the "Graphics" setting (Auto, High, Low) decides
-- whether the renderers draw High or Low. Auto picks Low on phones and tablets, when Roblox's graphics slider is
-- turned down, or after a run stayed below the FPS limit for a while (then until the player leaves). Low also turns
-- the arena's bloom and the optional lights off here (decor lanterns and other players' lanterns, tagged by the
-- server) and thins the floating embers. EnemyRenderer, DeathBursts and DamageNumberController ask isLow();
-- DebugController shows getLevel() with the reason.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))

local RunStateController = require(script.Parent.RunStateController)
local SettingsController = require(script.Parent.SettingsController)

export type Level = "High" | "Low"

local Graphics = Config.Graphics
local BLOOM_NAME = "LanternfallBloom" -- MapService/Decor

local GraphicsController = {}

-- (level: Level): the level changed (setting, Auto's FPS check)
GraphicsController.Changed = Signal.new()

local level: Level = "High"
local reason = "default"
local slowSession = false -- Auto saw a slow run in this session

-- Which level a choice gives (pure, for tests): High and Low as chosen; Auto is Low on touch devices, with Roblox's
-- graphics slider at or below the limit (robloxQuality 1-10, nil = automatic) or after a slow run. Returns the level
-- and why.
function GraphicsController.decide(
	choice: string?,
	touch: boolean,
	robloxQuality: number?,
	slow: boolean
): (Level, string)
	if choice == "High" then
		return "High", "chosen"
	elseif choice == "Low" then
		return "Low", "chosen"
	end
	local auto = Graphics.auto
	if auto.lowOnTouch and touch then
		return "Low", "auto: touch device"
	elseif robloxQuality and robloxQuality <= auto.robloxQualityLowAtOrBelow then
		return "Low", `auto: Roblox graphics {robloxQuality}`
	elseif slow then
		return "Low", "auto: low FPS"
	end
	return "High", "auto"
end

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Roblox's own graphics quality slider (1-10), nil while it is on automatic or cannot be read.
local function robloxQuality(): number?
	local ok, value = pcall(function()
		local settings = (UserSettings() :: any):GetService("UserGameSettings")
		return settings.SavedQualityLevel.Value
	end)
	return if ok and type(value) == "number" and value > 0 then value else nil
end

local function ownCharacter(instance: Instance): boolean
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	return character ~= nil and instance:IsDescendantOf(character)
end

local function applyLight(light: Instance)
	if light:IsA("Light") then
		light.Enabled = level == "High" or Graphics.low.optionalLights or ownCharacter(light)
	end
end

local function applyMotes(emitter: Instance)
	if emitter:IsA("ParticleEmitter") then
		local share = if level == "Low" then Graphics.low.motesShare else 1
		emitter.Rate = Config.Map.decor.motes.rate * share
	end
end

local function applyBloom()
	local bloom = Lighting:FindFirstChild(BLOOM_NAME)
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Enabled = level == "High" or Graphics.low.bloom
	end
end

local function applyWorld()
	applyBloom()
	for _, light in CollectionService:GetTagged(Graphics.optionalLightTag) do
		applyLight(light)
	end
	for _, emitter in CollectionService:GetTagged(Graphics.motesTag) do
		applyMotes(emitter)
	end
end

local function refresh()
	local newLevel, newReason =
		GraphicsController.decide(SettingsController.get().graphics, isTouch(), robloxQuality(), slowSession)
	reason = newReason
	if newLevel ~= level then
		level = newLevel
		applyWorld()
		GraphicsController.Changed:Fire(level)
	end
end

-- Lifecycle -------------------------------------------------------------------------

function GraphicsController.init()
	SettingsController.Changed:Connect(refresh)
	CollectionService:GetInstanceAddedSignal(Graphics.optionalLightTag):Connect(applyLight)
	CollectionService:GetInstanceAddedSignal(Graphics.motesTag):Connect(applyMotes)
	Lighting.ChildAdded:Connect(function(child)
		if child.Name == BLOOM_NAME then
			applyBloom()
		end
	end)
	-- the own lantern may arrive before Character points at the new character
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		localPlayer.CharacterAdded:Connect(function()
			task.defer(applyWorld)
		end)
	end
end

function GraphicsController.start()
	refresh()
	applyWorld()
	-- Auto: a run that stays slow switches to Low for the rest of the session
	if RunService:IsStudio() and not Graphics.auto.fpsCheckInStudio then
		return
	end
	local frames, seconds = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		if slowSession or RunStateController.getView() ~= "Run" then
			frames, seconds = 0, 0
			return
		end
		frames += 1
		seconds += dt
		if seconds >= Graphics.auto.lowFpsSeconds then
			if frames / seconds < Graphics.auto.lowFps then
				slowSession = true
				refresh()
			end
			frames, seconds = 0, 0
		end
	end)
end

-- Queries ---------------------------------------------------------------------------

function GraphicsController.isLow(): boolean
	return level == "Low"
end

-- The level drawn now and why (e.g. "auto: touch device").
function GraphicsController.getLevel(): (Level, string)
	return level, reason
end

-- Tests: as if Auto had seen a slow run (true) or not.
function GraphicsController.setSlowSession(slow: boolean)
	slowSession = slow
	refresh()
end

return GraphicsController
