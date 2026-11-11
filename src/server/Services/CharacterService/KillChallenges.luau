--!strict
-- Native cumulative credited-kill challenges; CharacterService connects once to authoritative enemy deaths.
local Run = require(script.Parent.Parent.RunDirector)
local Enemy = require(script.Parent.Parent.EnemySim)
local Data = require(script.Parent.Parent.PlayerDataService)
local Challenges = {}
function Challenges.init()
	Enemy.EnemyKilled:Connect(function(info)
		if Run.isActive() and info.killer then
			if info.boss and info.aliveSeconds then
				Data.observeNativeFastBossKill(info.killer, info.aliveSeconds)
			end
			if info.enemyId == "Tree" then
				Data.observeNativeTreeKill(info.killer)
			else
				Data.observeNativeEnemyKill(info.killer)
			end
		end
	end)
end
return Challenges
