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
local intents: { [Player]: { moving: boolean, at: number, direction: Vector3? } } = {}
local speedOf: ((Player) -> number)? = nil
local initialized = false

function Movement.init(speedProvider: ((Player) -> number)?)
	if speedProvider then
		speedOf = speedProvider
	end
	if initialized then
		return
	end
	initialized = true
	Net.onServer("SetMovementIntent", function(player: Player, moving: boolean, direction: Vector3?)
		if not Run.isActive() or Run.getParticipantState(player) ~= "Alive" then
			return
		end
		if direction then
			if direction.Y ~= 0 or moving ~= (direction.Magnitude > 0) then
				return
			end
			direction = if moving then direction.Unit else Vector3.zero
		end
		local previous = intents[player]
		intents[player] = { moving = moving, at = workspace:GetServerTimeNow(), direction = direction }
		if not direction or not previous or previous.moving ~= moving then
			Movement.Changed:Fire(player)
		end
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

-- Native Unit.get_move_input is normalized input times server-computed stat speed, including against a wall.
function Movement.getInput(player: Player): Vector3
	if not Run.isActive() or Run.getParticipantState(player) ~= "Alive" or not speedOf then
		return Vector3.zero
	end
	local intent = intents[player]
	local speed = math.max(0, speedOf(player))
	if intent and intent.direction and workspace:GetServerTimeNow() - intent.at <= C.lifetimeSeconds then
		return intent.direction * speed
	end
	-- Older boolean-only clients remain supported; new clients always send direction with the existing intent.
	local velocity = Map.getRootVelocity(player)
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	return if horizontal.Magnitude > 0 then horizontal.Unit * speed else Vector3.zero
end

return Movement
