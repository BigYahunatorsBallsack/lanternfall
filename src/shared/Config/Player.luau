--!strict
-- Base player stats at run start (DESIGN.md section 4). Read by CombatService and the player controllers.

return table.freeze({
	maxHp = 100,
	moveSpeed = 16, -- studs/s
	dash = table.freeze({
		distance = 12, -- studs
		cooldown = 6, -- seconds
		invulnerability = 0.3, -- seconds
	}),
	pickupRadius = 8, -- studs (XP orbs, healing, embers)
	armor = 0, -- flat reduction per hit
	minDamagePerHit = 1,
	regenPerSecond = 0,
	hitInvulnerability = 0.5, -- seconds of protection after taking a hit
	critChance = 0.05,
	critMultiplier = 2,
	maxWeapons = 4,
	maxPassives = 4,
	maxItemLevel = 5,
})
