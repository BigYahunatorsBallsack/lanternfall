--!strict
-- In-run HUD for the prototype: team XP bar with the level (and level-ups waiting for the end of the wave), the time
-- left in the wave or the shop, the wave (number, final wave, shop; Util/RunSchedule) with a big banner when a new wave
-- starts that names what it brings, the local HP bar with a red flash on hits, the team with HP and Alive/Down states
-- (who is picking a card, who is done shopping), your weapons with their levels and your items with their counts in
-- their rarity color (the first few). Since B4 the item effect bonuses active right now sit above the HP bar
-- (ActiveBonuses remote: "+8 Armor (standing still)"). Shown while the local player is in a running run; reads
-- RunStateController, PlayerStateController, LoadoutController and ProgressController.
-- Paket 14: weapons and items have tooltips (UI/Tooltip, Util/TooltipText: real damage, scaling, limits), under the
-- wave the next planned elite or horde wave (remote WavePlan from DangerService, all planned waves in its tooltip;
-- the wave banner names them too), arrows at the screen edge point to teammates out of sight, the team panel sits
-- below the settings button, and small screens (Widgets.isCompact) list fewer items.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local DangerRules = require(Shared:WaitForChild("Util"):WaitForChild("DangerRules"))
local EffectText = require(Shared:WaitForChild("Util"):WaitForChild("EffectText"))
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local RunSchedule = require(Shared:WaitForChild("Util"):WaitForChild("RunSchedule"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))
local UpgradeText = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeText"))

local LevelUpController = require(script.Parent.LevelUpController)
local LoadoutController = require(script.Parent.LoadoutController)
local PlayerStateController = require(script.Parent.PlayerStateController)
local ProgressController = require(script.Parent.ProgressController)
local RunStateController = require(script.Parent.RunStateController)
local SettingsController = require(script.Parent.SettingsController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Tooltip = require(script.Parent.Parent.UI.Tooltip)
local TooltipText = require(Shared:WaitForChild("Util"):WaitForChild("TooltipText"))
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
local ARROW_MARGIN = 36 -- pixels between a teammate arrow and the screen edge
local ARROW_SIZE = 34
local CHALLENGE_COLOR = Color3.fromRGB(255, 150, 70) -- elite and horde waves ahead
local MAX_BONUS_LINES = 4 -- active effect bonuses over the HP bar; the rest as "+2 more"

local HUDController = {}

local screen: ScreenGui
local buildPanel: Frame
local buildButton: TextButton
local buildOpen = false
local timerLabel: TextLabel
local hintLabel: TextLabel
local teamRows: Frame
local hpFill: Frame
local hpLabel: TextLabel
local bonusLabel: TextLabel
local bonuses: { Types.ActiveBonus } = {}
local hitFlash: Frame
local weaponsTitle: TextLabel
local weaponRows: Frame
local itemsTitle: TextLabel
local itemRows: Frame
local xpFill: Frame
local xpLabel: TextLabel
local bannerWave = 0 -- the wave whose banner was shown; 0 before the first
local previewLabel: TextLabel
local wavePlan: { Types.WaveChallenge } = {} -- Paket 14: planned elite and horde waves of the run (WavePlan)
local teamPanel: Frame
local arrowLayer: Frame
local arrows: { [number]: Frame } = {}

local function hintText(state: Types.RunState): (string, Color3)
	if state.phase == "Boss" then
		return string.upper(Config.Enemies.boss.displayName), Theme.danger
	end
	local wave = RunSchedule.wave(state.wave)
	if state.runOptions and state.runOptions.firstNight then -- Paket 19: the First Night has fewer waves
		local count = DangerRules.waveCount(state.runOptions)
		if state.phase == "Shop" then
			return `Shop · wave {wave.number + 1} / {count} next`, Theme.success
		elseif wave.number >= count then
			return `Final wave {wave.number} / {count}`, Theme.danger
		end
		return `Wave {wave.number} / {count}`, Theme.textDim
	end
	if state.phase == "Shop" and wave.number >= wave.count then
		return `Shop · endless wave {wave.number + 1} next`, Theme.success -- B11
	elseif state.phase == "Shop" then
		return `Shop · wave {wave.number + 1} / {wave.count} next`, Theme.success
	elseif wave.endless then
		return `Endless wave {wave.number}`, if wave.boss then Theme.danger else Theme.textDim -- B11
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
	local state = RunStateController.get()
	local options = state and (state.runOptions or state.options)
	local events = RunSchedule.eventsOf(number, if options then options.danger else nil) -- B11: by danger level
	for _, challenge in wavePlan do
		if challenge.wave == number then
			table.insert(events, 1, if challenge.kind == "Horde" then "Horde wave!" else "Elite wave!")
		end
	end
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
	local preview = TooltipText.nextChallenge(wavePlan, state.wave)
	previewLabel.Visible = preview ~= nil
	if preview and previewLabel.Text ~= preview then
		previewLabel.Text = preview
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
				TextSize = if workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X < 1100 then 14 else 18,
				AutomaticSize = Enum.AutomaticSize.Y,
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

local function renderItems()
	Widgets.clearRows(itemRows)
	local items = ProgressController.getLocalItems()
	local total = 0
	for _, info in items do
		total += info.count
	end
	itemsTitle.Visible = #items > 0
	itemsTitle.Text = `ITEMS ({total})`
	for index, info in items do
		local item = Config.Items.byId[info.id]
		local row = Widgets.label({
			Name = info.id,
			Text = `{if item then item.displayName else info.id}{if info.count > 1 then ` x{info.count}` else ""}`,
			TextColor3 = if item then Theme.tiers[item.tier] or Theme.text else Theme.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 17,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = itemRows,
		})
		local itemId, count = info.id, info.count
		Tooltip.attach(row, function()
			return TooltipText.item(itemId, count)
		end)
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
		local row = Widgets.label({
			Name = `Weapon{index}`,
			Text = UpgradeText.weaponName(weapon.id, weapon.tier, weapon.evolution),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 17,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = weaponRows,
		})
		local uid = weapon.uid
		Tooltip.attach(row, function()
			local current = LoadoutController.getLocal()
			for _, info in if current then current.weapons else {} do
				if info.uid == uid then
					return TooltipText.weapon(info)
				end
			end
			return nil, nil
		end)
	end
end

local function renderBonuses()
	local lines = {}
	for index, bonus in bonuses do
		if index > MAX_BONUS_LINES then
			table.insert(lines, `+{#bonuses - MAX_BONUS_LINES} more`)
			break
		end
		table.insert(lines, EffectText.bonus(bonus))
	end
	bonusLabel.Text = table.concat(lines, "\n")
	bonusLabel.Visible = #lines > 0
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

-- The team panel stays below the settings button, which scales with the screen.
local function placeTeamPanel()
	local uiScale = teamPanel:FindFirstChildOfClass("UIScale")
	local scale = if uiScale then uiScale.Scale else 1
	teamPanel.Position = UDim2.new(1, -12, 0, 8 + SettingsController.RESERVED_HEIGHT * scale)
end

local function newArrow(name: string): Frame
	local holder = Widgets.create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE),
		Parent = arrowLayer,
	})
	Widgets.label({
		Name = "Arrow",
		Text = "▶",
		Font = Theme.fontBold,
		TextSize = ARROW_SIZE,
		TextColor3 = Theme.accent,
		TextStrokeTransparency = 0.3,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	})
	Widgets.label({
		Name = "Name",
		Text = name,
		TextSize = 14,
		TextStrokeTransparency = 0.3,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(120, 16),
		Parent = holder,
	})
	return holder
end

-- Every frame: an arrow at the screen edge for each teammate whose character is out of sight.
local function updateArrows()
	local camera = workspace.CurrentCamera
	local state = RunStateController.get()
	local seen: { [number]: boolean } = {}
	local size = screen.AbsoluteSize
	if camera and state and size and (camera :: any).WorldToScreenPoint then
		local center = size / 2
		local half = center - Vector2.new(ARROW_MARGIN, ARROW_MARGIN)
		for _, info in state.players do
			local stateName = info.state or "Alive"
			if not info.participant or info.userId == Players.LocalPlayer.UserId or stateName == "Out" then
				continue
			end
			local player = Players:GetPlayerByUserId(info.userId)
			local character = player and player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (root and root:IsA("BasePart")) then
				continue
			end
			local point, onScreen = camera:WorldToScreenPoint(root.Position)
			local inside = onScreen and point.X >= 0 and point.Y >= 0 and point.X <= size.X and point.Y <= size.Y
			if inside then
				continue
			end
			local direction = Vector2.new(point.X, point.Y) - center
			if point.Z < 0 then
				direction = -direction
			end
			if direction.Magnitude < 1e-3 then
				continue
			end
			direction = direction.Unit
			local reach = math.min(half.X / math.abs(direction.X), half.Y / math.abs(direction.Y))
			local at = center + direction * reach
			local arrow = arrows[info.userId] or newArrow(info.name)
			arrows[info.userId] = arrow
			arrow.Position = UDim2.fromOffset(at.X, at.Y)
			local label = arrow:FindFirstChild("Arrow") :: TextLabel
			label.Rotation = math.deg(math.atan2(direction.Y, direction.X))
			label.TextColor3 = if stateName == "Down" then Theme.danger else Theme.accent
			arrow.Visible = true
			seen[info.userId] = true
		end
	end
	for userId, arrow in arrows do
		if not seen[userId] then
			arrow:Destroy()
			arrows[userId] = nil
		end
	end
end

local function render()
	local state = RunStateController.get()
	screen.Enabled = state ~= nil and RunStateController.getView() == "Run"
	if not (state and screen.Enabled) then
		return
	end
	local fighting = state.phase == "Running" or state.phase == "Boss"
	buildButton.Visible = fighting
	buildPanel.Visible = fighting and buildOpen
	for _, name in { "Health", "Team", "Timer" } do
		local object = screen:FindFirstChild(name)
		if object then
			object.Visible = fighting
		end
	end
	local hint, color = hintText(state)
	hintLabel.Text = hint
	hintLabel.TextColor3 = color
	placeTeamPanel()
	renderTeam(state)
	renderHp()
	renderWeapons()
	renderItems()
	renderXp()
	renderBonuses()
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
		TextSize = 30,
		Size = UDim2.new(1, 0, 0, 34),
		TextColor3 = Theme.accent,
		LayoutOrder = 1,
		Parent = top,
	})
	hintLabel = Widgets.label({ TextSize = 18, LayoutOrder = 2, Parent = top })
	previewLabel = Widgets.label({
		Name = "WavePreview",
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 16,
		Font = Theme.fontBold,
		TextColor3 = CHALLENGE_COLOR,
		Visible = false,
		LayoutOrder = 3,
		Parent = top,
	})
	Tooltip.attach(previewLabel, function()
		local state = RunStateController.get()
		return TooltipText.wavePlan(wavePlan, if state then state.wave + 1 else 1)
	end)

	local team = Widgets.panel({
		Name = "Team",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8 + SettingsController.RESERVED_HEIGHT),
		Size = UDim2.fromOffset(260, 0),
		Parent = screen,
	})
	teamPanel = team
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
	buildPanel = weapons
	weapons.Visible = false
	weapons.ZIndex = 3
	buildButton = Widgets.button({
		Name = "BuildToggle",
		Text = "BUILD  +",
		TextSize = 16,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(132, 44),
		Parent = screen,
	}, function()
		buildOpen = not buildOpen
		buildPanel.Visible = buildOpen
		buildButton.Text = if buildOpen then "BUILD  −" else "BUILD  +"
	end)
	weapons.Position = UDim2.fromOffset(12, 64)
	weapons.Size = UDim2.fromOffset(300, 360)
	weapons.AutomaticSize = Enum.AutomaticSize.None
	local buildScroll = Widgets.create("ScrollingFrame", {
		Name = "BuildContent",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		Parent = weapons,
	})
	local buildList = Widgets.list(6)
	buildList.VerticalAlignment = Enum.VerticalAlignment.Top
	buildList.Parent = buildScroll
	weaponsTitle = Widgets.label({
		Name = "WeaponsTitle",
		Text = "WEAPONS",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = buildScroll,
	})
	weaponRows = Widgets.create("Frame", {
		Name = "WeaponRows",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		Parent = buildScroll,
	})
	Widgets.list(4).Parent = weaponRows
	itemsTitle = Widgets.label({
		Name = "ItemsTitle",
		Text = "ITEMS",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		LayoutOrder = 2,
		Parent = buildScroll,
	})
	itemRows = Widgets.create("Frame", {
		Name = "ItemRows",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 3,
		Parent = buildScroll,
	})
	Widgets.list(4).Parent = itemRows

	local hp = Widgets.panel({
		Name = "Health",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(HP_BAR_WIDTH, 0),
		Parent = screen,
	})
	Widgets.list(6).Parent = hp
	bonusLabel = Widgets.label({
		Name = "Bonuses",
		Text = "",
		TextSize = 15,
		TextColor3 = Theme.tiers[2],
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Visible = false,
		LayoutOrder = 0,
		Parent = hp,
	})
	local track = Widgets.create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.button,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 1,
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

	local function resizeHud()
		local area = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
		local narrow = area.X < 700
		Widgets.unscaled(top)
		Widgets.unscaled(hp)
		Widgets.unscaled(weapons)
		Widgets.unscaled(team)
		top.Size = UDim2.fromOffset(
			if narrow then math.max(140, math.min(200, area.X - 180)) else math.min(320, area.X - 480),
			0
		)
		top.AnchorPoint = Vector2.new(if narrow then 0 else 0.5, 0)
		top.Position = if narrow then UDim2.fromOffset(12, 8) else UDim2.new(0.5, 0, 0, 8)
		hp.Size = UDim2.fromOffset(math.min(HP_BAR_WIDTH, area.X - 120), 0)
		team.Size = UDim2.fromOffset(if narrow then 150 elseif area.X < 1100 then 200 else 260, 0)
		buildButton.Position = UDim2.fromOffset(12, if narrow then 234 else 12)
		weapons.Position = UDim2.fromOffset(12, if narrow then 284 else 128)
		weapons.Size = UDim2.fromOffset(
			math.min(340, area.X - 24),
			math.max(120, math.min(360, area.Y - (if narrow then 384 else 234)))
		)
		placeTeamPanel()
		local current = RunStateController.get()
		if current then
			renderTeam(current)
		end
	end
	resizeHud()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeHud)
	end
	arrowLayer = Widgets.create("Frame", {
		Name = "TeamArrows",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
		Parent = screen,
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

function HUDController.init()
	Net.onClient("WavePlan", function(list: { Types.WaveChallenge })
		wavePlan = list
	end)
	RunStateController.Changed:Connect(function()
		if RunStateController.getView() ~= "Run" then
			wavePlan = {} -- belongs to the run that ended
		end
	end)
	Net.onClient("ActiveBonuses", function(list: { Types.ActiveBonus })
		bonuses = list
		if screen then
			renderBonuses()
		end
	end)
end

-- The planned elite and horde waves the server sent (tests).
function HUDController.getWavePlan(): { Types.WaveChallenge }
	return wavePlan
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
	ProgressController.ItemsChanged:Connect(function(userId: number)
		if screen.Enabled and userId == Players.LocalPlayer.UserId then
			renderItems()
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
			updateArrows()
		end
	end)
end

return HUDController
