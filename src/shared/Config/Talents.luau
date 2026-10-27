--!strict
-- Permanent talents bought with embers (DESIGN.md section 10). Keys match the profile schema `talents` table.
-- `value` is applied per rank (stat ids and units of Config.Stats where it is one); costs[n] is the price of rank n.

export type Talent = {
	id: string,
	displayName: string,
	stat: string,
	value: number,
	costs: { number },
}

local Talents: { [string]: Talent } = {
	toughness = {
		id = "toughness",
		displayName = "Toughness",
		stat = "maxHp",
		value = 3,
		costs = { 100, 200, 400, 700, 1000 },
	},
	power = {
		id = "power",
		displayName = "Power",
		stat = "damage",
		value = 2,
		costs = { 100, 200, 400, 700, 1000 },
	},
	reach = {
		id = "reach",
		displayName = "Reach",
		stat = "pickupRange",
		value = 5,
		costs = { 100, 200, 400, 700, 1000 },
	},
	greed = {
		id = "greed",
		displayName = "Greed",
		stat = "embers",
		value = 0.05,
		costs = { 100, 200, 400, 700, 1000 },
	},
	rescuer = {
		id = "rescuer",
		displayName = "Rescuer",
		stat = "reviveSpeed",
		value = 0.1,
		costs = { 150, 300, 600 },
	},
	rerolls = {
		id = "rerolls",
		displayName = "Second Thoughts",
		stat = "rerolls",
		value = 1,
		costs = { 500, 1500 },
	},
}

return table.freeze(Talents)
