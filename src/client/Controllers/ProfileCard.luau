--!strict
-- Paket 12 lobby extension: the local player's saved record (runs, wins, best wave, kills) under the player list,
-- with a hint when Studio does not save for real. Mounted and rendered by LobbyController; reads ProfileInfo.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local ProfileCard = {}

local info: Types.ProfileInfo? = nil
local recordLabel: TextLabel?
local saveLabel: TextLabel?

function ProfileCard.get(): Types.ProfileInfo?
	return info
end

function ProfileCard.render()
	if not (recordLabel and saveLabel) then
		return
	end
	if not info then
		recordLabel.Text = "Loading your saved record..."
		saveLabel.Visible = false
		return
	end
	local danger = if info.bestDanger >= 0 then ` · won on danger {info.bestDanger}` else ""
	recordLabel.Text = `{info.runs} runs · {info.wins} wins · best wave {info.bestWave}{danger}\n`
		.. `{info.kills} kills · {info.bossKills} bosses`
	saveLabel.Visible = info.saveMode ~= "DataStore"
	saveLabel.Text = if info.saveMode == "Mock"
		then "Studio test: not saved (API access is off)"
		else "Not saved (no DataStore)"
end

-- Adds the record lines at the end of the lobby's player list panel.
function ProfileCard.mount(list: Frame)
	Widgets.label({
		Name = "RecordTitle",
		Text = "YOUR SAVED RECORD",
		Font = Theme.fontBold,
		TextColor3 = Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 10,
		Parent = list,
	})
	recordLabel = Widgets.label({
		Name = "Record",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 11,
		Parent = list,
	})
	saveLabel = Widgets.label({
		Name = "SaveMode",
		TextSize = 14,
		TextColor3 = Theme.danger,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		LayoutOrder = 12,
		Parent = list,
	})
	Net.onClient("ProfileInfo", function(payload: Types.ProfileInfo)
		info = payload
		ProfileCard.render()
	end)
	ProfileCard.render()
end

return ProfileCard
