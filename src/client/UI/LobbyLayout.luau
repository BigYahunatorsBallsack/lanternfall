--!strict
-- Main menu and preparation pages mounted by LobbyController; the original controls retain their server commands.
local Widgets = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Backdrop = require(script.Parent.MenuBackdrop)
local OfferText = require(script.Parent.OfferText)
local CharacterChoice = require(script.Parent.Parent.Controllers.CharacterChoice)
local ProfileCard = require(script.Parent.Parent.Controllers.ProfileCard)
local RunState = require(script.Parent.Parent.Controllers.RunStateController)
local Party = require(script.Parent.Parent.Controllers.PartyController)
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local StatMath = require(Shared.Util.StatMath)
local WeaponClasses = require(Shared.Util.WeaponClasses)
local Layout = {}
local refresh: (() -> ())? = nil

local function place(object: GuiObject, x: number, y: number, width: number, height: number)
	object.AnchorPoint = Vector2.new(0, 0)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(width, height)
end

function Layout.mount(screen: ScreenGui, choose: Frame, players: Frame, record: Frame, status: Frame)
	Backdrop.mount(screen)
	local root = Widgets.create("Frame", { Name = "LobbyPages", BackgroundTransparency = 1, Parent = screen })
	local scale = Widgets.create("UIScale", { Parent = root })
	local storage = Widgets.create("Folder", { Name = "LayoutStorage", Parent = screen })
	local step = "Main"
	local title = Widgets.label({ Name = "PageTitle", TextSize = 40, TextStrokeTransparency = 0, Parent = root })
	local main = Widgets.create(
		"Frame",
		{ Name = "MainMenu", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root }
	)
	local brand = Widgets.label({
		Name = "Brand",
		Text = "LANTERNFALL",
		TextSize = 80,
		Font = Theme.fontBold,
		TextStrokeTransparency = 0,
		Parent = main,
	})
	local tagline =
		Widgets.label({ Text = "SURVIVE THE NIGHT", TextSize = 34, TextStrokeTransparency = 0, Parent = main })
	local hero = Icons.holder(main, 390)
	Icons.draw(hero, "character", "NightWatch")
	local secondHero = Icons.holder(main, 320)
	Icons.draw(secondHero, "character", "SparkMage")
	local function show(value: string)
		ProfileCard.closeWindows()
		step = value
		Layout.refresh()
	end
	local menuButtons = {}
	for index, entry in
		{
			{ "Start", "Start", "Character" },
			{ "OpenCollection", "Collection", "Collection" },
			{ "OpenParty", "Co-op", "Party" },
			{ "Options", "Options", "Options" },
		}
	do
		menuButtons[index] = Widgets.button({
			Name = entry[1],
			Text = entry[2],
			TextSize = 26,
			Font = Theme.font,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = main,
		}, function()
			if entry[3] == "Options" then
				require(script.Parent.Parent.Controllers.SettingsController).setOpen(true)
			else
				show(entry[3])
			end
		end)
	end
	local back = Widgets.button({
		Name = "LobbyBack",
		Text = "←     Back",
		Font = Theme.font,
		TextSize = 18,
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.fromOffset(158, 34),
		Parent = root,
	}, function()
		show(({ Weapon = "Character", Difficulty = "Weapon" })[step] or "Main")
	end)
	local scroll = Widgets.create("ScrollingFrame", {
		Name = "LobbyContent",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = root,
	})
	local content = Widgets.create("Frame", { Name = "Page", BackgroundTransparency = 1, Parent = scroll })
	local danger = screen:FindFirstChild("Danger") :: Frame
	for _, panel in { choose, danger, players, record, status } do
		Widgets.unscaled(panel)
		panel.Parent = content
		local outline = panel:FindFirstChildOfClass("UIStroke")
		if outline then
			outline.Thickness = 0
		end
	end
	for _, child in choose:GetChildren() do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			child.Parent = storage
		end
	end
	choose.BackgroundTransparency = 1
	choose.AutomaticSize = Enum.AutomaticSize.None
	status.BackgroundTransparency = 1
	status.Parent = root
	for _, child in status:GetChildren() do
		if child:IsA("UIStroke") or child:IsA("UIPadding") then
			child.Parent = storage
		end
		if child:IsA("TextLabel") then
			child.TextSize = 14
		end
	end
	local footer = Widgets.create("Frame", { Name = "LobbyFooter", BackgroundTransparency = 1, Parent = root })
	Widgets.list(6).Parent = footer
	for order, name in { "Ready", "HubActions", "BackToHub" } do
		local action = choose:FindFirstChild(name)
		if action and action:IsA("GuiObject") then
			action.Parent = footer
			action.LayoutOrder = order
			action.Size = UDim2.new(1, 0, 0, if name == "BackToHub" then 34 else 44)
		end
	end
	local weapon = Widgets.create(
		"Frame",
		{ Name = "WeaponPreview", BackgroundColor3 = Theme.button, BorderSizePixel = 0, Parent = content },
		{ Widgets.corner() }
	)
	local weaponArt = Icons.holder(weapon, 64)
	weaponArt.Position = UDim2.fromOffset(12, 12)
	local weaponName = Widgets.label({
		Name = "WeaponName",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(84, 12),
		Size = UDim2.new(1, -96, 0, 26),
		Parent = weapon,
	})
	local weaponClass = Widgets.label({
		TextSize = 16,
		TextColor3 = Theme.statLabel,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(84, 40),
		Size = UDim2.new(1, -96, 0, 38),
		Parent = weapon,
	})
	local weaponStats = Widgets.label({
		Name = "WeaponStats",
		TextSize = 14,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(12, 90),
		Size = UDim2.new(1, -24, 1, -102),
		Parent = weapon,
	})
	local runOptions = Widgets.create(
		"Frame",
		{ Name = "RunOptions", BackgroundColor3 = Theme.button, BorderSizePixel = 0, Parent = content },
		{ Widgets.corner() }
	)
	Widgets.label({
		Text = "Run options",
		TextSize = 22,
		Position = UDim2.fromOffset(12, 20),
		Size = UDim2.new(1, -24, 0, 32),
		Parent = runOptions,
	})
	Widgets.label({
		Text = "Lantern Ruins",
		TextSize = 20,
		Position = UDim2.fromOffset(12, 74),
		Size = UDim2.new(1, -24, 0, 44),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0,
		Parent = runOptions,
	})
	Widgets.label({
		Text = "20 waves",
		TextSize = 18,
		Position = UDim2.fromOffset(12, 140),
		Size = UDim2.new(1, -24, 0, 30),
		Parent = runOptions,
	})
	Widgets.button({
		Name = "PrepareParty",
		Text = "Co-op",
		TextSize = 20,
		Position = UDim2.fromOffset(12, 198),
		Size = UDim2.new(1, -24, 0, 44),
		Parent = runOptions,
	}, function()
		show("Party")
	end)
	local levels = danger:FindFirstChild("Levels") :: Frame
	levels.Parent = content
	levels:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 8)
	local palette = {
		Theme.panel,
		Color3.fromRGB(60, 90, 104),
		Color3.fromRGB(85, 58, 105),
		Color3.fromRGB(116, 59, 56),
		Color3.fromRGB(128, 85, 48),
		Color3.fromRGB(101, 95, 48),
	}
	local advanced = Widgets.panel({
		Name = "RunAdjustments",
		Visible = false,
		Size = UDim2.fromOffset(380, 0),
		Parent = screen,
		ZIndex = 8,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	Widgets.list(8).Parent = advanced
	Widgets.label({ Text = "Enemy settings", TextSize = 24, LayoutOrder = 0, Parent = advanced })
	for _, child in danger:GetChildren() do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			child.Parent = storage
		end
		if child:IsA("Frame") and string.sub(child.Name, 1, 7) == "Slider_" then
			child.Parent = advanced
		end
	end
	Widgets.button({ Text = "Close", LayoutOrder = 20, Parent = advanced }, function()
		advanced.Visible = false
	end)
	local adjustments = Widgets.button(
		{ Name = "EnemySettings", Text = "Enemy settings", Font = Theme.font, TextSize = 14, Parent = content },
		function()
			advanced.Visible = not advanced.Visible
		end
	)
	CharacterChoice.Chosen:Connect(show)
	refresh = function()
		local area = screen.AbsoluteSize
		if typeof(area) ~= "Vector2" or area.X <= 0 then
			area = workspace.CurrentCamera.ViewportSize
		end
		local compact = area.X < 1000 or area.Y < 600
		local factor = if compact then 1 else math.min(area.X / 1280, area.Y / 720)
		local width, height = area.X / factor, area.Y / factor
		scale.Scale = factor
		root.Size = UDim2.fromOffset(width, height)
		main.Visible = step == "Main"
		back.Visible = step ~= "Main"
		title.Visible = step ~= "Main"
		title.Text = ({
			Character = "Character Selection",
			Weapon = "Weapon Selection",
			Difficulty = "Difficulty Selection",
			Party = "Co-op",
			Collection = "Collection",
		})[step] or ""
		place(
			title,
			if compact then 16 else 180,
			if compact then 56 else 40,
			if compact then width - 32 else width - 360,
			52
		)
		title.TextSize = if compact then 28 else 40
		place(
			brand,
			if compact then 16 else width * 0.4,
			if compact then 80 else 52,
			if compact then width - 32 else width * 0.58,
			100
		)
		brand.TextSize = if compact then math.min(48, width / 9) else 80
		place(
			tagline,
			if compact then 16 else width * 0.4,
			if compact then 165 else 152,
			if compact then width - 32 else width * 0.58,
			60
		)
		tagline.TextSize = if compact then 22 else 34
		place(hero, width * 0.2, 255, 390, 390)
		place(secondHero, width - 360, height - 335, 320, 320)
		hero.Visible, secondHero.Visible = not compact, not compact
		for index, button in menuButtons do
			place(
				button,
				32,
				(if compact then 240 else height - 340) + (index - 1) * 50,
				if compact then width - 64 else 205,
				44
			)
		end
		choose.Visible = step == "Character" or step == "Weapon" or step == "Difficulty"
		danger.Visible, players.Visible, record.Visible = step == "Difficulty", step == "Party", step == "Collection"
		runOptions.Visible = step == "Character"
		weapon.Visible = step == "Weapon" or step == "Difficulty"
		levels.Visible, adjustments.Visible = step == "Difficulty", step == "Difficulty"
		if not screen.Enabled then
			advanced.Visible = false
		end
		scroll.Visible = step ~= "Main"
		local footerHeight = 0
		for _, action in footer:GetChildren() do
			if action:IsA("GuiObject") and action.Visible then
				footerHeight += action.Size.Y.Offset + 6
			end
		end
		footer.Visible = step == "Difficulty"
		place(
			footer,
			if compact then 12 else width - 290,
			height - footerHeight - 12,
			if compact then width - 24 else 274,
			footerHeight
		)
		status.Visible = step == "Difficulty" and not compact
		place(status, 16, height - 42, width - 330, 30)
		local top = if compact then 108 else 116
		place(scroll, 16, top, width - 32, height - top - 12 - (if footer.Visible then footerHeight + 12 else 0))
		local innerWidth = width - 32
		place(content, 0, 0, innerWidth, if compact and choose.Visible then 810 else 500)
		place(choose, 0, 0, innerWidth, 500)
		CharacterChoice.setStep(step)
		CharacterChoice.resize(innerWidth, height)
		local startX = math.max(0, (innerWidth - (if step == "Difficulty" then 1000 else 730)) / 2)
		place(
			runOptions,
			if compact then 0 else startX + 516,
			if compact then 550 else 0,
			if compact then innerWidth else 214,
			if compact then 260 else 334
		)
		place(
			weapon,
			if compact then 0 else startX + 516,
			if compact then 440 else 0,
			if compact then innerWidth else 232,
			if compact then 300 else 334
		)
		place(
			danger,
			if compact then 0 else startX + 764,
			if compact then 440 else 0,
			if compact then innerWidth else 232,
			if compact then 230 else 334
		)
		danger.AutomaticSize = Enum.AutomaticSize.None
		danger.BackgroundColor3 = Theme.button
		local state, party = RunState.get(), Party.get()
		local options = if party and party.role == "Hub" then party.options else state and state.options
		local selected = if options then options.danger else 0
		local dangerTitle = danger:FindFirstChild("Title") :: TextLabel
		dangerTitle.Text = `Danger {selected}\nDifficulty`
		dangerTitle.TextColor3, dangerTitle.TextSize = Theme.statLabel, 22
		place(dangerTitle, 12, 16, 208, 60)
		local description = danger:FindFirstChild("Description") :: TextLabel
		place(description, 12, 94, if compact then innerWidth - 24 else 208, 190)
		description.TextXAlignment, description.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
		local tile = if compact and innerWidth < 430 then (innerWidth - 40) / 6 else 62
		local rowWidth = 6 * tile + 40
		place(levels, (innerWidth - rowWidth) / 2, if compact then 348 else 366, rowWidth, tile)
		for index, level in Config.Difficulty.levels do
			local button = levels:FindFirstChild(`Danger{level.level}`) :: TextButton
			button.Size, button.TextSize = UDim2.fromOffset(tile, tile), tile - 10
			button.TextColor3 = Color3.fromRGB(236, 206, 86)
			button.TextStrokeTransparency = 0
			button.BackgroundColor3 = if level.level == selected then Theme.accent else palette[index]
		end
		place(
			adjustments,
			if compact then 0 else startX + 764,
			if compact then 690 else 442,
			if compact then innerWidth else 232,
			34
		)
		for _, page in { players, record } do
			page.AnchorPoint = Vector2.new(0.5, 0)
			page.Position, page.Size = UDim2.fromScale(0.5, 0), UDim2.fromOffset(math.min(680, innerWidth), 0)
			page.AutomaticSize = Enum.AutomaticSize.Y
		end
		content.AutomaticSize = if players.Visible or record.Visible
			then Enum.AutomaticSize.Y
			else Enum.AutomaticSize.None
		local id, me = CharacterChoice.getStartWeapon(), RunState.getLocalPlayer()
		if id and Config.Weapons[id] then
			Icons.draw(weaponArt, "weapon", id)
			weaponName.Text, weaponClass.Text = Config.Weapons[id].displayName, WeaponClasses.names(id)
			local sheet = StatMath.baseSheet()
			local class = me and Config.Classes[me.classId]
			for key, value in if class then class.stats else {} do
				sheet[key] = (sheet[key] or 0) + value
			end
			local _, text = OfferText.weapon(id, 1, sheet)
			weaponStats.Text = text
		end
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(Layout.refresh)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Layout.refresh)
	end
	Layout.refresh()
end

function Layout.refresh()
	if refresh then
		refresh()
	end
end
return Layout
