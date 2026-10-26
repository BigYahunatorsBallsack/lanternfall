--!strict
-- Playable classes (DESIGN.md section 5). Read by RunDirector (start weapon, bonus) and the class UI.
-- bonus.stat uses the same stat names as Passives; value is a fraction (0.2 = +20 %).

export type Class = {
	id: string,
	displayName: string,
	startWeapon: string,
	bonus: { stat: string, value: number },
	free: boolean,
	available: boolean, -- false = planned for Live-Ops, not selectable yet
	emberPrice: number?,
}

local Classes: { [string]: Class } = {
	BladeWarden = {
		id = "BladeWarden",
		displayName = "Blade Warden",
		startWeapon = "OrbitBlades",
		bonus = { stat = "maxHp", value = 0.2 },
		free = true,
		available = true,
	},
	SparkMage = {
		id = "SparkMage",
		displayName = "Spark Mage",
		startWeapon = "SparkBolt",
		bonus = { stat = "cooldown", value = -0.1 },
		free = true,
		available = true,
	},
	LanternKeeper = {
		id = "LanternKeeper",
		displayName = "Lantern Keeper",
		startWeapon = "LanternPulse",
		bonus = { stat = "reviveSpeed", value = 0.25 },
		free = false,
		available = false,
		emberPrice = 2500,
	},
	Trapper = {
		id = "Trapper",
		displayName = "Trapper",
		startWeapon = "ThornTrail",
		bonus = { stat = "area", value = 0.15 },
		free = false,
		available = false,
		emberPrice = 2500,
	},
}

return table.freeze(Classes)
