--!strict
-- Keeps Roblox's walking controls and disables jumping on keyboard, gamepad and character spawn.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local InputController = {}

local function suppressJump(): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
end

function InputController.init()
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false) -- HP is in our HUD
end

function InputController.start()
	ContextActionService:BindActionAtPriority(
		"LanternfallNoJump",
		suppressJump,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA
	)
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

return InputController
