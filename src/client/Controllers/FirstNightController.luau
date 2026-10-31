--!strict
-- First Night hints (Paket 19, Config.FirstNight): while the local player plays a First Night run, one hint at a time
-- at the top of the screen ("Move" until the character walked a bit, then how weapons and orbs work, "Pick one" while
-- the level-up cards are open, the shop while it is open, the Looter in the Looter wave) with a Skip button (remote
-- SkipFirstNight). After the run the server sends FirstNightLobby once and the lobby hint opens (OK closes it).
-- Reads RunStateController and LevelUpController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local LevelUpController = require(script.Parent.LevelUpController)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local Dialog = require(script.Parent.Parent.UI.Dialog)

local FirstNight = Config.FirstNight
local Hints = FirstNight.hints

export type HintId = "move" | "fight" | "levelUp" | "shop" | "looter"

local FirstNightController = {}

local screen: ScreenGui
local hintPanel: Frame
local hintLabel: TextLabel
local lobbyPanel: Frame
local helpButton: TextButton
local expanded = true

-- Per run (cleared outside a First Night): where the character started, which hints are done, the timed hint and
-- until when it shows.
local startPosition: Vector3? = nil
local lastPosition: Vector3? = nil
local done: { [string]: boolean } = {}
local timed: HintId? = nil
local timedUntil = 0
local shown: HintId? = nil

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function hintText(id: HintId): string
	if id == "move" and isTouch() then
		return Hints.moveTouch
	elseif id == "looter" and FirstNight.looterWave >= FirstNight.waves then
		return `{Hints.looter}. {Hints.lastWave}`
	end
	return (Hints :: any)[id]
end

-- The local player's First Night run, if one is going (Running or Shop).
local function firstNightRun(): Types.RunState?
	local state = RunStateController.get()
	if not (state and state.runOptions and state.runOptions.firstNight) then
		return nil
	end
	if state.phase ~= "Running" and state.phase ~= "Shop" then
		return nil
	end
	local me = RunStateController.getLocalPlayer()
	return if me and me.participant then state else nil
end

local function startTimed(id: HintId)
	timed = id
	timedUntil = os.clock() + FirstNight.hintSeconds
end

-- Which hint shows now (nil = none), and moves the steps on.
local function current(state: Types.RunState): HintId?
	local now = os.clock()
	if state.phase == "Shop" then
		done.shopping = true
		return if done.shop then nil else "shop"
	elseif done.shopping then
		done.shop = true -- the first shop is over
	end
	if LevelUpController.isOpen() then
		done.levelOpen = true
		return if done.levelUp then nil else "levelUp"
	elseif done.levelOpen then
		done.levelUp = true
	end
	if not done.move then
		local position = rootPosition()
		if position then
			if lastPosition and (position - lastPosition).Magnitude > FirstNight.jumpStuds then
				startPosition = nil -- teleported into the arena
			end
			lastPosition = position
			startPosition = startPosition or position
			local offset = position - (startPosition :: Vector3)
			if Vector3.new(offset.X, 0, offset.Z).Magnitude >= FirstNight.moveStuds then
				done.move = true
				startTimed("fight")
			end
		end
		if not done.move then
			return "move"
		end
	end
	if state.wave == FirstNight.looterWave and not done.looter then
		done.looter = true
		startTimed("looter")
	end
	if timed and now < timedUntil then
		return timed
	end
	timed = nil
	return nil
end

local function update()
	local state = firstNightRun()
	if not state then -- outside a First Night: the next one starts over
		startPosition = nil
		lastPosition = nil
		table.clear(done)
		timed = nil
	end
	local id = if state then current(state) else nil
	if id ~= shown then
		shown = id
		expanded = true
		if id then
			hintLabel.Text = hintText(id)
		end
	end
	hintPanel.Visible = state ~= nil and expanded
	helpButton.Visible = state ~= nil
	hintLabel.Visible = id ~= nil
	screen.Enabled = state ~= nil or lobbyPanel.Visible
end

local function build()
	screen = Widgets.screen("FirstNight", 7)
	helpButton = Widgets.button({
		Name = "Help",
		Text = "HELP",
		TextSize = 15,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -72, 0, 8),
		Size = UDim2.fromOffset(96, 44),
		Parent = screen,
	}, function()
		expanded = not expanded
		update()
	end)
	hintPanel = Widgets.panel({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(560, 0),
		Visible = false,
		Parent = screen,
	})
	Widgets.list(8).Parent = hintPanel
	hintLabel = Widgets.label({
		Name = "Text",
		TextSize = 16,
		Font = Theme.fontBold,
		TextColor3 = Theme.accent,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = hintPanel,
	})
	Widgets.button({
		Name = "Skip",
		Text = Hints.skip,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 2,
		Parent = hintPanel,
	}, function()
		Net.fireServer("SkipFirstNight")
	end)

	Widgets.button({
		Name = "HideHint",
		Text = "GOT IT",
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 3,
		Parent = hintPanel,
	}, function()
		expanded = false
		update()
	end)
	Widgets.unscaled(hintPanel)
	local function resize()
		local area = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
		hintPanel.Size = UDim2.fromOffset(math.min(560, area.X - 24), 0)
	end
	resize()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	end
	lobbyPanel = Widgets.panel({
		Name = "Lobby",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(520, 0),
		Visible = false,
		Parent = screen,
	})
	Widgets.list(10).Parent = lobbyPanel
	Widgets.label({
		Name = "Title",
		Text = Hints.lobbyTitle,
		Font = Theme.fontBold,
		TextSize = Theme.titleSize,
		TextColor3 = Theme.accent,
		Size = UDim2.new(1, 0, 0, Theme.titleSize + 8),
		LayoutOrder = 1,
		Parent = lobbyPanel,
	})
	Widgets.label({
		Name = "Text",
		Text = Hints.lobby,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = lobbyPanel,
	})
	Widgets.button({
		Name = "Ok",
		Text = Hints.ok,
		Size = UDim2.fromOffset(160, 44),
		LayoutOrder = 3,
		Parent = lobbyPanel,
	}, function()
		lobbyPanel.Visible = false
		update()
	end)
	Dialog.wrap(lobbyPanel)
end

function FirstNightController.init()
	build()
	Net.onClient("FirstNightLobby", function()
		lobbyPanel.Visible = true
		update()
	end)
end

function FirstNightController.start()
	RunService.Heartbeat:Connect(update)
end

-- Tests: the hint on the screen (nil = none) and whether the lobby hint is open.
function FirstNightController.getHint(): HintId?
	return if hintPanel.Visible and hintLabel.Visible then shown else nil
end

function FirstNightController.isLobbyHintOpen(): boolean
	return lobbyPanel.Visible
end

return FirstNightController
