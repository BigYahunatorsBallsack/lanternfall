--!strict
-- Admin rights and debug command values (DESIGN.md section 16). Read by AdminService.
-- Admins: everyone in Studio (if allowInStudio), the owner of a user-owned experience, and userIds.

return table.freeze({
	userIds = table.freeze({}) :: { number },
	allowInStudio = true,
	skipMinuteSeconds = 60, -- "SkipMinute"
	skipToBossLeadSeconds = 10, -- "SkipToBoss" leaves this many seconds until the boss
	spawnWaveCount = 40, -- "SpawnWave": enemies spawned around the admin (the alive cap still applies)
	hitNearbyRadius = 20, -- "HitNearby": studs around the admin
	hitNearbyDamage = 5, -- "HitNearby": damage per enemy, so a Shadeling at minute 0 takes two hits
	statsInterval = 1, -- seconds between stats updates for the admin stats panel
})
