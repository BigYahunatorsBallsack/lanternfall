--!strict
-- Ids of the admin debug commands. Used by Net/Remotes (validation), AdminService (handlers) and
-- DebugController (buttons). Only admins may run them; the server checks that, not the client.

return table.freeze({
	"SkipWave", -- run timer to the end of the current wave (opens the shop)
	"HoldWaves", -- stop or restart the wave timer (waves never end while it stands still)
	"AddShards", -- +Config.Admin.addShards Shards
	"SkipToBoss", -- run timer to a few seconds before the boss
	"DownSelf", -- knock yourself down
	"ReviveSelf", -- stand up again
	"HurtSelf", -- take a hit as if an enemy touched you
	"HealSelf", -- back to full HP
	"WinRun", -- end the run as a victory
	"SpawnWave", -- spawn a group of enemies around yourself
	"SpawnElite", -- spawn a Gloom Elite (drops a chest) near yourself
	"HitNearby", -- damage every enemy close to you
	"KillEnemies", -- kill every enemy
	"ToggleSpawning", -- pause or resume enemy spawning
	"AddWeapon", -- add the next weapon you do not have yet
	"NextWeapon", -- swap your weapons for only the next one, to try each weapon on its own
	"LevelUpWeapons", -- every weapon +1 level
	"EvolveWeapons", -- evolve every weapon that has an evolution: max level and the needed passive first
	"ToggleWeapons", -- switch every player's weapons off or on
	"GainLevel", -- the team reaches the next level right away (level-up cards)
})
