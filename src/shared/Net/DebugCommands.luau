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
	"TierUpWeapons", -- every weapon +1 tier
	"EvolveWeapons", -- evolve every weapon that has an evolution: max tier and the needed item first
	"ToggleWeapons", -- switch every player's weapons off or on
	"GainLevel", -- the team reaches the next level right away (level-up cards)
	"AddEffectItem", -- the next item with an effect or a secondary stat (since B4), one after another
	"AddCombatItem", -- the next item with a combat stat or a burn or explode effect (since B5), one after another
	"SpawnLooter", -- a Looter near yourself (since B6; it runs away and drops a crate)
	"SpawnTree", -- a Tree next to yourself (since B6; drops a fruit or crate)
	"DropCrate", -- a crate at your feet (since B6; it opens at the end of the wave)
	"AddNewItem", -- the next item of the latest item package (since B8, Config.Admin.newItems), one after another
	"SpawnNewEnemy", -- the next enemy of the latest enemy package near yourself (since B9, Config.Admin.newEnemies)
})
