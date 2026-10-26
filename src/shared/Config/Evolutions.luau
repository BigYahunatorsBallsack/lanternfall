--!strict
-- Weapon evolutions (DESIGN.md section 6). Only offered from elite or boss chests. Read by LootService.

export type Evolution = {
	id: string,
	displayName: string,
	weapon: string, -- must be at max level
	passive: string, -- any level
	behavior: string,
	stats: { [string]: number }, -- overrides on top of the max-level weapon
}

local Evolutions: { [string]: Evolution } = {
	BladeStorm = {
		id = "BladeStorm",
		displayName = "Blade Storm",
		weapon = "OrbitBlades",
		passive = "Armor",
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
		passive = "Focus",
		behavior = "SparkBolt",
		stats = {
			explosionRadius = 6,
		},
	},
}

return table.freeze(Evolutions)
