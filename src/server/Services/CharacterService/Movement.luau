--!strict
-- Validated movement intent for native character conditions; CharacterService initializes it, weapons query it.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local C = require(Shared.Config.CharacterMechanics).movementIntent
local Run = require(script.Parent.Parent.RunDirector)
local Map = require(script.Parent.Parent.MapService)
local Movement = {}
Movement.Changed = Signal.new()
local intents: { [Player]: { moving: boolean, at: number } } = {}
local initialized = false

function Movement.init()
	if initialized then
		return
	end
	initialized = true
	Net.onServer("SetMovementIntent", function(player: Player, moving: boolean)
		if not Run.isActive() or Run.getParticipantState(player) ~= "Alive" then
			return
		end
		intents[player] = { moving = moving, at = workspace:GetServerTimeNow() }
		Movement.Changed:Fire(player)
	end)
	Run.RunStarted:Connect(function()
		table.clear(intents)
	end)
	Run.WaveRetried:Connect(function()
		table.clear(intents)
	end)
	Run.PhaseChanged:Connect(function(phase)
		if phase ~= "Running" then
			table.clear(intents)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		intents[player] = nil
	end)
end

function Movement.isMoving(player: Player): boolean
	local intent = intents[player]
	if intent and intent.moving and workspace:GetServerTimeNow() - intent.at <= C.lifetimeSeconds then
		return true
	end
	-- A forged "still" intent cannot grant stationary bonuses while the server observes movement.
	local velocity = Map.getRootVelocity(player)
	return velocity.X ~= 0 or velocity.Z ~= 0
end

return Movement
