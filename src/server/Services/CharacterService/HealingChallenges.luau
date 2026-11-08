--!strict
-- Native per-wave accepted healing for Doctor's challenge; initialized by CharacterService for every participant.
local Players = game:GetService("Players")
local Run = require(script.Parent.Parent.RunDirector)
local Combat = require(script.Parent.Parent.CombatService)
local Data = require(script.Parent.Parent.PlayerDataService)
local Healing = {}
local totals: { [Player]: number } = {}
function Healing.init()
	Run.RunStarted:Connect(function()
		table.clear(totals)
	end)
	Run.WaveStarting:Connect(function()
		table.clear(totals)
	end)
	Run.addCheckpoint("NativeHealing", function()
		return table.clone(totals)
	end, function(saved: { [Player]: number })
		totals = table.clone(saved)
	end)
	Combat.HealingApplied:Connect(function(player: Player, amount: number)
		local phase = Run.getPhase()
		if amount <= 0 or (phase ~= "Running" and phase ~= "Shop") or Run.getParticipantState(player) ~= "Alive" then
			return
		end
		totals[player] = (totals[player] or 0) + amount
		Data.observeNativeHealing(player, totals[player])
	end)
	Players.PlayerRemoving:Connect(function(player)
		totals[player] = nil
	end)
end
return Healing
