--!strict
-- Applies the server-approved character skin on selection and respawn; loaded by the server service loader.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local Config = require(ReplicatedStorage.Shared.Config)
local Art = require(ReplicatedStorage.Shared.Config.CharacterArt)
local RunDirector = require(script.Parent.RunDirector)
local Skin = require(script.Skin)

local CharacterAppearanceService = {}
local templates: { [string]: Model } = {}
local loading: { [string]: boolean } = {}
local revisions: { [Player]: number } = {}

local function selected(player: Player): string
	return RunDirector.getParticipantClassId(player)
		or RunDirector.getSelectedClassId(player)
		or Config.Run.flow.defaultClassId
end

local function loadTemplate(classId: string): Model?
	if templates[classId] then
		return templates[classId]
	end
	if loading[classId] then
		repeat
			task.wait()
		until not loading[classId]
		return templates[classId]
	end
	local assetId = Art.models[classId]
	if not assetId then
		return nil
	end
	loading[classId] = true
	local pending: Model? = nil
	local ok, result = pcall(function(): Model
		local container = InsertService:LoadAsset(assetId)
		pending = container
		local model = Skin.prepare(container, classId)
		pending = model
		return model
	end)
	loading[classId] = nil
	if ok then
		templates[classId] = result
		return result
	end
	if pending then
		pending:Destroy()
	end
	warn(`[Lanternfall] Character {classId} failed to load: {result}`)
	return nil
end

function CharacterAppearanceService.refresh(player: Player)
	local revision = (revisions[player] or 0) + 1
	revisions[player] = revision
	local character = player.Character
	if not character then
		return
	end
	local classId = selected(player)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", Art.rootWaitSeconds)
		local humanoid = character:WaitForChild("Humanoid", Art.rootWaitSeconds)
		if not (root and root:IsA("BasePart") and humanoid and humanoid:IsA("Humanoid")) then
			return
		end
		for attempt = 1, Art.loadAttempts do
			if revisions[player] ~= revision or player.Character ~= character or not player.Parent then
				return
			end
			local template = loadTemplate(classId)
			if template then
				if revisions[player] ~= revision or player.Character ~= character or not player.Parent then
					return
				end
				local ok, message = pcall(Skin.attach, template, character, root, humanoid, classId)
				if ok then
					character:SetAttribute("LanternfallClassId", classId)
					return
				end
				warn(`[Lanternfall] Character {classId} failed to attach: {message}`)
			end
			if attempt < Art.loadAttempts then
				task.wait(Art.retrySeconds)
			end
		end
	end)
end

local function onCharacter(player: Player, _character: Model)
	CharacterAppearanceService.refresh(player)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end

function CharacterAppearanceService.init()
	RunDirector.ClassSelected:Connect(CharacterAppearanceService.refresh)
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		revisions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CharacterAppearanceService
