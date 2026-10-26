--!strict
-- Ids of the admin debug commands. Used by Net/Remotes (validation), AdminService (handlers) and
-- DebugController (buttons). Only admins may run them; the server checks that, not the client.

return table.freeze({
	"SkipMinute", -- run timer +1 minute
	"SkipToBoss", -- run timer to a few seconds before the boss
	"DownSelf", -- knock yourself down
	"ReviveSelf", -- stand up again
	"HurtSelf", -- take a hit as if an enemy touched you
	"HealSelf", -- back to full HP
	"WinRun", -- end the run as a victory
	"SpawnWave", -- spawn a group of enemies around yourself
	"HitNearby", -- damage every enemy close to you
	"KillEnemies", -- kill every enemy
	"ToggleSpawning", -- pause or resume enemy spawning
	"AddWeapon", -- add the next weapon you do not have yet
	"NextWeapon", -- swap your weapons for only the next one, to try each weapon on its own
	"LevelUpWeapons", -- every weapon +1 level
	"ToggleWeapons", -- switch every player's weapons off or on
})
