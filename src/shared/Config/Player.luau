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
	hitInvulnerability = 0.4, -- seconds of protection after taking a hit (B5: Brotato range 0.2-0.4, before 0.5)
	-- crits of weapons that set no critChance / critDamage of their own (Brotato: most weapons x2 at 3 %; since B5,
	-- before 5 % for every weapon), also of item explosions
	critChance = 0.03, -- per hit, before the Crit Chance stat
	critMultiplier = 2,
	minWeaponCooldown = 1 / 12, -- seconds; at most 12 attacks per second like Brotato (since B5, before 0.2 s)
	maxWeapons = 6, -- Brotato's six weapon slots (since B2, before 4)
	maxWeaponTier = 4, -- Brotato's weapon tiers I-IV (since B3, before levels 1-5); two equal weapons merge into the next
})
