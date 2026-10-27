--!strict
-- Base player values at run start (DESIGN.md section 4). Read by CombatService, WeaponService, InputController and HUD.
-- The stats that grow during a run (Config.Stats) start from maxHp, moveSpeed, pickupRadius and critChance here.

return table.freeze({
	maxHp = 100,
	moveSpeed = 16, -- studs/s
	dash = table.freeze({
		distance = 12, -- studs
		cooldown = 6, -- seconds
		invulnerability = 0.3, -- seconds
		duration = 0.15, -- seconds the dash movement takes (distance / duration = dash speed)
		cooldownTolerance = 0.25, -- seconds the server forgives, so ping does not eat a dash
	}),
	pickupRadius = 8, -- studs (XP orbs, healing, embers)
	minDamagePerHit = 1,
	hitInvulnerability = 0.5, -- seconds of protection after taking a hit
	critChance = 0.05, -- per weapon hit, before the Crit Chance stat
	critMultiplier = 2,
	minWeaponCooldown = 0.2, -- seconds; cooldown bonuses never make a weapon faster than this
	maxWeapons = 6, -- Brotato's six weapon slots (since B2, before 4)
	maxItemLevel = 5, -- weapon levels (B3 brings Brotato's tiers)
})
