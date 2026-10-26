--!strict
-- Base player stats at run start (DESIGN.md section 4). Read by CombatService, InputController and HUD.

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
