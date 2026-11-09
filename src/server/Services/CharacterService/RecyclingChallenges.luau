--!strict
-- Native run-wide recycling challenge; CharacterService initializes, ShopService reports successful sales only.
local Players = game:GetService("Players")
local Run = require(script.Parent.Parent.RunDirector)
local Shop = require(script.Parent.Parent.ShopService)
local Data = require(script.Parent.Parent.PlayerDataService)
local Recycling = {}
local totals: { [Player]: number } = {}
function Recycling.init()
	Run.RunStarted:Connect(function()
		table.clear(totals)
	end)
	Run.addCheckpoint("NativeRecycling", function()
		return table.clone(totals)
	end, function(saved: { [Player]: number })
		totals = table.clone(saved)
	end)
	Shop.Sold:Connect(function(player: Player)
		totals[player] = (totals[player] or 0) + 1
		Data.observeNativeRecycling(player, totals[player])
	end)
	Players.PlayerRemoving:Connect(function(player)
		totals[player] = nil
	end)
end
return Recycling
