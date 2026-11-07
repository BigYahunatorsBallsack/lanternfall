--!strict
-- B10 lobby extension; mounted by LobbyController, which owns visibility and READY.
-- Since Paket 13 locked characters show what unlocks them and the highest danger level open for the character;
-- since Paket 17 also their Ember shop price.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local CharacterRules = require(Shared.Util.CharacterRules)
local CharacterAccess = require(Shared.Util.CharacterAccess)
local ProgressRules = require(Shared.Util.ProgressRules)
local ProfileCard = require(script.Parent.ProfileCard)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local Icons = require(script.Parent.Parent.UI.Icons)
local Tooltip = require(script.Parent.Parent.UI.Tooltip)
local Signal = require(Shared.Util.Signal)
local CharacterChoice = {}
CharacterChoice.Chosen = Signal.new()
local step = "Character"
local requestedClass: string? = nil
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

local function canChooseWeapon(classId: string, weaponId: string): boolean
	if not Config.Classes[classId].nativeStartSelection then
		return true
	end
	local info = ProfileCard.get()
	if info and info.nativeWeaponUnlocks then
		return info.nativeWeaponUnlocks[weaponId] == true
	end
	return CharacterAccess.weaponUnlocked(nil, weaponId)
end

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
		button.CharacterName.TextColor3 = if unlocked then Theme.text else Theme.textDim
		button.LockLabel.Visible = not unlocked
		local price = Config.Progress.characterPrices[classId]
		button.UnlockPrice.Visible = not unlocked and price ~= nil
		button.UnlockPrice.Text = if price then `{price} EMBERS` else ""
		button.SelectionMark.Visible = false
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
	if requestedClass == me.classId then
		requestedClass = nil
		CharacterChoice.Chosen:Fire("Weapon")
	end
	selectedName.Text = class.displayName
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
				if not canChooseWeapon(class.id, weaponId) then
					return
				end
				if os.clock() - lastPress < 0.3 then
					return
				end
				lastPress = os.clock()
				Net.fireServer("SelectStartWeapon", class.id, weaponId)
				CharacterChoice.Chosen:Fire("Difficulty")
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
			Widgets.label({
				Name = "LockLabel",
				Text = "LOCKED",
				TextSize = 12,
				TextColor3 = Theme.textDim,
				Position = UDim2.fromOffset(0, 62),
				Size = UDim2.new(1, 0, 0, 18),
				Parent = tile,
			})
		end
	end
	for weaponId, button in buttons do
		local allowed = canChooseWeapon(me.classId, weaponId)
		local chosen = allowed and weaponId == (selected[me.classId] or class.startWeapon)
		button.Active = allowed
		button.LockLabel.Visible = not allowed
		button.BackgroundColor3 = if chosen then Theme.accent elseif allowed then Theme.button else Theme.panel
		button.TextColor3 = if not allowed then Theme.textDim elseif chosen then Theme.accentText else Theme.text
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
		button.Activated:Connect(function()
			if CharacterChoice.isUnlocked(classId) then
				requestedClass = classId
				local me = RunStateController.getLocalPlayer()
				if me and me.classId == classId then
					requestedClass = nil
					CharacterChoice.Chosen:Fire("Weapon")
				end
			end
		end)
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
	summary = Widgets.create("Frame", {
		Name = "CharacterSummary",
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.65,
		BorderSizePixel = 0,
		Parent = stage,
	}, { Widgets.corner(), Widgets.create("UIStroke", { Color = Theme.stroke, Thickness = 3 }) })
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
	summary:FindFirstChildOfClass("UIStroke").Thickness = 0
	selectedName.TextStrokeTransparency = 0
	selectedName.TextStrokeColor3 = Theme.stroke
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

function CharacterChoice.setStep(value: string)
	step = value
end

function CharacterChoice.resize(width: number, _height: number?)
	if not weaponRow or not details then
		return
	end
	local compact = width < 860
	local summaryWidth = if compact then width else 500
	local summaryHeight = if compact then 300 else 334
	local x = if compact then 0 else math.max(0, (width - (if step == "Difficulty" then 1000 else 730)) / 2)
	choiceTitle.Visible = false
	stage.Size = UDim2.new(1, 0, 0, if compact then 490 else 500)
	summary.Position = UDim2.fromOffset(x, 0)
	summary.Size = UDim2.fromOffset(summaryWidth, summaryHeight)
	selectedName.Position = UDim2.fromOffset(8, 4)
	selectedName.Size = UDim2.new(1, -16, 0, 50)
	selectedName.TextSize = if compact then 30 else 40
	selectedName.TextXAlignment = Enum.TextXAlignment.Center
	portrait.Position = UDim2.fromOffset(16, 62)
	portrait.Size = UDim2.fromOffset(if compact then 112 else 176, if compact then 140 else 196)
	portrait.BackgroundTransparency = 0
	portrait.BackgroundColor3 = Theme.surface
	metrics.Visible = false
	ruleArea.Position = UDim2.fromOffset(if compact then 140 else 208, 106)
	ruleArea.Size = UDim2.new(1, if compact then -150 else -220, 0, if compact then 174 else 188)
	details.TextSize = if compact then 15 else 16
	details.Text = string.gsub(details.Text or "", "; ", "\n")
	local count = 0
	for _ in classButtons do
		count += 1
	end
	local tile = if compact then 56 else 52
	local columns = math.max(1, math.min(count, math.floor(width / (tile + 6))))
	local rows = math.ceil(count / columns)
	classRow.Visible = step == "Character"
	classRow.AnchorPoint = Vector2.new(0.5, 0)
	classRow.Position = UDim2.new(0.5, 0, 0, summaryHeight + 26)
	classRow.Size = UDim2.fromOffset(columns * (tile + 6) - 6, rows * (tile + 6))
	local grid = classRow:FindFirstChildOfClass("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(tile, tile)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	for _, button in classButtons do
		button.Artwork.AnchorPoint = Vector2.new(0, 0)
		button.Artwork.Position = UDim2.fromOffset(2, 2)
		button.Artwork.Size = UDim2.fromOffset(tile - 4, tile - 4)
		button.CharacterName.Visible = false
		button.UnlockPrice.Visible = false
		button.LockLabel.Text = "LOCKED"
		button.LockLabel.TextSize = 10
		button.LockLabel.TextStrokeTransparency = 0
	end
	weaponRow.Parent = stage
	weaponRow.Visible = step == "Weapon"
	weaponRow.AnchorPoint = Vector2.new(0.5, 0)
	weaponRow.Position = UDim2.new(0.5, 0, 0, summaryHeight + 26)
	local weaponCount = 0
	for _ in buttons do
		weaponCount += 1
	end
	local weaponColumns = math.max(1, math.min(weaponCount, math.floor(width / 70)))
	weaponRow.Size = UDim2.fromOffset(weaponColumns * 70 - 8, math.ceil(weaponCount / weaponColumns) * 70)
	local weaponGrid = weaponRow:FindFirstChildOfClass("UIGridLayout")
	weaponGrid.CellSize = UDim2.fromOffset(62, 62)
	weaponGrid.CellPadding = UDim2.fromOffset(8, 8)
	for _, button in buttons do
		button.Artwork.Size = UDim2.fromOffset(58, 58)
		button.WeaponName.Visible = false
	end
	for _, child in weaponRow.Parent.Parent:GetChildren() do
		if child:IsA("TextLabel") and child.Name == "WeaponHeading" then
			child.Visible = false
		end
	end
end

function CharacterChoice.getStartWeapon(): string?
	local me = RunStateController.getLocalPlayer()
	local class = me and Config.Classes[me.classId]
	return if me and class then selected[me.classId] or class.startWeapon else nil
end

return CharacterChoice
