--!strict
-- Weapon evolutions (DESIGN.md section 6). Only offered from elite or boss chests (WP9). Read by WeaponService
-- (stats via WeaponStats), UpgradeService (who may evolve what) and the client (HUD name, weapon look).

export type Evolution = {
	id: string,
	displayName: string,
	weapon: string, -- must be at the max tier (IV, since B3; before level 5)
	item: string, -- key in Config.Items, owned at least once
	behavior: string,
	stats: { [string]: number }, -- overrides on top of the max-tier weapon
}

local Evolutions: { [string]: Evolution } = {
	BladeStorm = {
		id = "BladeStorm",
		displayName = "Blade Storm",
		weapon = "OrbitBlades",
		item = "Armor",
		behavior = "OrbitBlades",
		stats = {
			count = 8,
			radius = 10,
			damageMultiplier = 2,
		},
	},
	Starfire = {
		id = "Starfire",
		displayName = "Starfire",
		weapon = "SparkBolt",
		item = "Focus",
		behavior = "SparkBolt",
		stats = {
			explosionRadius = 6, -- studs around every enemy a bolt hits
			explosionDamage = 1, -- share of the bolt's damage the other enemies in the blast take (assumption)
		},
	},
}

return table.freeze(Evolutions)
