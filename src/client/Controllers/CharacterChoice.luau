--!strict
-- B10 lobby extension; mounted by LobbyController, which owns visibility and READY.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local CharacterRules = require(Shared.Util.CharacterRules)
local RunStateController = require(script.Parent.RunStateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local CharacterChoice = {}
local selected: { [string]: string } = {}
local details: TextLabel?
local weaponRow: Frame?
local renderedClass: string? = nil
local buttons: { [string]: TextButton } = {}
local lastPress = 0

function CharacterChoice.render()
	local me = RunStateController.getLocalPlayer()
	if not me or not details or not weaponRow then
		return
	end
	local class = Config.Classes[me.classId]
	if not class then
		return
	end
	details.Text = `{class.displayName} · {CharacterRules.maxWeapons(me.classId)} slots\n{class.description}`
	if renderedClass ~= me.classId then
		renderedClass = me.classId
		Widgets.clearRows(weaponRow)
		table.clear(buttons)
		for index, weaponId in class.startWeapons do
			buttons[weaponId] = Widgets.button({
				Name = `Start_{weaponId}`,
				Text = Config.Weapons[weaponId].displayName,
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
		end
	end
	for weaponId, button in buttons do
		local chosen = weaponId == (selected[me.classId] or class.startWeapon)
		button.BackgroundColor3 = if chosen then Theme.accent else Theme.button
		button.TextColor3 = if chosen then Theme.accentText else Theme.text
	end
end

function CharacterChoice.mount(card: Frame, row: Frame, classButtons: { [string]: TextButton })
	-- Reuse the existing buttons and handlers; keep the shared lobby module append-only.
	for _, child in card:GetChildren() do
		if child:IsA("TextLabel") then
			child.Text = "CHOOSE YOUR CHARACTER AND STARTING WEAPON"
		end
	end
	for _, child in row:GetChildren() do
		if child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	row.Size = UDim2.new(1, 0, 0, 132)
	Widgets.create("UIGridLayout", {
		CellSize = UDim2.new(0.2, -6, 0, 62),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	for classId, button in classButtons do
		button.Text = Config.Classes[classId].displayName
		button.TextSize = 16
	end
	details = Widgets.label({
		Name = "CharacterRules",
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 90),
		LayoutOrder = 3,
		Parent = card,
	})
	weaponRow = Widgets.create("Frame", {
		Name = "StartingWeapons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 54),
		LayoutOrder = 4,
		Parent = card,
	})
	Widgets.list(6, Enum.FillDirection.Horizontal).Parent = weaponRow
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

return CharacterChoice
