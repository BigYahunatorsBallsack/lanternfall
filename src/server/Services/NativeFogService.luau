--!strict
-- Publishes authoritative Nightmare fog activation and wave-start visibility; the client shares light from existing replicated actors.
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Net.Types)
local Net = require(Shared.Net)
local Run = require(script.Parent.RunDirector)
local Danger = require(script.Parent.DangerService)
local Stats = require(script.Parent.StatService)
local Enemy = require(script.Parent.EnemySim)
local Service = {}
local state: Types.NativeFogState = { wave = 0, at = 0, players = {} }
local checkedWave = 0
local function send(player: Player?)
	if player then
		Net.fireClient("NativeFog", player, state)
	else
		for _, participant in Run.getParticipants() do
			Net.fireClient("NativeFog", participant, state)
		end
	end
end
local function clear()
	checkedWave = 0
	state = { wave = 0, at = workspace:GetServerTimeNow(), players = {} }
	send(nil)
end
local function step()
	if Run.getPhase() ~= "Running" then
		return
	end
	local wave = Run.getWave()
	local dirty = false
	if checkedWave ~= wave then
		checkedWave = wave
		state = { wave = 0, at = workspace:GetServerTimeNow(), players = {} }
		if Danger.getNightmareEvent(wave) == "fog_of_war" then
			state.wave = wave
			for _, player in Run.getParticipants() do
				table.insert(state.players, {
					userId = player.UserId,
					visibility = Stats.getStat(player, "fogVisibility"),
					alive = Run.getParticipantState(player) == "Alive",
				})
			end
		end
		dirty = true
	end
	if state.wave ~= 0 then
		local living = {}
		for _, player in Run.getParticipants() do
			living[player.UserId] = Run.getParticipantState(player) == "Alive"
		end
		for _, info in state.players do
			local alive = living[info.userId] == true
			if alive ~= info.alive then
				info.alive = alive
				dirty = true
			end
		end
	end
	if dirty then
		send(nil)
	end
end
function Service.init()
	Run.RunStarted:Connect(clear)
	Run.RunEnded:Connect(clear)
	Run.PhaseChanged:Connect(function(phase)
		if phase ~= "Running" then
			clear()
		end
	end)
	Run.SyncRequested:Connect(function(player)
		step()
		send(player)
	end)
	Enemy.Stepped:Connect(step)
end
function Service.isActive(): boolean
	return state.wave ~= 0
end
return Service
