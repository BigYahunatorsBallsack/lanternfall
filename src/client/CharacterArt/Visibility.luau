--!strict
-- Preloads replicated skins on each device and swaps local avatar visibility only after success; called by CharacterAnimationController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Art = require(ReplicatedStorage.Shared.Config.CharacterArt)

type Entry = {
	character: Model,
	skin: Model,
	root: BasePart,
	ready: boolean,
	attempts: number,
	nextTry: number,
	hidden: { [Instance]: number },
	connection: RBXScriptConnection?,
	pending: thread?,
	timeout: thread?,
}
local entries: { [Player]: Entry } = {}
local Visibility = {}
local nativeNames: { [string]: boolean } = {
	Head = true,
	UpperTorso = true,
	LowerTorso = true,
	Torso = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}

local function showSkin(entry: Entry, visible: boolean)
	for _, part in entry.skin:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if visible then 0 else 1
		end
	end
end

local function hideNative(entry: Entry, instance: Instance)
	if instance:IsDescendantOf(entry.skin) then
		return
	end
	if instance:IsA("BasePart") then
		if
			(instance.Parent == entry.character and nativeNames[instance.Name])
			or instance:FindFirstAncestorWhichIsA("Accessory")
		then
			if entry.hidden[instance] == nil then
				entry.hidden[instance] = instance.LocalTransparencyModifier
			end
			instance.LocalTransparencyModifier = 1
		end
	elseif instance:IsA("Decal") and instance.Parent and instance.Parent.Name == "Head" then
		if entry.hidden[instance] == nil then
			entry.hidden[instance] = instance.Transparency
		end
		instance.Transparency = 1
	end
end

function Visibility.forget(player: Player)
	local entry = entries[player]
	if not entry then
		return
	end
	entries[player] = nil
	if entry.connection then
		entry.connection:Disconnect()
	end
	for _, thread in { entry.pending, entry.timeout } do
		if coroutine.status(thread) ~= "dead" then
			task.cancel(thread)
		end
	end
	for instance, value in entry.hidden do
		if instance.Parent then
			if instance:IsA("BasePart") then
				instance.LocalTransparencyModifier = value
			elseif instance:IsA("Decal") then
				instance.Transparency = value
			end
		end
	end
end

local function load(player: Player, entry: Entry)
	entry.attempts += 1
	entry.pending = task.defer(function()
		local failed = false
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ entry.skin }, function(_id, status)
				if status ~= Enum.AssetFetchStatus.Success then
					failed = true
				end
			end)
		end)
		if entries[player] ~= entry then
			return
		end
		entry.pending = nil
		if entry.timeout then
			task.cancel(entry.timeout)
			entry.timeout = nil
		end
		entry.ready = ok and not failed
		if entry.ready then
			for _, instance in entry.character:GetDescendants() do
				hideNative(entry, instance)
			end
			showSkin(entry, true)
		else
			entry.nextTry = os.clock() + Art.retrySeconds
		end
	end)
	entry.timeout = task.delay(Art.preloadTimeoutSeconds, function()
		if entries[player] ~= entry then
			return
		end
		if entry.pending then
			task.cancel(entry.pending)
			entry.pending = nil
		end
		entry.timeout = nil
		entry.nextTry = os.clock() + Art.retrySeconds
	end)
end

function Visibility.update()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local skin = character and character:FindFirstChild(Art.folderName)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local entry = entries[player]
		if entry and (entry.character ~= character or entry.skin ~= skin) then
			Visibility.forget(player)
			entry = nil
		end
		if not (character and skin and skin:IsA("Model") and root and root:IsA("BasePart")) then
			continue
		end
		if not entry then
			entry = {
				character = character,
				skin = skin,
				root = root,
				ready = false,
				attempts = 0,
				nextTry = 0,
				hidden = {},
			}
			entries[player] = entry
			local current = entry
			current.connection = character.DescendantAdded:Connect(function(instance)
				if current.ready then
					hideNative(current, instance)
				end
			end)
			showSkin(current, false)
		end
		if
			not entry.ready
			and not entry.pending
			and entry.attempts < Art.loadAttempts
			and os.clock() >= entry.nextTry
		then
			load(player, entry)
		end
	end
end

function Visibility.get(player: Player): Entry?
	return entries[player]
end

return Visibility
