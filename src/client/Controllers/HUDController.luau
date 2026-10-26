--!strict
-- In-run HUD for the prototype: run timer, phase hint, the local HP bar with a red flash on hits, the team with
-- HP and Alive/Down states and your weapons with their levels. Shown while the local player is in a running run;
-- reads RunStateController, PlayerStateController and LoadoutController. WP14 builds the full HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local LoadoutController = require(script.Parent.LoadoutController)
local PlayerStateController = require(script.Parent.PlayerStateController)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local STATE_TEXT: { [string]: string } = { Alive = "alive", Down = "DOWN", Out = "out" }
local HP_BAR_WIDTH = 360
local HIT_FLASH_SECONDS = 0.35
local HIT_FLASH_TRANSPARENCY = 0.75 -- red screen tint right after a hit
local LOW_HP_FRACTION = 0.3

local HUDController = {}

local screen: ScreenGui
local timerLabel: TextLabel
local hintLabel: TextLabel
local teamRows: Frame
local hpFill: Frame
local hpLabel: TextLabel
local hitFlash: Frame
local weaponsTitle: TextLabel
local weaponRows: Frame

local function hintText(state: Types.RunState): (string, Color3)
	if state.phase == "Boss" then
		return string.upper(Config.Enemies.boss.displayName), Theme.danger
	end
	return `Survive until {Format.time(Config.Run.durationSeconds)}`, Theme.textDim
end

local function renderTeam(state: Types.RunState)
	Widgets.clearRows(teamRows)
	local order = 0
	for _, info in state.players do
		if info.participant then
			order += 1
			local stateName = info.state or "Alive"
			local vitals = PlayerStateController.get(info.userId)
			local hpText = if vitals and stateName == "Alive" then ` · {vitals.hp} HP` else ""
			Widgets.label({
				Text = `{info.name} · {STATE_TEXT[stateName] or stateName}{hpText}`,
				TextColor3 = if stateName == "Alive" then Theme.text else Theme.danger,
				TextXAlignment = Enum.TextXAlignment.Right,
				LayoutOrder = order,
				Parent = teamRows,
			})
		end
	end
end

local function renderHp()
	local vitals = PlayerStateController.getLocal()
	if not vitals then
		return
	end
	local fraction = if vitals.maxHp > 0 then math.clamp(vitals.hp / vitals.maxHp, 0, 1) else 0
	hpFill.Size = UDim2.fromScale(fraction, 1)
	hpFill.BackgroundColor3 = if fraction <= LOW_HP_FRACTION then Theme.danger else Theme.success
	hpLabel.Text = `{vitals.hp} / {vitals.maxHp}`
end

local function weaponName(weapon: Types.WeaponInfo): string
	local evolution = weapon.evolution and Config.Evolutions[weapon.evolution]
	if evolution then
		return evolution.displayName
	end
	local config = Config.Weapons[weapon.id]
	return if config then config.displayName else weapon.id
end

local function renderWeapons()
	Widgets.clearRows(weaponRows)
	local loadout = LoadoutController.getLocal()
	local paused = loadout ~= nil and loadout.paused
	weaponsTitle.Text = if paused then "WEAPONS (OFF)" else "WEAPONS"
	weaponsTitle.TextColor3 = if paused then Theme.danger else Theme.textDim
	if not loadout then
		return
	end
	for index, weapon in loadout.weapons do
		local level = if weapon.level >= Config.Player.maxItemLevel then "MAX" else `LV {weapon.level}`
		Widgets.label({
			Text = `{weaponName(weapon)} · {level}`,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = index,
			Parent = weaponRows,
		})
	end
end

local function flashHit()
	hitFlash.BackgroundTransparency = HIT_FLASH_TRANSPARENCY
	TweenService:Create(hitFlash, TweenInfo.new(HIT_FLASH_SECONDS), { BackgroundTransparency = 1 }):Play()
end

local function onVitalsChanged(userId: number, vitals: Types.PlayerVitals, previous: Types.PlayerVitals?)
	if not screen.Enabled then
		return
	end
	if userId == Players.LocalPlayer.UserId then
		renderHp()
		if previous and vitals.hp < previous.hp and vitals.hp > 0 then
			flashHit()
		end
	end
	local state = RunStateController.get()
	if state then
		renderTeam(state)
	end
end

local function render()
	local state = RunStateController.get()
	screen.Enabled = state ~= nil and RunStateController.getView() == "Run"
	if not (state and screen.Enabled) then
		return
	end
	local hint, color = hintText(state)
	hintLabel.Text = hint
	hintLabel.TextColor3 = color
	renderTeam(state)
	renderHp()
	renderWeapons()
end

local function build()
	screen = Widgets.screen("HUD", 0)

	local top = Widgets.panel({
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(260, 0),
		Parent = screen,
	})
	Widgets.list(2).Parent = top
	timerLabel = Widgets.label({
		Text = "00:00",
		Font = Theme.fontBold,
		TextSize = 44,
		Size = UDim2.new(1, 0, 0, 48),
		TextColor3 = Theme.accent,
		LayoutOrder = 1,
		Parent = top,
	})
	hintLabel = Widgets.label({ TextSize = 18, LayoutOrder = 2, Parent = top })

	local team = Widgets.panel({
		Name = "Team",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(260, 0),
		Parent = screen,
	})
	Widgets.list(4).Parent = team
	Widgets.label({
		Text = "TEAM",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 0,
		Parent = team,
	})
	teamRows = Widgets.create("Frame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		Parent = team,
	})
	Widgets.list(4).Parent = teamRows

	local weapons = Widgets.panel({
		Name = "Weapons",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 8),
		Size = UDim2.fromOffset(240, 0),
		Parent = screen,
	})
	Widgets.list(4).Parent = weapons
	weaponsTitle = Widgets.label({
		Name = "WeaponsTitle",
		Text = "WEAPONS",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = weapons,
	})
	weaponRows = Widgets.create("Frame", {
		Name = "WeaponRows",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		Parent = weapons,
	})
	Widgets.list(4).Parent = weaponRows

	local hp = Widgets.panel({
		Name = "Health",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(HP_BAR_WIDTH, 0),
		Parent = screen,
	})
	local track = Widgets.create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.button,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = hp,
	}, { Widgets.corner(UDim.new(0, 8)) })
	hpFill = Widgets.create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.success,
		Size = UDim2.fromScale(1, 1),
		Parent = track,
	}, { Widgets.corner(UDim.new(0, 8)) })
	hpLabel = Widgets.label({
		Name = "HpText",
		Text = "",
		Font = Theme.fontBold,
		TextSize = 18,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = track,
	})

	hitFlash = Widgets.create("Frame", {
		Name = "HitFlash",
		BackgroundColor3 = Theme.danger,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Active = false,
		ZIndex = 0,
		Parent = screen,
	})
end

function HUDController.start()
	build()
	RunStateController.Changed:Connect(render)
	PlayerStateController.Changed:Connect(onVitalsChanged)
	LoadoutController.Changed:Connect(function(userId: number)
		if screen.Enabled and userId == Players.LocalPlayer.UserId then
			renderWeapons()
		end
	end)
	render()

	RunService.Heartbeat:Connect(function()
		if screen.Enabled then
			local text = Format.time(RunStateController.getElapsed())
			if timerLabel.Text ~= text then
				timerLabel.Text = text
			end
		end
	end)
end

return HUDController
