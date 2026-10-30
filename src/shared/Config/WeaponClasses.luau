--!strict
-- Weapon classes (DESIGN.md section 6, Brotato's weapon sets since B5): every weapon belongs to one or two classes
-- (Config.Weapons -> classes). Carrying 2 to 6 weapons of a class (copies count) gives that class's bonus for the
-- count; the bonuses replace each other, they do not add up. Numbers are Brotato's (Max HP times Config.Stats.hpScale),
-- the names our own. Brotato's Tool class (Engineering) follows with structures (B12); its Legendary class has no
-- weapons here yet. Read by Util/WeaponClasses (StatService adds the bonus, the client shows it) and ShopRules (the
-- shop prefers classes you own).

export type WeaponClass = {
	id: string,
	displayName: string,
	-- bonuses[n] = the stats for carrying n weapons of the class (2..maxCount); fewer than 2 give nothing
	bonuses: { [number]: { [string]: number } },
}

local function class(id: string, displayName: string, bonuses: { { [string]: number } }): WeaponClass
	local byCount: { [number]: { [string]: number } } = {}
	for index, stats in bonuses do
		byCount[index + 1] = table.freeze(stats)
	end
	return table.freeze({ id = id, displayName = displayName, bonuses = table.freeze(byCount) })
end

local ORDER: { WeaponClass } = {
	-- Blade
	class("Edge", "Edge", {
		{ meleeDamage = 1, lifeSteal = 1 },
		{ meleeDamage = 2, lifeSteal = 2 },
		{ meleeDamage = 3, lifeSteal = 3 },
		{ meleeDamage = 4, lifeSteal = 4 },
		{ meleeDamage = 5, lifeSteal = 5 },
	}),
	-- Blunt
	class("Bludgeon", "Bludgeon", {
		{ armor = 1, speed = -2 },
		{ armor = 1, maxHp = 30, speed = -4 },
		{ armor = 2, maxHp = 30, speed = -6 },
		{ armor = 2, maxHp = 60, speed = -8 },
		{ armor = 3, maxHp = 60, speed = -10 },
	}),
	-- Elemental
	class("Arcane", "Arcane", {
		{ elementalDamage = 1 },
		{ elementalDamage = 2 },
		{ elementalDamage = 3 },
		{ elementalDamage = 4 },
		{ elementalDamage = 5 },
	}),
	-- Ethereal
	class("Spectral", "Spectral", {
		{ dodge = 6, armor = -1 },
		{ dodge = 12, armor = -2 },
		{ dodge = 18, armor = -3 },
		{ dodge = 24, armor = -4 },
		{ dodge = 30, armor = -5 },
	}),
	-- Explosive
	class("Volatile", "Volatile", {
		{ explosionSize = 5 },
		{ explosionSize = 10 },
		{ explosionSize = 15 },
		{ explosionSize = 20 },
		{ explosionSize = 25 },
	}),
	-- Gun
	class("Longshot", "Longshot", {
		{ range = 10 },
		{ range = 20 },
		{ range = 30 },
		{ range = 40 },
		{ range = 50 },
	}),
	-- Heavy
	class("Colossal", "Colossal", {
		{ damage = 5 },
		{ damage = 10 },
		{ damage = 15 },
		{ damage = 20 },
		{ damage = 25 },
	}),
	-- Medical
	class("Remedy", "Remedy", {
		{ hpRegen = 1 },
		{ hpRegen = 2 },
		{ hpRegen = 3 },
		{ hpRegen = 4 },
		{ hpRegen = 5 },
	}),
	-- Medieval
	class("Knightly", "Knightly", {
		{ armor = 1 },
		{ armor = 1, dodge = 3 },
		{ armor = 2, dodge = 3 },
		{ armor = 2, dodge = 6 },
		{ armor = 3, dodge = 6 },
	}),
	-- Musical
	class("Choir", "Choir", {
		{ luck = 5 },
		{ luck = 10 },
		{ luck = 15 },
		{ luck = 20 },
		{ luck = 25 },
	}),
	-- Precise
	class("Keen", "Keen", {
		{ critChance = 3 },
		{ critChance = 6 },
		{ critChance = 9 },
		{ critChance = 12 },
		{ critChance = 15 },
	}),
	-- Primitive
	class("Primal", "Primal", {
		{ maxHp = 30 },
		{ maxHp = 60 },
		{ maxHp = 90 },
		{ maxHp = 120 },
		{ maxHp = 150 },
	}),
	-- Support
	class("Steward", "Steward", {
		{ harvesting = 5 },
		{ harvesting = 10 },
		{ harvesting = 15 },
		{ harvesting = 20 },
		{ harvesting = 25 },
	}),
	-- Unarmed
	class("Brawl", "Brawl", {
		{ dodge = 3 },
		{ dodge = 6 },
		{ dodge = 9 },
		{ dodge = 12 },
		{ dodge = 15 },
	}),
}

local byId: { [string]: WeaponClass } = {}
for _, entry in ORDER do
	byId[entry.id] = entry
end

return table.freeze({
	order = table.freeze(ORDER),
	byId = table.freeze(byId),
	minCount = 2, -- weapons of a class before its first bonus
	maxCount = 6, -- the bonus stops growing here (Brotato's six weapon slots)
})
