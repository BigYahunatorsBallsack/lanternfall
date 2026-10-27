--!strict
-- Player stats (DESIGN.md section 4, Brotato direction since B2): the list of stats, their level-up upgrade values
-- and the numbers of the formulas in Util/StatMath. Values are kept in the units the player sees: "percent" stats in
-- percent points (5 = +5 %), the others as plain numbers. Read by StatService (sums), WeaponStats, CombatService,
-- ExperienceService, ShopService, UpgradeService and the client (stat panel, card texts).
--
-- HP is Brotato's times `hpScale`: our players start with 100 HP instead of 10, so Max HP values, the HP a
-- regeneration tick heals and the HP life steal heals are multiplied by it.

export type StatId =
	"maxHp"
	| "hpRegen"
	| "lifeSteal"
	| "damage"
	| "meleeDamage"
	| "rangedDamage"
	| "elementalDamage"
	| "attackSpeed"
	| "critChance"
	| "range"
	| "armor"
	| "dodge"
	| "speed"
	| "luck"
	| "harvesting"
	| "xpGain"
	| "pickupRange"

export type Stat = {
	id: string,
	displayName: string,
	percent: boolean, -- shown and stored as percent points
	primary: boolean, -- primary stats get level-up upgrades; secondary ones only come from items
	upgrade: { number }?, -- level-up values for tier 1..4 (primary stats)
}

local function stat(id: string, displayName: string, percent: boolean, upgrade: { number }?): Stat
	return table.freeze({
		id = id,
		displayName = displayName,
		percent = percent,
		primary = upgrade ~= nil,
		upgrade = if upgrade then table.freeze(upgrade) else nil,
	})
end

-- In the order of the stat panel. Upgrade values as in Brotato (Max HP times hpScale); Engineering is left out
-- because there are no structures.
local ORDER: { Stat } = {
	stat("maxHp", "Max HP", false, { 30, 60, 90, 120 }),
	stat("hpRegen", "HP Regeneration", false, { 2, 3, 4, 5 }),
	stat("lifeSteal", "Life Steal", true, { 1, 2, 3, 4 }),
	stat("damage", "Damage", true, { 5, 8, 12, 16 }),
	stat("meleeDamage", "Melee Damage", false, { 2, 4, 6, 8 }),
	stat("rangedDamage", "Ranged Damage", false, { 1, 2, 3, 4 }),
	stat("elementalDamage", "Elemental Damage", false, { 1, 2, 3, 4 }),
	stat("attackSpeed", "Attack Speed", true, { 5, 10, 15, 20 }),
	stat("critChance", "Crit Chance", true, { 3, 5, 7, 9 }),
	stat("range", "Range", false, { 15, 30, 45, 60 }),
	stat("armor", "Armor", false, { 1, 2, 3, 4 }),
	stat("dodge", "Dodge", true, { 3, 6, 9, 12 }),
	stat("speed", "Speed", true, { 3, 6, 9, 12 }),
	stat("luck", "Luck", false, { 5, 10, 15, 20 }),
	stat("harvesting", "Harvesting", false, { 5, 8, 10, 12 }),
	stat("xpGain", "XP Gain", true, nil),
	stat("pickupRange", "Pickup Range", true, nil),
}

local byId: { [string]: Stat } = {}
for _, entry in ORDER do
	byId[entry.id] = entry
end

return table.freeze({
	order = table.freeze(ORDER),
	byId = table.freeze(byId),

	hpScale = 10,
	maxHpPerLevel = 10, -- every team level (Brotato: +1 Max HP)

	-- HP Regeneration: one tick of hpScale HP every baseSeconds / (1 + (regen - 1) / divisor) seconds (1 regen = 5 s,
	-- 10 regen = 1 s); nothing below 1.
	regen = table.freeze({ baseSeconds = 5, divisor = 2.25 }),
	-- Life Steal: chance per weapon hit to heal hpScale HP, at most once per this many seconds (10 per second).
	lifeSteal = table.freeze({ minSecondsBetween = 0.1 }),
	-- Armor: damage taken x 1 / (1 + armor / divisor); negative armor: x (divisor - 2 armor) / (divisor - armor).
	armor = table.freeze({ divisor = 15 }),
	dodge = table.freeze({ max = 60 }), -- percent; more Dodge than this does nothing
	critChanceMax = 100, -- percent, base crit of the weapons (Config.Player.critChance) included
	-- Attack Speed: cooldowns / (1 + AS); negative AS: cooldowns x (1 + |AS| x negativeFactor), so it hurts less than
	-- the same plus helps (Brotato does not publish its formula; assumption).
	attackSpeed = table.freeze({ negativeFactor = 0.5 }),
	-- Range: points like Brotato's (a pistol has 400); studsPerPoint turns them into studs. Melee weapons get
	-- meleeFactor of it, and no weapon range drops below minStuds.
	range = table.freeze({ studsPerPoint = 0.1, meleeFactor = 0.5, minStuds = 2.5 }),
	-- Harvesting: at the end of each wave Shards and team XP equal to it, then it grows by this share (rounded up).
	harvesting = table.freeze({ growth = 0.05 }),
	-- Speed: move speed x (1 + speed / 100), never below this share of the base speed.
	minSpeedFactor = 0,
})
