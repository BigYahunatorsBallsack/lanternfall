--!strict
-- Admin rights and debug command values (DESIGN.md section 16). Read by AdminService.
-- Admins: everyone in Studio (if allowInStudio), the owner of a user-owned experience, and userIds.

return table.freeze({
	userIds = table.freeze({}) :: { number },
	allowInStudio = true,
	addShards = 100, -- "AddShards"
	addEmbers = 1000, -- "AddEmbers" (since Paket 17): saved Embers for the Ember shop
	-- "SkipToBoss" leaves this many seconds until the end of the run: since WP10 the boss wave's 90 s, so it lands at
	-- the end of wave 19 (its shop, then the boss wave)
	skipToBossLeadSeconds = 90,
	spawnWaveCount = 40, -- "SpawnWave": enemies spawned around the admin (the alive cap still applies)
	hitNearbyRadius = 20, -- "HitNearby": studs around the admin
	hitNearbyDamage = 5, -- "HitNearby": damage per enemy, so a Shadeling at minute 0 takes two hits
	hurtSelfDamage = 25, -- "HurtSelf": damage of the test hit (armor and hit protection apply)
	statsInterval = 1, -- seconds between stats updates for the admin stats panel
	hurtBossShare = 0.25, -- "HurtBoss" (since WP10): share of its max HP every boss loses
	-- "AddNewItem" (since B8): the items of the latest item package, one after another
	newItems = table.freeze({
		"GrubTincture",
		"BeckoningBell",
		"TaintedElixir",
		"HookedTongue",
		"CrackedSkull",
		"WispJar",
		"OrderSash",
		"RollingEye",
		"InkPolyp",
		"Knucklebones",
		"WitchKettle",
		"SaltCoral",
		"AstralPhilter",
		"AmberResin",
		"RabbleBanner",
		"HearthSprite",
		"BloodChalice",
		"CrimsonHand",
		"VelvetDivan",
		"BrassCarapace",
		"ThunderShells",
		"SecondStomach",
		"TitanGirdle",
		"PyreAshes",
	}) :: { string },
	-- "SpawnNewEnemy" (since B9): the enemies of the latest enemy package, one after another
	newEnemies = table.freeze({
		"Stalker",
		"Skulker",
		"Thornback",
		"Herald",
		"Mender",
		"BroodEgg",
		"Reaper",
		"Gobbler",
	}) :: { string },
})
