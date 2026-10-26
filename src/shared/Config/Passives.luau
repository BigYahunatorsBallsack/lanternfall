--!strict
-- Passive item records (DESIGN.md section 6). Read by UpgradeService and stat calculation.
-- mode "percent": perLevel is a fraction added per level (0.15 = +15 %).
-- mode "flat": perLevel is added as an absolute value.

export type Passive = {
	id: string,
	displayName: string,
	description: string,
	stat: "maxHp" | "moveSpeed" | "cooldown" | "pickupRadius" | "damage" | "armor",
	mode: "percent" | "flat",
	perLevel: number,
}

local Passives: { [string]: Passive } = {
	Vitality = {
		id = "Vitality",
		displayName = "Vitality",
		description = "+15% max HP",
		stat = "maxHp",
		mode = "percent",
		perLevel = 0.15,
	},
	Haste = {
		id = "Haste",
		displayName = "Haste",
		description = "+8% move speed",
		stat = "moveSpeed",
		mode = "percent",
		perLevel = 0.08,
	},
	Focus = {
		id = "Focus",
		displayName = "Focus",
		description = "-8% weapon cooldown",
		stat = "cooldown",
		mode = "percent",
		perLevel = -0.08,
	},
	Magnet = {
		id = "Magnet",
		displayName = "Magnet",
		description = "+30% pickup radius",
		stat = "pickupRadius",
		mode = "percent",
		perLevel = 0.3,
	},
	Might = {
		id = "Might",
		displayName = "Might",
		description = "+10% damage",
		stat = "damage",
		mode = "percent",
		perLevel = 0.1,
	},
	Armor = {
		id = "Armor",
		displayName = "Armor",
		description = "+1 armor",
		stat = "armor",
		mode = "flat",
		perLevel = 1,
	},
}

return table.freeze(Passives)
