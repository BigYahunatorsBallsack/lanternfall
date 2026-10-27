--!strict
-- Items (DESIGN.md section 6, Brotato direction since B2; they replace the six passives). Bought in the shop between
-- waves or found in elite chests. Every item changes stats (Config.Stats ids, in the units the player sees), most
-- with a downside, and stacks without limit unless `limit` says otherwise. The stat packages follow Brotato's items
-- (HP times Config.Stats.hpScale); names and looks are our own. Vitality, Haste, Focus, Magnet, Might and Armor keep
-- the ids of the old passives, so the evolutions (Config.Evolutions) still find them.
-- Also the rarity tiers: their chances by wave (shop) or level (level-up cards), raised by Luck (Util/StatMath).
-- Read by StatService, ShopService/ShopRules, UpgradeService and the client (texts, colors).

export type Item = {
	id: string,
	displayName: string,
	tier: number, -- 1 Common, 2 Uncommon, 3 Rare, 4 Legendary
	price: number, -- base price in Shards (Config.Shop.price adds to it per wave)
	stats: { [string]: number },
	limit: number?, -- most you can own; nil = no limit
}

-- Chance of a tier at wave (or level) w, Brotato's shop table: (perWave * (w - minWave + 1) + base) * (1 + luck / 100),
-- at most `max`, 0 before minWave. Rolled from the rarest down with one number (Util/StatMath.rollTier).
export type Tier = {
	name: string,
	minWave: number,
	base: number,
	perWave: number,
	max: number,
}

local function item(
	id: string,
	displayName: string,
	tier: number,
	price: number,
	stats: { [string]: number },
	limit: number?
): Item
	return table.freeze({
		id = id,
		displayName = displayName,
		tier = tier,
		price = price,
		stats = table.freeze(stats),
		limit = limit,
	})
end

local LIST: { Item } = {
	-- Common
	item("Vitality", "Vitality", 1, 15, { maxHp = 30, damage = -1 }),
	item("Haste", "Haste", 1, 20, { speed = 4, range = -6 }),
	item("Focus", "Focus", 1, 20, { attackSpeed = 10, damage = -2 }),
	item("Magnet", "Magnet", 1, 20, { pickupRange = 30 }),
	item("Might", "Might", 1, 18, { damage = 5, maxHp = -10 }),
	item("Armor", "Armor Plate", 1, 18, { armor = 1, maxHp = -10 }),
	item("WaxHeart", "Wax Heart", 1, 18, { maxHp = 20, hpRegen = 2, speed = -1 }),
	item("CrackedLens", "Cracked Lens", 1, 20, { range = 20 }),
	item("BoneKnuckles", "Bone Knuckles", 1, 15, { meleeDamage = 1 }),
	item("TallowCandle", "Tallow Candle", 1, 20, { meleeDamage = 2, elementalDamage = 1, harvesting = -2 }),
	item("MothWing", "Moth Wing", 1, 30, { lifeSteal = 2, elementalDamage = -1 }),
	item("GraveSpade", "Grave Spade", 1, 15, { harvesting = 8, meleeDamage = -1 }),
	item("CatClaw", "Cat Claw", 1, 20, { meleeDamage = 1, critChance = 3, maxHp = -10 }),
	item("RustedCoin", "Rusted Coin", 1, 15, { luck = 8, damage = -1 }),
	item("FlintShard", "Flint Shard", 1, 15, { rangedDamage = 1, meleeDamage = -1 }),
	item("WardRune", "Ward Rune", 1, 20, { dodge = 3, maxHp = -10 }),
	-- Uncommon
	item("LeechJar", "Leech Jar", 2, 45, { lifeSteal = 2, hpRegen = 2, harvesting = -3 }),
	item("AshBlindfold", "Ash Blindfold", 2, 45, { critChance = 5, dodge = 5, range = -15 }),
	item("SignalBanner", "Signal Banner", 2, 55, { range = 20, attackSpeed = 10 }),
	item("Brazier", "Brazier", 2, 40, { elementalDamage = 2, hpRegen = 2, speed = -2 }),
	item("OilFlask", "Oil Flask", 2, 45, { elementalDamage = 4, meleeDamage = -1, rangedDamage = -1 }),
	item("LoadedDice", "Loaded Dice", 2, 50, { dodge = 8, armor = -1 }),
	item("NarrowScope", "Narrow Scope", 2, 45, { damage = 12, range = -12 }),
	item("Whetstone", "Whetstone", 2, 35, { meleeDamage = 3, attackSpeed = -3 }),
	item("AcidVial", "Acid Vial", 2, 65, { maxHp = 80, dodge = -2 }),
	item("StaticBracelet", "Static Bracelet", 2, 55, { critChance = 4, elementalDamage = 2, rangedDamage = -2 }),
	item("PowderPouch", "Powder Pouch", 2, 45, { rangedDamage = 2, attackSpeed = 5, armor = -1 }),
	item("LanternOil", "Lantern Oil", 2, 45, { luck = 15, speed = 2, damage = -2 }),
	-- Rare
	item("GlassLantern", "Glass Lantern", 3, 75, { damage = 25, armor = -3 }),
	item("FourLeafCharm", "Four-Leaf Charm", 3, 65, { luck = 20, dodge = 6, lifeSteal = -2 }),
	item("EelFin", "Eel Fin", 3, 65, { speed = 10, lifeSteal = 3, luck = -8 }),
	item("BloodOffering", "Blood Offering", 3, 55, { harvesting = 40, maxHp = -20 }),
	item("IronShackle", "Iron Shackle", 3, 75, { damage = 15, armor = 3, speed = -3 }, 1),
	item("ClockworkGears", "Clockwork Gears", 3, 70, { attackSpeed = 10, critChance = 5, range = -10 }),
	item("TomeOfEchoes", "Tome of Echoes", 3, 70, { xpGain = 50, lifeSteal = -2 }),
	item("SmokeMantle", "Smoke Mantle", 3, 80, { dodge = 10, speed = -5, armor = -3 }),
	item("SilverRounds", "Silver Rounds", 3, 70, { rangedDamage = 3, critChance = 5, speed = -3 }),
	item("ThornCrown", "Thorn Crown", 3, 70, { meleeDamage = 4, elementalDamage = 4, attackSpeed = -5 }),
	-- Legendary
	item("TitanArms", "Titan Arms", 4, 105, { meleeDamage = 12, rangedDamage = 6, attackSpeed = -3, speed = -3 }),
	item(
		"ShadowCloak",
		"Shadow Cloak",
		4,
		110,
		{ lifeSteal = 5, dodge = 20, meleeDamage = -2, rangedDamage = -2, elementalDamage = -2 }
	),
	item(
		"HeavyRounds",
		"Heavy Rounds",
		4,
		100,
		{ rangedDamage = 5, damage = 10, range = 10, attackSpeed = -5, critChance = -5 }
	),
	item("ColossusHeart", "Colossus Heart", 4, 110, { maxHp = 150, hpRegen = 5, speed = -10 }),
	item(
		"BrassHarness",
		"Brass Harness",
		4,
		90,
		{ armor = 3, critChance = 5, speed = 5, hpRegen = -2, lifeSteal = -2 }
	),
	item(
		"WitchMortar",
		"Witch's Mortar",
		4,
		100,
		{ meleeDamage = 10, elementalDamage = 10, range = -20, pickupRange = -20 }
	),
	item("LanternCodex", "Lantern Codex", 4, 90, { xpGain = 50, luck = 10, maxHp = -30 }),
	item("EternalFlame", "Eternal Flame", 4, 120, { damage = 20, attackSpeed = 20, armor = -2 }),
}

local byId: { [string]: Item } = {}
for _, entry in LIST do
	byId[entry.id] = entry
end

local TIERS: { Tier } = {
	{ name = "Common", minWave = 1, base = 1, perWave = 0, max = 1 },
	{ name = "Uncommon", minWave = 2, base = 0, perWave = 0.06, max = 0.6 },
	{ name = "Rare", minWave = 4, base = 0, perWave = 0.02, max = 0.25 },
	{ name = "Legendary", minWave = 8, base = 0, perWave = 0.0023, max = 0.08 },
}
for index, tier in TIERS do
	TIERS[index] = table.freeze(tier)
end

return table.freeze({
	list = table.freeze(LIST), -- in this order in the code; sorted by id where order matters (rolls)
	byId = table.freeze(byId),
	tiers = table.freeze(TIERS),
	chestMinTier = 2, -- an elite chest without an evolution gives an item of at least this tier (assumption)
})
