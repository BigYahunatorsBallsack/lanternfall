--!strict
-- Publishes the server-approved character on selection and respawn as an attribute of the character; every client draws
-- the matching 2D sprite from it (client/CharacterArt/Visibility). Loaded by the server service loader.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RunDirector = require(script.Parent.RunDirector)

local CLASS_ATTRIBUTE = "LanternfallClassId"

local CharacterAppearanceService = {}

local function selected(player: Player): string
	return RunDirector.getParticipantClassId(player)
		or RunDirector.getSelectedClassId(player)
		or Config.Run.flow.defaultClassId
end

function CharacterAppearanceService.refresh(player: Player)
	local character = player.Character
	if character then
		character:SetAttribute(CLASS_ATTRIBUTE, selected(player))
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		CharacterAppearanceService.refresh(player)
	end)
	CharacterAppearanceService.refresh(player)
end

function CharacterAppearanceService.init()
	RunDirector.ClassSelected:Connect(CharacterAppearanceService.refresh)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CharacterAppearanceService
