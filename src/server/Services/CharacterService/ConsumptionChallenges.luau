--!strict
-- Native Hungry challenge counts each consumed fruit/crate during one run; CharacterService initializes it for all players.
local Players = game:GetService("Players")
local Run = require(script.Parent.Parent.RunDirector)
local Loot = require(script.Parent.Parent.LootService)
local Data = require(script.Parent.Parent.PlayerDataService)
local Challenges = {}
local counts: { [Player]: number } = {}
function Challenges.init()
	Run.RunStarted:Connect(function()
		table.clear(counts)
	end)
	Loot.ConsumableCollected:Connect(function(player)
		if not Run.isOngoing() or Run.getParticipantState(player) ~= "Alive" then
			return
		end
		counts[player] = (counts[player] or 0) + 1
		Data.observeNativeConsumption(player, counts[player])
	end)
	Run.addCheckpoint("NativeConsumption", function()
		return table.clone(counts)
	end, function(saved: { [Player]: number })
		counts = table.clone(saved)
	end)
	Players.PlayerRemoving:Connect(function(player)
		counts[player] = nil
	end)
end
return Challenges
