--!strict
-- Reports only walking intent for native character conditions; the server owns every resulting bonus and attack.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local C = require(Shared.Config.CharacterMechanics).movementIntent
local Controller = {}
local previous: boolean? = nil
local previousDirection = Vector3.zero
local lastSent = -math.huge

function Controller.init()
	RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local direction = humanoid and humanoid.MoveDirection
		local moving = direction ~= nil and (direction.X ~= 0 or direction.Z ~= 0)
		local horizontal = if direction then Vector3.new(direction.X, 0, direction.Z) else Vector3.zero
		local now = workspace:GetServerTimeNow()
		if
			now - lastSent >= C.minSendSeconds
			and (moving ~= previous or horizontal ~= previousDirection or now - lastSent >= C.heartbeatSeconds)
		then
			lastSent, previous = now, moving
			previousDirection = horizontal
			Net.fireServer("SetMovementIntent", moving, horizontal)
		end
	end)
end

return Controller
