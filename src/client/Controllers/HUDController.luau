--!strict
-- In-run HUD for the prototype: team XP bar with the level (and level-ups waiting for the end of the wave), the time
-- left in the wave or the shop, the wave (number, final wave, shop; Util/RunSchedule) with a big banner when a new wave
-- starts that names what it brings, the local HP bar with a red flash on hits, the team with HP and Alive/Down states
-- (who is picking a card, who is done shopping), and your weapons and passives with their levels. Shown while the local player is in a running run; reads RunStateController,
-- PlayerStateController, LoadoutController and ProgressController. WP14 builds the full HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local RunSchedule = require(Shared:WaitForChild("Util"):WaitForChild("RunSchedule"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local LevelUpController = require(script.Parent.LevelUpController)
local LoadoutController = require(script.Parent.LoadoutController)
local PlayerStateController = require(script.Parent.PlayerStateController)
local ProgressController = require(script.Parent.ProgressController)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local STATE_TEXT: { [string]: string } = { Alive = "alive", Down = "DOWN", Out = "out" }
local HP_BAR_WIDTH = 360
local HIT_FLASH_SECONDS = 0.35
local HIT_FLASH_TRANSPARENCY = 0.75 -- red screen tint right after a hit
local LOW_HP_FRACTION = 0.3
local XP_BAR_WIDTH = 420
local XP_COLOR = Color3.fromRGB(96, 170, 255) -- the color of small XP orbs
local BANNER_SECONDS = 2.6
local BANNER_FADE_SECONDS = 0.4
local BANNER_TITLE_SIZE = 56

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
local passivesTitle: TextLabel
local passiveRows: Frame
local xpFill: Frame
local xpLabel: TextLabel
local bannerWave = 0 -- the wave whose banner was shown; 0 before the first

local function hintText(state: Types.RunState): (string, Color3)
	if state.phase == "Boss" then
		return string.upper(Config.Enemies.boss.displayName), Theme.danger
	end
	local wave = RunSchedule.wave(state.wave)
	if state.phase == "Shop" then
		return `Shop · wave {wave.number + 1} / {wave.count} next`, Theme.success
	elseif wave.final then
		return `Final wave {wave.number} / {wave.count}`, Theme.danger
	end
	return `Wave {wave.number} / {wave.count}`, Theme.textDim
end

-- Big "WAVE n" banner with what the wave brings (new enemies, Swarm Rush, elites).
local function showWaveBanner(number: number)
	local old = screen:FindFirstChild("WaveBanner")
	if old then
		old:Destroy()
	end
	local events = RunSchedule.eventsOf(number)
	local banner = Widgets.create("Frame", {
		Name = "WaveBanner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.fromOffset(520, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = screen,
	})
	Widgets.list(2).Parent = banner
	local labels = {
		Widgets.label({
			Name = "WaveTitle",
			Text = `WAVE {number}`,
			Font = Theme.fontBold,
			TextSize = BANNER_TITLE_SIZE,
			Size = UDim2.new(1, 0, 0, BANNER_TITLE_SIZE + 4),
			TextColor3 = if #events > 0 then Theme.danger else Theme.accent,
			TextStrokeTransparency = 0.3,
			LayoutOrder = 1,
			Parent = banner,
		}),
	}
	if #events > 0 then
		table.insert(
			labels,
			Widgets.label({
				Name = "WaveEvents",
				Text = table.concat(events, "  ·  "),
				Font = Theme.fontBold,
				TextSize = 22,
				TextColor3 = Theme.text,
				TextStrokeTransparency = 0.3,
				LayoutOrder = 2,
				Parent = banner,
			})
		)
	end
	task.delay(BANNER_SECONDS, function()
		if not banner.Parent then
			return
		end
		local info = TweenInfo.new(BANNER_FADE_SECONDS)
		for _, label in labels do
			TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		task.wait(BANNER_FADE_SECONDS)
		banner:Destroy()
	end)
end

local function xpText(): string
	local team = ProgressController.getTeam()
	local waiting = LevelUpController.getWaiting()
	local level = `LV {if team then team.level else 1}`
	return if waiting > 0 then `{level} · +{waiting} at wave end` else level
end

-- Big timer: seconds left in the wave (Running), in the shop (Shop), fighting time in the boss phase.
local function timerText(state: Types.RunState?): string
	if state and state.phase == "Running" then
		local left = RunSchedule.wave(state.wave).endsAt - RunStateController.getElapsed()
		return Format.time(math.max(0, math.ceil(left)))
	elseif state and state.phase == "Shop" then
		return Format.time(math.ceil(RunStateController.getPhaseRemaining()))
	end
	return Format.time(RunStateController.getElapsed())
end

-- Every frame: the timer, the wave hint, and the banner once a new wave starts.
local function updateWave()
	local state = RunStateController.get()
	local text = timerText(state)
	if timerLabel.Text ~= text then
		timerLabel.Text = text
	end
	local xp = xpText()
	if xpLabel.Text ~= xp then
		xpLabel.Text = xp
	end
	if not (state and (state.phase == "Running" or state.phase == "Shop")) then
		bannerWave = 0
		return
	end
	local hint, color = hintText(state)
	if hintLabel.Text ~= hint then
		hintLabel.Text = hint
		hintLabel.TextColor3 = color
	end
	if state.phase == "Running" and state.wave ~= bannerWave then
		bannerWave = state.wave
		showWaveBanner(state.wave)
	end
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
			local pickText = if vitals and vitals.choosing then " · picking" else ""
			if state.phase == "Shop" and stateName ~= "Out" and not (vitals and vitals.choosing) then
				pickText = if info.shopReady then " · ready" else " · shopping"
			end
			Widgets.label({
				Text = `{info.name} · {STATE_TEXT[stateName] or stateName}{hpText}{pickText}`,
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

local function levelText(level: number): string
	return if level >= Config.Player.maxItemLevel then "MAX" else `LV {level}`
end

local function renderPassives()
	Widgets.clearRows(passiveRows)
	local passives = ProgressController.getLocalPassives()
	passivesTitle.Visible = #passives > 0
	for index, info in passives do
		local passive = Config.Passives[info.id]
		Widgets.label({
			Text = `{if passive then passive.displayName else info.id} · {levelText(info.level)}`,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = index,
			Parent = passiveRows,
		})
	end
end

local function renderXp()
	local team = ProgressController.getTeam()
	local fraction = if team and team.needed > 0 then math.clamp(team.xp / team.needed, 0, 1) else 0
	xpFill.Size = UDim2.fromScale(fraction, 1)
	xpLabel.Text = xpText()
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
		Widgets.label({
			Text = `{weaponName(weapon)} · {levelText(weapon.level)}`,
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
	renderPassives()
	renderXp()
end

local function build()
	screen = Widgets.screen("HUD", 0)

	local top = Widgets.panel({
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(XP_BAR_WIDTH, 0),
		Parent = screen,
	})
	Widgets.list(2).Parent = top
	-- Team XP bar with the level (DESIGN.md section 13); a Frame, so the timer stays the panel's first TextLabel.
	local xpTrack = Widgets.create("Frame", {
		Name = "XpTrack",
		BackgroundColor3 = Theme.button,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 0,
		Parent = top,
	}, { Widgets.corner(UDim.new(0, 6)) })
	xpFill = Widgets.create("Frame", {
		Name = "XpFill",
		BackgroundColor3 = XP_COLOR,
		Size = UDim2.fromScale(0, 1),
		Parent = xpTrack,
	}, { Widgets.corner(UDim.new(0, 6)) })
	xpLabel = Widgets.label({
		Name = "XpText",
		Text = "LV 1",
		Font = Theme.fontBold,
		TextSize = 16,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = xpTrack,
	})
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
	passivesTitle = Widgets.label({
		Name = "PassivesTitle",
		Text = "PASSIVES",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		LayoutOrder = 2,
		Parent = weapons,
	})
	passiveRows = Widgets.create("Frame", {
		Name = "PassiveRows",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 3,
		Parent = weapons,
	})
	Widgets.list(4).Parent = passiveRows

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
	ProgressController.PassivesChanged:Connect(function(userId: number)
		if screen.Enabled and userId == Players.LocalPlayer.UserId then
			renderPassives()
		end
	end)
	ProgressController.TeamChanged:Connect(function()
		if screen.Enabled then
			renderXp()
		end
	end)
	render()

	RunService.Heartbeat:Connect(function()
		if screen.Enabled then
			updateWave()
		end
	end)
end

return HUDController
