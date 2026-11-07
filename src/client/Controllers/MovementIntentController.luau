--!strict
-- Reports only walking intent for native character conditions; the server owns every resulting bonus and attack.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local C = require(Shared.Config.CharacterMechanics).movementIntent
local Controller = {}
local previous: boolean? = nil
local lastSent = -math.huge

function Controller.init()
	RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local direction = humanoid and humanoid.MoveDirection
		local moving = direction ~= nil and (direction.X ~= 0 or direction.Z ~= 0)
		local now = workspace:GetServerTimeNow()
		if now - lastSent >= C.minSendSeconds and (moving ~= previous or now - lastSent >= C.heartbeatSeconds) then
			lastSent, previous = now, moving
			Net.fireServer("SetMovementIntent", moving)
		end
	end)
end

return Controller
