--!strict
-- Keeps the latest weapon loadout of every player (Loadout remote from WeaponService). Read by WeaponRenderer
-- (what to draw around whom) and HUDController (the weapon list).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Net"):WaitForChild("Types"))

local LoadoutController = {}

-- (userId: number, loadout: Types.Loadout)
LoadoutController.Changed = Signal.new()

local loadouts: { [number]: Types.Loadout } = {}

function LoadoutController.init()
	Net.onClient("Loadout", function(loadout: Types.Loadout)
		loadouts[loadout.userId] = loadout
		LoadoutController.Changed:Fire(loadout.userId, loadout)
	end)
	Players.PlayerRemoving:Connect(function(player)
		loadouts[player.UserId] = nil
	end)
end

function LoadoutController.get(userId: number): Types.Loadout?
	return loadouts[userId]
end

function LoadoutController.getLocal(): Types.Loadout?
	return loadouts[Players.LocalPlayer.UserId]
end

-- Every known loadout by userId (live; do not change it).
function LoadoutController.getAll(): { [number]: Types.Loadout }
	return loadouts
end

return LoadoutController
