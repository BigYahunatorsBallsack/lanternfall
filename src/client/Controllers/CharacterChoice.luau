--!strict
-- B10 lobby extension; mounted by LobbyController, which owns visibility and READY.
-- Since Paket 13 locked characters show what unlocks them and the highest danger level open for the character;
-- since Paket 17 also their Ember shop price.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local CharacterRules = require(Shared.Util.CharacterRules)
local ProgressRules = require(Shared.Util.ProgressRules)
local ProfileCard = require(script.Parent.ProfileCard)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local Icons = require(script.Parent.Parent.UI.Icons)
local Tooltip = require(script.Parent.Parent.UI.Tooltip)
local CharacterChoice = {}
local selected: { [string]: string } = {}
local details: TextLabel?
local weaponRow: Frame?
local renderedClass: string? = nil
local buttons: { [string]: TextButton } = {}
local lastPress = 0
local stage: Frame
local classRow: Frame
local summary: Frame
local portrait: Frame
local selectedName: TextLabel
local metrics: TextLabel
local ruleArea: ScrollingFrame
local classButtons: { [string]: TextButton } = {}
local choiceTitle: TextLabel

-- Paket 13: whether the local player has unlocked a character (lockable ones count as locked until loaded).
function CharacterChoice.isUnlocked(classId: string): boolean
	local info = ProfileCard.get()
	return ProgressRules.isUnlocked(
		"characters",
		classId,
		if info then info.achievements or {} else {},
		if info then info.ownedClasses else nil
	)
end

-- Paket 13: highest danger level the local player has open with a character.
function CharacterChoice.maxDanger(classId: string): number
	local info = ProfileCard.get()
	local open = info and info.characterDanger and info.characterDanger[classId]
	return open or Config.Progress.startDanger
end

local function renderLocks()
	local me = RunStateController.getLocalPlayer()
	for classId, button in classButtons do
		local unlocked = CharacterChoice.isUnlocked(classId)
		local chosen = me ~= nil and me.classId == classId
		button.Text = ""
		button.CharacterName.Text = Config.Classes[classId].displayName
		button.CharacterName.TextColor3 = if chosen
			then Theme.accentText
			elseif unlocked then Theme.text
			else Theme.textDim
		button.LockLabel.Visible = not unlocked
		local price = Config.Progress.characterPrices[classId]
		button.UnlockPrice.Visible = not unlocked and price ~= nil
		button.UnlockPrice.Text = if price then `{price} EMBERS` else ""
		button.SelectionMark.Visible = chosen
		button.Outline.Color = if chosen then Theme.accent else Theme.stroke
		button.Outline.Thickness = if chosen then 4 else 3
		if not unlocked then
			button.BackgroundColor3 = Theme.panel
		end
	end
end

function CharacterChoice.render()
	renderLocks()
	local me = RunStateController.getLocalPlayer()
	if not me or not details or not weaponRow then
		return
	end
	local class = Config.Classes[me.classId]
	if not class then
		return
	end
	selectedName.Text = string.upper(class.displayName)
	metrics.Text = `{CharacterRules.maxWeapons(me.classId)} WEAPONS\nDANGER {CharacterChoice.maxDanger(me.classId)}`
	details.Text = string.gsub(class.description, ", ", "\n")
	Icons.draw(portrait, "character", me.classId)

	if renderedClass ~= me.classId then
		renderedClass = me.classId
		Widgets.clearRows(weaponRow)
		table.clear(buttons)
		for index, weaponId in class.startWeapons do
			buttons[weaponId] = Widgets.button({
				Name = `Start_{weaponId}`,
				Text = "",
				TextSize = 15,
				Size = UDim2.new(1 / #class.startWeapons, -6, 1, 0),
				LayoutOrder = index,
				Parent = weaponRow,
			}, function()
				if os.clock() - lastPress < 0.3 then
					return
				end
				lastPress = os.clock()
				Net.fireServer("SelectStartWeapon", class.id, weaponId)
			end)
			local tile = buttons[weaponId]
			local art = Icons.holder(tile, 80)
			art.AnchorPoint = Vector2.new(0.5, 0)
			art.Position = UDim2.new(0.5, 0, 0, 2)
			Icons.draw(art, "weapon", weaponId)
			Widgets.label({
				Name = "WeaponName",
				Text = Config.Weapons[weaponId].displayName,
				TextSize = 17,
				Position = UDim2.new(0, 4, 1, -30),
				Size = UDim2.new(1, -8, 0, 28),
				Parent = tile,
			})
		end
	end
	for weaponId, button in buttons do
		local chosen = weaponId == (selected[me.classId] or class.startWeapon)
		button.BackgroundColor3 = if chosen then Theme.accent else Theme.button
		button.TextColor3 = if chosen then Theme.accentText else Theme.text
		button.WeaponName.TextColor3 = button.TextColor3
		button.Outline.Color = if chosen then Theme.accent else Theme.stroke
	end
end

function CharacterChoice.mount(card: Frame, row: Frame, buttonsByClass: { [string]: TextButton })
	for _, child in card:GetChildren() do
		if child:IsA("TextLabel") then
			choiceTitle = child
			child.Text = "CHOOSE YOUR CHARACTER"
			child.TextSize = 26
			child.TextColor3 = Theme.text
			child.Size = UDim2.new(1, 0, 0, 38)
			child.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	stage = Widgets.create("Frame", {
		Name = "CharacterStage",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 290),
		LayoutOrder = 2,
		Parent = card,
	})
	classRow = row
	row.Parent = stage
	for _, child in row:GetChildren() do
		if child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	Widgets.create("UIGridLayout", {
		CellSize = UDim2.new(0.2, -8, 0, 132),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	classButtons = buttonsByClass
	for classId, button in classButtons do
		button.Text = ""
		local art = Icons.holder(button, 96)
		art.AnchorPoint = Vector2.new(0.5, 0)
		art.Position = UDim2.new(0.5, 0, 0, 2)
		Icons.draw(art, "character", classId)
		Widgets.label({
			Name = "CharacterName",
			Text = Config.Classes[classId].displayName,
			TextSize = 17,
			Font = Theme.fontBold,
			Position = UDim2.new(0, 4, 1, -47),
			Size = UDim2.new(1, -8, 0, 30),
			Parent = button,
		})
		Widgets.label({
			Name = "LockLabel",
			Text = "LOCKED",
			TextSize = 10,
			TextColor3 = Theme.textDim,
			Position = UDim2.fromOffset(0, 1),
			Size = UDim2.new(1, 0, 0, 14),
			Parent = button,
		})
		Widgets.label({
			Name = "UnlockPrice",
			TextSize = 11,
			TextColor3 = Theme.textDim,
			Position = UDim2.new(0, 4, 1, -18),
			Size = UDim2.new(1, -8, 0, 16),
			Visible = false,
			Parent = button,
		})
		Widgets.label({
			Name = "SelectionMark",
			Text = "✓",
			TextSize = 20,
			TextColor3 = Theme.accentText,
			Position = UDim2.new(1, -26, 0, 0),
			Size = UDim2.fromOffset(26, 26),
			Visible = false,
			Parent = button,
		})
		Tooltip.attach(button, function()
			local class = Config.Classes[classId]
			local requirement = ProgressRules.requirement("characters", classId)
			local price = Config.Progress.characterPrices[classId]
			local locked = (requirement or "Unlock this character in your collection")
				.. (if price then `\nor {price} Embers (Collection → Ember shop)` else "")
			return class.displayName, if CharacterChoice.isUnlocked(classId) then class.description else locked
		end)
	end
	summary = Widgets.create(
		"Frame",
		{ Name = "CharacterSummary", BackgroundColor3 = Theme.surface, BorderSizePixel = 0, Parent = stage },
		{ Widgets.corner(), Widgets.create("UIStroke", { Color = Theme.stroke, Thickness = 3 }) }
	)
	selectedName = Widgets.label({
		Name = "SelectedCharacter",
		Font = Theme.fontBold,
		TextSize = 25,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 38),
		Parent = summary,
	})
	portrait = Icons.holder(summary, 112)
	portrait.Position = UDim2.fromOffset(12, 45)
	metrics = Widgets.label({
		Name = "CharacterCapacity",
		TextSize = 15,
		TextColor3 = Theme.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(134, 54),
		Size = UDim2.new(1, -144, 0, 70),
		Parent = summary,
	})
	ruleArea = Widgets.create("ScrollingFrame", {
		Name = "RuleArea",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(14, 164),
		Size = UDim2.new(1, -28, 1, -178),
		Parent = summary,
	})
	details = Widgets.label({
		Name = "CharacterRules",
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -5, 0, 0),
		Parent = ruleArea,
	})
	Widgets.label({
		Name = "WeaponHeading",
		Text = "STARTING WEAPON",
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.fontBold,
		TextSize = 20,
		LayoutOrder = 3,
		Parent = card,
	})
	weaponRow = Widgets.create("Frame", {
		Name = "StartingWeapons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 108),
		LayoutOrder = 4,
		Parent = card,
	})
	Widgets.create("UIGridLayout", {
		CellSize = UDim2.new(0.2, -8, 0, 108),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = weaponRow,
	})
	local ready = card:FindFirstChild("Ready")
	if ready and ready:IsA("GuiObject") then
		ready.LayoutOrder = 5
	end
	Net.onClient("StartWeaponChoice", function(classId: string, weaponId: string)
		selected[classId] = weaponId
		CharacterChoice.render()
	end)
	CharacterChoice.render()
end

function CharacterChoice.resize(width: number, height: number?)
	if not weaponRow or not details then
		return
	end
	local card = weaponRow.Parent
	for _, name in { "Ready", "BackToHub" } do
		local action = card:FindFirstChild(name)
		if action then
			action.Size = UDim2.new(1, 0, 0, if name == "Ready" then 58 else 46)
		end
	end
	local wide = width >= 860
	local short = height ~= nil and height < 420
	choiceTitle.Visible = not short
	local columns = if width < 540 then 2 else 5
	local grid = classRow:FindFirstChildOfClass("UIGridLayout")
	local count = 0
	for _ in classButtons do
		count += 1
	end
	local cellHeight = if short then 100 else 132
	local gridHeight = math.ceil(count / columns) * (cellHeight + 10) - 10
	grid.CellSize = UDim2.new(1 / columns, -8, 0, cellHeight)
	for _, button in classButtons do
		local size = if short then 64 else 96
		button.Artwork.Size = UDim2.fromOffset(size, size)
		button.CharacterName.TextSize = if short then 14 else 17
		button.CharacterName.Position = UDim2.new(0, 4, 1, if short then -43 else -47)
		button.CharacterName.Size = UDim2.new(1, -8, 0, if short then 25 else 30)
	end
	classRow.Size = if wide then UDim2.new(0.63, -16, 0, gridHeight) else UDim2.new(1, 0, 0, gridHeight)
	classRow.Position = UDim2.new()
	summary.Position = if wide then UDim2.fromScale(0.63, 0) else UDim2.fromOffset(0, gridHeight + 16)
	summary.Size = if wide then UDim2.new(0.37, 0, 0, gridHeight) else UDim2.new(1, 0, 0, 262)
	stage.Size = UDim2.new(1, 0, 0, if wide then gridHeight else gridHeight + 278)
	local weaponCount = 0
	for _ in buttons do
		weaponCount += 1
	end
	local weaponColumns = if width < 540 then 2 else math.max(1, math.min(5, weaponCount))
	local weaponHeight = if short then 96 else 108
	weaponRow:FindFirstChildOfClass("UIGridLayout").CellSize = UDim2.new(1 / weaponColumns, -8, 0, weaponHeight)
	for _, button in buttons do
		local iconSize = if short then 66 else 80
		button.Artwork.Size = UDim2.fromOffset(iconSize, iconSize)
		button.WeaponName.TextSize = if short then 14 else 17
	end
	weaponRow.Size = UDim2.new(1, 0, 0, math.max(1, math.ceil(weaponCount / weaponColumns)) * (weaponHeight + 10) - 10)
end

return CharacterChoice
