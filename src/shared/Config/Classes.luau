--!strict
-- Playable classes (DESIGN.md section 5). Read by RunDirector (start weapon, bonus) and the class UI.
-- `stats` are added to the player's stats at run start (Config.Stats ids and units, e.g. maxHp = 20 = +20 HP).
-- B4 turns the classes into characters with Brotato-style trade-offs.

export type Class = {
	id: string,
	displayName: string,
	startWeapon: string,
	stats: { [string]: number },
	free: boolean,
	available: boolean, -- false = planned for Live-Ops, not selectable yet
	emberPrice: number?,
}

local Classes: { [string]: Class } = {
	BladeWarden = {
		id = "BladeWarden",
		displayName = "Blade Warden",
		startWeapon = "OrbitBlades",
		stats = { maxHp = 20 }, -- before B2: +20 % max HP
		free = true,
		available = true,
	},
	SparkMage = {
		id = "SparkMage",
		displayName = "Spark Mage",
		startWeapon = "SparkBolt",
		stats = { attackSpeed = 10 }, -- before B2: -10 % cooldown
		free = true,
		available = true,
	},
	LanternKeeper = {
		id = "LanternKeeper",
		displayName = "Lantern Keeper",
		startWeapon = "LanternPulse",
		stats = {}, -- planned: +25 % revive speed (WP11)
		free = false,
		available = false,
		emberPrice = 2500,
	},
	Trapper = {
		id = "Trapper",
		displayName = "Trapper",
		startWeapon = "ThornTrail",
		stats = { range = 15 }, -- planned before B2: +15 % area
		free = false,
		available = false,
		emberPrice = 2500,
	},
}

return table.freeze(Classes)
