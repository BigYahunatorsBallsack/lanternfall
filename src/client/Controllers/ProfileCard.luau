--!strict
-- Paket 12 lobby extension: the local player's saved record (runs, wins, best wave, kills) under the player list,
-- with a hint when Studio does not save for real. Mounted and rendered by LobbyController; reads ProfileInfo.
-- Since Paket 13 also the Embers and an "ACHIEVEMENTS" button that opens AchievementList; CharacterChoice and
-- DangerChoice read the unlocks from ProfileCard.get(). Since Paket 16 the STORE button and the Ember Boost line below
-- it (StoreController).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local AchievementList = require(script.Parent.AchievementList)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local ProfileCard = {}

local info: Types.ProfileInfo? = nil
local recordLabel: TextLabel?
local saveLabel: TextLabel?
local achievementsButton: TextButton?

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
	recordLabel.Text = `{info.embers or 0} Embers\n`
		.. `{info.runs} runs · {info.wins} wins · best wave {info.bestWave}{danger}\n`
		.. `{info.kills} kills · {info.bossKills} bosses`
	if achievementsButton then
		local done = 0
		for _ in info.achievements or {} do
			done += 1
		end
		achievementsButton.Text = `ACHIEVEMENTS {done}/{#Config.Progress.achievements}`
	end
	AchievementList.render(info)
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
	achievementsButton = Widgets.button({
		Name = "OpenAchievements",
		Text = "ACHIEVEMENTS",
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 38),
		LayoutOrder = 13,
		Parent = list,
	}, function()
		require(script.Parent.StoreController).setOpen(false) -- Paket 16: one window at a time
		AchievementList.setOpen(not AchievementList.isOpen())
	end)
	AchievementList.mount(list.Parent :: Instance)
	require(script.Parent.StoreController).mount(list) -- Paket 16
	Net.onClient("ProfileInfo", function(payload: Types.ProfileInfo)
		info = payload
		ProfileCard.render()
		-- unlocks changed: the other lobby extensions read them (required here, they require ProfileCard)
		require(script.Parent.CharacterChoice).render()
		require(script.Parent.DangerChoice).render()
	end)
	ProfileCard.render()
end

return ProfileCard
