--!strict
-- Validates and remembers native starting-pet intents; StatService grants the resolved item, and place services carry the pick.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Run = require(script.Parent.RunDirector)
local Data = require(script.Parent.PlayerDataService)
local Service = {}
local selections: { [Player]: { [string]: string } } = {}
local function allowed(classId: string, petId: string): boolean
	local class, item = Config.Classes[classId], Config.Items.byId[petId]
	return class ~= nil
		and class.startPets ~= nil
		and table.find(class.startPets, petId) ~= nil
		and item ~= nil
		and item.pet ~= nil
end
function Service.getStartPet(player: Player, classId: string): string?
	local choices = selections[player]
	local choice = choices and choices[classId]
	return if choice and allowed(classId, choice) and Data.isUnlocked(player, "items", choice) then choice else nil
end
function Service.resolve(player: Player, classId: string): string?
	local class = Config.Classes[classId]
	local choice = Service.getStartPet(player, classId)
	if choice then
		return choice
	end
	for _, id in (class and class.startPets) or {} do
		if allowed(classId, id) and Data.isUnlocked(player, "items", id) then
			return id
		end
	end
	return nil
end
function Service.selectStartPet(player: Player, classId: string, petId: string): boolean
	if Run.isOngoing() and Run.getParticipantState(player) ~= nil then
		return false
	end
	local class = Config.Classes[classId]
	if
		Run.getSelectedClassId(player) ~= classId
		or not class
		or not class.available
		or not allowed(classId, petId)
		or not Data.isUnlocked(player, "items", petId)
	then
		return false
	end
	local choices = selections[player] or {}
	selections[player] = choices
	choices[classId] = petId
	Net.fireClient("StartPetChoice", player, classId, petId, true)
	return true
end
function Service.init()
	Net.onServer("SelectStartPet", Service.selectStartPet)
	Run.SyncRequested:Connect(function(player)
		for classId, petId in selections[player] or {} do
			if allowed(classId, petId) then
				Net.fireClient("StartPetChoice", player, classId, petId, false)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		selections[player] = nil
	end)
end
return Service
