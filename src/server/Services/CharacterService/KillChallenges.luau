--!strict
-- Native cumulative credited-kill challenges; CharacterService connects once to authoritative enemy deaths.
local Run = require(script.Parent.Parent.RunDirector)
local Enemy = require(script.Parent.Parent.EnemySim)
local Data = require(script.Parent.Parent.PlayerDataService)
local Challenges = {}
function Challenges.init()
	Enemy.EnemyKilled:Connect(function(info)
		if Run.isActive() and info.killer and info.enemyId ~= "Tree" then
			Data.observeNativeEnemyKill(info.killer)
		end
	end)
end
return Challenges
