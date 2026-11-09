--!strict
-- Base player values at run start (DESIGN.md section 4). Read by CombatService, WeaponService and HUD.
-- The stats that grow during a run (Config.Stats) start from maxHp, moveSpeed, pickupRadius and critChance here.

local Stats = require(script.Parent.Stats)

return table.freeze({
	maxHp = 10,
	-- Brotato: 450 units/s. Use the same world scale as weapon ranges (0.1 studs per unit), not Roblox's old 16.
	moveSpeed = 450 * Stats.range.studsPerPoint,
	-- studs (XP orbs, healing, embers); 8 until the playtest after Paket 24, now about Brotato's share of the arena
	-- width (150 of about 2000 px) for the 160-stud arena
	pickupRadius = 12,
	minDamagePerHit = 1,
	-- seconds of protection after taking a hit, like Brotato: from min (tiny hit) to max (a hit worth all max HP),
	-- linear in the share of max HP lost. The 0.2-0.4 s range is Brotato's; the linear curve is an assumption
	-- (the wiki gives no formula). Since 09.11.2026, before always 0.4 s (B5) and 0.5 s.
	hitInvulnerabilityMin = 0.2,
	hitInvulnerabilityMax = 0.4,
	-- crits of weapons that set no critChance / critDamage of their own (Brotato: most weapons x2 at 3 %; since B5,
	-- before 5 % for every weapon), also of item explosions
	critChance = 0.03, -- per hit, before the Crit Chance stat
	critMultiplier = 2,
	minWeaponCooldown = 1 / 12, -- seconds; at most 12 attacks per second like Brotato (since B5, before 0.2 s)
	maxWeapons = 6, -- Brotato's six weapon slots (since B2, before 4)
	maxWeaponTier = 4, -- Brotato's weapon tiers I-IV (since B3, before levels 1-5); two equal weapons merge into the next
})
