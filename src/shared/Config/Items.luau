--!strict
-- Main-game Brotato item replacements, consumed by stats, effects, shops and inventory UI.
-- Owner request 2026-11-06: original names, prices, tiers, limits and complete effects replace the former variants.
-- Historical ids remain internal so saved achievement unlocks and weapon evolutions keep working.
-- HP and healing use original Brotato units (current main). Source facts: docs/item-parity/catalog.json.

local Effects = require(script.Parent.Effects)

export type Item = {
	description: string?,
	available: boolean?, -- false while original artwork is only prepared locally
	structure: string?,
	pet: string?,
	nativeWinWith: string?,
	nativeChallenge: string?,
	id: string,
	displayName: string,
	tier: number, -- 1 Common, 2 Uncommon, 3 Rare, 4 Legendary
	price: number, -- base price in Shards (Config.Shop.price adds to it per wave)
	stats: { [string]: number },
	limit: number?, -- most you can own; nil = no limit
	effects: { Effects.Effect }?, -- since B4 (Config.Effects)
	tags: { string }, -- B10: positive stat/effect affinities used by character shops
}

-- Chance of a tier at wave (or level) w, Brotato's ItemService.get_tier_from_wave: base + perWave * (w - minWave + 1)
-- times (1 + luck / 100), or divided by (1 + |luck| / 100) for negative Luck, at most `max`, 0 before minWave. Rolled from the rarest down with one number (Util/StatMath.rollTier).
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
	limit: number?,
	effects: { Effects.Effect }?,
	description: string?
): Item
	if effects then
		for index, effect in effects do
			if effect.stats then
				table.freeze(effect.stats)
			end
			if effect.scaling then
				table.freeze(effect.scaling)
			end
			effects[index] = table.freeze(effect)
		end
	end
	local tags = {}
	local found = {}
	local function tag(name: string)
		if not found[name] then
			found[name] = true
			table.insert(tags, name)
		end
	end
	for name, value in stats do
		if value > 0 then
			tag(name)
		end
	end
	for _, effect in effects or {} do
		for name, value in effect.stats or {} do
			if value > 0 then
				tag(name)
			end
		end
		if effect.trigger == "Consumable" then
			tag("consumable")
		end
		if effect.action == "Burn" then
			tag("elementalDamage")
		end
	end
	if (stats.fruitHeal or 0) > 0 then
		tag("consumable")
	end
	table.sort(tags)
	return table.freeze({
		description = description,
		tags = table.freeze(tags),
		id = id,
		displayName = displayName,
		tier = tier,
		price = price,
		stats = table.freeze(stats),
		limit = limit,
		effects = if effects then table.freeze(effects) else nil,
	})
end

local LIST: { Item } = {
	item("Vitality", "Cake", 1, 15, { maxHp = 3, damage = -1 }),
	item("Haste", "Beanie", 1, 20, { speed = 4, range = -6 }),
	item("Focus", "Coffee", 1, 20, { attackSpeed = 10, damage = -2 }),
	item("Magnet", "Boiling Water", 1, 30, { elementalDamage = 2, maxHp = -1 }),
	item("Might", "Injection", 1, 20, { damage = 7, maxHp = -2 }),
	item("Armor", "Metal Plate", 2, 40, { armor = 2, damage = -3 }),
	item("WaxHeart", "Broken Mouth", 1, 25, { maxHp = 5, hpRegen = -1 }),
	item("CrackedLens", "Glasses", 1, 20, { range = 20 }),
	item("BoneKnuckles", "Plant", 1, 15, { hpRegen = 3, lifeSteal = -1 }),
	item("TallowCandle", "Charcoal", 1, 20, { elementalDamage = 1, meleeDamage = 2, harvesting = -2 }),
	item("MothWing", "Butterfly", 1, 30, { lifeSteal = 2, elementalDamage = -1 }),
	item("GraveSpade", "Fertilizer", 1, 15, { harvesting = 8, meleeDamage = -1 }),
	item("CatClaw", "Claw Tree", 1, 20, { meleeDamage = 1, critChance = 3, maxHp = -1 }),
	item("RustedCoin", "Lost Duck", 1, 25, { luck = 8, elementalDamage = -1 }),
	item("FlintShard", "Lens", 1, 20, { rangedDamage = 1, range = -5 }),
	item("WardRune", "Peaceful Bee", 1, 18, { dodge = 4, harvesting = 4, meleeDamage = -1, rangedDamage = -1 }),
	item("PawnTicket", "Coupon", 1, 15, { itemPrice = -5 }, 5),
	item("ChitteringFamiliar", "Cute Monkey", 1, 25, { rangedDamage = -1, shardHealing = 8 }, 13),
	item(
		"BoneCharm",
		"Jelly",
		1,
		15,
		{},
		nil,
		{ { trigger = "Always", action = "PerX", source = "distinctWeapons", per = 1, stats = { maxHp = 1 } } }
	),
	item("Satchel", "Bag", 1, 15, { speed = -1 }, 3, { { trigger = "Chest", action = "Shards", amount = 15 } }),
	item("LeechJar", "Blood Leech", 2, 45, { lifeSteal = 2, hpRegen = 2, harvesting = -3 }),
	item("AshBlindfold", "Blindfold", 2, 45, { critChance = 5, dodge = 5, range = -15 }),
	item("SignalBanner", "Banner", 2, 55, { range = 20, attackSpeed = 10, knockback = -5 }),
	item("Brazier", "Campfire", 2, 40, { elementalDamage = 2, hpRegen = 2, speed = -2 }),
	item("OilFlask", "Fuel Tank", 2, 45, { elementalDamage = 4, meleeDamage = -1, rangedDamage = -1 }),
	item("LoadedDice", "Gambling Token", 2, 50, { dodge = 8, armor = -1 }),
	item("NarrowScope", "Cyclops Worm", 2, 45, { damage = 12, range = -12 }),
	item("Whetstone", "Mastery", 2, 55, { meleeDamage = 6, rangedDamage = -3 }),
	item("AcidVial", "Acid", 2, 65, { maxHp = 8, dodge = -2, knockback = -2 }),
	item("StaticBracelet", "Energy Bracelet", 2, 55, { critChance = 4, elementalDamage = 2, rangedDamage = -2 }),
	item("PowderPouch", "Small Magazine", 2, 60, { rangedDamage = 2, attackSpeed = 10, damage = -6 }),
	item("LanternOil", "Shady Potion", 2, 48, { luck = 20, hpRegen = -2 }),
	item("BitterTonic", "Celery Tea", 2, 35, {}, nil, {
		{ trigger = "WaveEnd", action = "Grow", stats = { xpGain = 5 } },
		{ trigger = "Acquire", action = "NextWaveStats", stats = { xpGain = 50, enemyHp = 100 } },
	}),
	item("JesterBell", "Dangerous Bunny", 2, 30, { freeRerolls = 1 }, 3),
	item("DowsingRod", "Metal Detector", 2, 40, { luck = 6, engineering = 2, damage = -5, doubleShards = 5 }, 20),
	item(
		"QuiltedCoat",
		"Padding",
		2,
		45,
		{ maxHp = 3 },
		1,
		{ { trigger = "Always", action = "PerX", source = "shards", per = 80, stats = { maxHp = 1 } } }
	),
	item(
		"TitheBox",
		"Piggy Bank",
		2,
		40,
		{},
		1,
		{ { trigger = "WaveStart", action = "ShardShare", amount = 20, untilWave = 20 } }
	),
	item(
		"RottingHeart",
		"Decomposing Flesh",
		2,
		30,
		{},
		nil,
		{ { trigger = "LevelUp", action = "Grow", stats = { lifeSteal = 1, maxHp = -1 } } }
	),
	item("ScrapAltar", "Recycling Machine", 2, 35, { sellValue = 35 }, 1),
	item("GlassLantern", "Glass Cannon", 3, 75, { damage = 25, armor = -3 }),
	item("FourLeafCharm", "Clover", 3, 65, { luck = 20, dodge = 6, lifeSteal = -2 }),
	item("EelFin", "Fin", 3, 65, { speed = 10, lifeSteal = 3, luck = -8 }),
	item(
		"BloodOffering",
		"Blood Donation",
		3,
		50,
		{ harvesting = 40 },
		nil,
		{ { trigger = "Timer", action = "Drain", interval = 1, amount = 1 } }
	),
	item(
		"IronShackle",
		"Ball and Chain",
		3,
		75,
		{ damage = 15, armor = 3, knockback = 5, speed = -3, weaponCooldownMin = 0.75 },
		1
	),
	item("ClockworkGears", "Poisonous Tonic", 3, 80, { attackSpeed = 10, critChance = 5, range = 15, hpRegen = -2 }),
	item("TomeOfEchoes", "Bean Teacher", 3, 70, { xpGain = 50, lifeSteal = -2 }),
	item("SmokeMantle", "Ghost Outfit", 3, 80, { dodge = 10, speed = -5, armor = -3, dodgeCap = 70 }, 1),
	item("SilverRounds", "Silver Bullet", 3, 70, { eliteDamage = 25 }),
	item("ThornCrown", "Wheat", 3, 85, { meleeDamage = 4, rangedDamage = 2, harvesting = 10, elementalDamage = -2 }),
	item(
		"IronVigil",
		"Barricade",
		3,
		75,
		{ knockback = 3, speed = -5 },
		nil,
		{ { trigger = "Always", action = "Stats", state = "Still", stats = { armor = 8 } } }
	),
	item(
		"StillVeil",
		"Chameleon",
		3,
		70,
		{ dodge = 3, damage = -4 },
		nil,
		{ { trigger = "Always", action = "Stats", state = "Still", stats = { dodge = 20 } } }
	),
	item(
		"StoneIdol",
		"Statue",
		3,
		60,
		{ speed = -10 },
		nil,
		{ { trigger = "Always", action = "Stats", state = "Still", stats = { attackSpeed = 40 } } }
	),
	item(
		"GildedPlume",
		"Peacock",
		3,
		50,
		{ xpGain = 25 },
		nil,
		{ { trigger = "Acquire", action = "NextWaveStats", stats = { xpGain = 100, enemyDamage = 50 } } }
	),
	item(
		"OathRing",
		"Vigilante Ring",
		3,
		92,
		{},
		nil,
		{ { trigger = "WaveEnd", action = "Grow", stats = { damage = 3 } } }
	),
	item(
		"PulseDraught",
		"Adrenaline",
		3,
		60,
		{ dodge = 5 },
		1,
		{ { trigger = "Dodge", action = "Heal", amount = 5, chance = 0.5 } }
	),
	item(
		"HuntersTally",
		"Hunting Trophy",
		3,
		55,
		{},
		3,
		{ { trigger = "Kill", action = "Shards", amount = 1, chance = 0.33, crit = true } }
	),
	item(
		"GalvanicCoil",
		"Power Generator",
		3,
		65,
		{ damage = -5 },
		1,
		{ { trigger = "Always", action = "PerX", source = "speed", per = 1, stats = { damage = 1 } } }
	),
	item(
		"MourningVeil",
		"Sad Tomato",
		3,
		50,
		{ hpRegen = 8 },
		1,
		{ { trigger = "WaveStart", action = "HpFraction", amount = 0.5 } }
	),
	item("MossWard", "Tardigrade", 3, 50, {}, nil, { { trigger = "WaveStart", action = "Shields", amount = 1 } }),
	item("PlagueRat", "Mouse", 3, 55, { lifeSteal = 5, enemyCount = 10, harvesting = -5 }, 5),
	item("HushCandle", "Candle", 3, 65, { elementalDamage = 4, hpRegen = 1, enemyCount = -10, damage = -5 }, 1),
	item("Changeling", "Alien Baby", 3, 80, { maxHp = 15, enemyHp = 10 }),
	item("SweetReliquary", "Candy Bag", 3, 70, {}, 1, {
		{ trigger = "WaveEnd", action = "RandomStats", amount = 8 },
		{ trigger = "WaveStart", action = "SpawnElite", chance = 0.1, amount = 1 },
	}),
	item(
		"TitanArms",
		"Big Arms",
		4,
		105,
		{ meleeDamage = 12, rangedDamage = 6, knockback = 3, attackSpeed = -3, speed = -3 }
	),
	item(
		"ShadowCloak",
		"Cape",
		4,
		110,
		{ lifeSteal = 5, dodge = 20, meleeDamage = -2, rangedDamage = -2, elementalDamage = -2 }
	),
	item(
		"HeavyRounds",
		"Heavy Bullets",
		4,
		100,
		{ rangedDamage = 5, damage = 10, range = 10, attackSpeed = -5, critChance = -5 }
	),
	item("ColossusHeart", "Octopus", 4, 105, { maxHp = 12, hpRegen = 5, lifeSteal = 3, critChance = -8 }),
	item("BrassHarness", "Jet Pack", 4, 100, { speed = 15, dodge = 10, maxHp = -5, armor = -1 }),
	item("WitchMortar", "Gnome", 4, 100, { meleeDamage = 10, elementalDamage = 10, range = -20, pickupRange = -20 }),
	item("LanternCodex", "Diploma", 4, 90, { engineering = 10, xpGain = 50, maxHp = -3 }),
	item("EternalFlame", "Potato", 4, 95, {
		maxHp = 3,
		hpRegen = 2,
		lifeSteal = 1,
		damage = 5,
		attackSpeed = 5,
		speed = 3,
		dodge = 3,
		armor = 1,
		luck = 5,
	}),
	item(
		"ClockworkArm",
		"Robot Arm",
		4,
		100,
		{},
		nil,
		{ { trigger = "WaveEnd", action = "Grow", stats = { meleeDamage = 3, engineering = 3, maxHp = -1 } } }
	),
	item(
		"EvergreenSprig",
		"Grind's Magical Leaf",
		4,
		110,
		{},
		nil,
		{ { trigger = "WaveEnd", action = "Grow", stats = { maxHp = 3, hpRegen = 1, lifeSteal = 1 } } }
	),
	item(
		"FortuneCoin",
		"Lucky Coin",
		4,
		105,
		{ armor = -2 },
		1,
		{ { trigger = "Always", action = "PerX", source = "critChance", per = 1, stats = { luck = 2 } } }
	),
	item(
		"EightEyedIdol",
		"Spider",
		4,
		110,
		{ damage = 12, dodge = -3, harvesting = -5 },
		nil,
		{ { trigger = "Always", action = "PerX", source = "distinctWeapons", per = 1, stats = { attackSpeed = 6 } } }
	),
	item(
		"LoneFlame",
		"Focus",
		4,
		110,
		{ damage = 30 },
		nil,
		{ { trigger = "Always", action = "PerX", source = "distinctWeapons", per = 1, stats = { attackSpeed = -3 } } }
	),
	item(
		"FieldCenser",
		"Medikit",
		4,
		95,
		{ hpRegen = 10, luck = -10 },
		nil,
		{ { trigger = "Timer", action = "WaveStats", interval = 5, stats = { hpRegen = 2 } } }
	),
	item(
		"EmberAnvil",
		"Anvil",
		4,
		120,
		{},
		1,
		{ { trigger = "ShopEnter", action = "UpgradeWeapon", stats = { armor = 2 } } }
	),
	item("SmolderingWick", "Scared Sausage", 1, 25, {}, 4, {
		{
			trigger = "Hit",
			action = "Burn",
			chance = 0.25,
			amount = 1,
			scaling = { elementalDamage = 1 },
			ticks = 3,
		},
	}),
	item("AshSerpent", "Snake", 1, 25, { maxHp = -1, burnSpread = 1 }),
	item("Bellows", "Eyes Surgery", 2, 60, { elementalDamage = 1, range = -10, burnSpeed = 20 }, 2),
	item("BlackPowder", "Dynamite", 1, 20, { explosionDamage = 15 }),
	item("FulminateJar", "Plastic Explosive", 3, 60, { explosionSize = 25 }),
	item("BurstingSigil", "Rip and Tear", 3, 65, { critChance = -5 }, 5, {
		{
			trigger = "Kill",
			action = "Explode",
			chance = 0.2,
			amount = 10,
			scaling = { meleeDamage = 0.5 },
			size = 0.65,
		},
	}),
	item("NeedleCharm", "Bandana", 3, 75, { damage = -10, piercing = 1 }),
	item("HollowNail", "Sharp Bullet", 1, 25, { damage = -5, knockback = -3, piercing = 1, piercingDamage = -20 }, 1),
	item("GourdLantern", "Pumpkin", 2, 40, { damage = -2, piercingDamage = 15 }),
	item("MirrorShard", "Ricochet", 4, 110, { damage = -25, bounce = 1 }),
	item("IronGauntlet", "Boxing Glove", 1, 18, { meleeDamage = 1, knockback = 3 }),
	item(
		"RecoilSpring",
		"Coil",
		3,
		70,
		{ knockback = 5 },
		3,
		{ { trigger = "Always", action = "PerX", source = "knockback", per = 1, stats = { damage = 1 } } }
	),
	item("GrubTincture", "Alien Worm", 1, 15, { maxHp = 3, hpRegen = 2, fruitHeal = -1 }),
	item("BeckoningBell", "Gentle Alien", 1, 30, { maxHp = 2, damage = 5, enemyCount = 5 }, 10),
	item("TaintedElixir", "Defective Steroids", 1, 20, { maxHp = 2, meleeDamage = 2, attackSpeed = -3 }),
	item("HookedTongue", "Alien Tongue", 1, 25, { pickupRange = 30, knockback = 1 }),
	item("CrackedSkull", "Head Injury", 1, 25, { damage = 6, range = -8 }),
	item("WispJar", "Baby Elephant", 1, 22, {}, nil, {
		{
			trigger = "Pickup",
			action = "Strike",
			target = "random",
			chance = 0.25,
			amount = 1,
			scaling = { luck = 0.25 },
		},
	}),
	item("OrderSash", "Black Belt", 2, 50, { xpGain = 25, meleeDamage = 3, knockback = 3, luck = -8 }),
	item("RollingEye", "Cyberball", 2, 30, {}, nil, {
		{
			trigger = "Kill",
			action = "Strike",
			target = "random",
			chance = 0.25,
			amount = 1,
			scaling = { luck = 0.25 },
		},
	}),
	item("InkPolyp", "Bat", 1, 20, { lifeSteal = 2, harvesting = -2 }),
	item(
		"Knucklebones",
		"Tentacle",
		2,
		35,
		{ critChance = 3 },
		5,
		{ { trigger = "Kill", action = "Heal", crit = true, chance = 0.2, amount = 1 } }
	),
	item("WitchKettle", "Lemonade", 1, 15, { fruitHeal = 1 }),
	item("SaltCoral", "Mushroom", 1, 25, { hpRegen = 3, luck = -2 }),
	item("AstralPhilter", "Alien Magic", 3, 85, { maxHp = 8, hpRegen = 3, luck = -8 }),
	item(
		"AmberResin",
		"Honey",
		3,
		70,
		{ rangedDamage = 3, explosionDamage = 10, explosionSize = 5, speed = -3, dodge = -3 }
	),
	item(
		"RabbleBanner",
		"Community Support",
		3,
		75,
		{ armor = -2 },
		1,
		{ { trigger = "Always", action = "PerX", source = "enemies", per = 1, stats = { attackSpeed = 1 } } }
	),
	item("HearthSprite", "Fairy", 3, 85, {}, 1, {
		{ trigger = "Always", action = "PerX", source = "distinctItemsTier1", per = 1, stats = { hpRegen = 1 } },
		{ trigger = "Always", action = "PerX", source = "distinctItemsTier4", per = 1, stats = { hpRegen = -3 } },
	}),
	item("BloodChalice", "Sunglasses", 2, 50, { critChance = 10, armor = -1 }),
	item("CrimsonHand", "Bloody Hand", 4, 110, { lifeSteal = 10 }, 1, {
		{ trigger = "Always", action = "PerX", source = "lifeSteal", per = 1, stats = { damage = 2 } },
		{ trigger = "Timer", action = "Drain", interval = 1, amount = 1 },
	}),
	item(
		"VelvetDivan",
		"Esty's Couch",
		4,
		100,
		{ maxHp = 5, speed = -20 },
		1,
		{ { trigger = "Always", action = "PerX", source = "speed", per = -1, min = 0, stats = { hpRegen = 2 } } }
	),
	item(
		"BrassCarapace",
		"Exoskeleton",
		4,
		90,
		{ armor = 3, critChance = 5, engineering = 5, speed = 5, hpRegen = -2, lifeSteal = -2 }
	),
	item("ThunderShells", "Explosive Shells", 4, 100, { explosionDamage = 60, explosionSize = 15, damage = -15 }),
	item(
		"SecondStomach",
		"Extra Stomach",
		4,
		100,
		{},
		1,
		{ { trigger = "Consumable", action = "Grow", fullHp = true, maxPerWave = 8, stats = { maxHp = 1 } } }
	),
	item(
		"TitanGirdle",
		"Giant Belt",
		4,
		110,
		{},
		1,
		{ { trigger = "Crit", action = "Strike", hpShare = 0.1, eliteHpShare = 0.01 } }
	),
	item("PyreAshes", "Warrior Helmet", 3, 80, { armor = 3, maxHp = 5, speed = -5 }),
	item("CalibratedTools", "Improved Tools", 3, 70, { attackSpeed = 10 }, 1),
	item(
		"BloodLure",
		"Bait",
		2,
		25,
		{ damage = 8 },
		nil,
		nil,
		"7-8 Hookfangs appear at the start of the next wave for each new lure."
	),
}

-- Structure ids stay stable for weapon deployments and the compact network feed.
table.insert(
	LIST,
	table.freeze({
		id = "BrassSentry",
		displayName = "Turret",
		tier = 1,
		price = 15,
		stats = table.freeze({}),
		structure = "BrassSentry",
		tags = table.freeze({ "engineering", "structure" }),
	})
)
table.insert(
	LIST,
	table.freeze({
		id = "CinderSentry",
		displayName = "Incendiary Turret",
		tier = 2,
		price = 40,
		stats = table.freeze({}),
		structure = "CinderSentry",
		tags = table.freeze({ "engineering", "structure" }),
	})
)
table.insert(
	LIST,
	table.freeze({
		id = "PrismSentry",
		displayName = "Laser Turret",
		tier = 3,
		price = 65,
		stats = table.freeze({}),
		structure = "PrismSentry",
		tags = table.freeze({ "engineering", "structure" }),
	})
)
table.insert(
	LIST,
	table.freeze({
		id = "MercySentry",
		displayName = "Medical Turret",
		tier = 2,
		price = 40,
		stats = table.freeze({}),
		structure = "MercySentry",
		tags = table.freeze({ "engineering", "structure" }),
	})
)
table.insert(
	LIST,
	table.freeze({
		id = "SiegeSentry",
		displayName = "Explosive Turret",
		tier = 4,
		price = 80,
		stats = table.freeze({}),
		structure = "SiegeSentry",
		tags = table.freeze({ "engineering", "structure" }),
	})
)
table.insert(
	LIST,
	table.freeze({
		id = "RuneMine",
		displayName = "Landmines",
		tier = 1,
		price = 15,
		stats = table.freeze({}),
		structure = "RuneMine",
		tags = table.freeze({ "engineering", "structure" }),
	})
)
table.insert(
	LIST,
	table.freeze({
		id = "MoonGarden",
		displayName = "Garden",
		tier = 2,
		price = 50,
		stats = table.freeze({}),
		structure = "MoonGarden",
		tags = table.freeze({ "engineering", "structure" }),
	})
)
table.insert(
	LIST,
	table.freeze({
		id = "OrbitWisp",
		displayName = "Wandering Bot",
		tier = 3,
		price = 60,
		stats = table.freeze({}),
		structure = "OrbitWisp",
		tags = table.freeze({ "engineering", "structure" }),
	})
)
table.insert(
	LIST,
	table.freeze({
		id = "StormFamiliar",
		displayName = "Tyler",
		tier = 2,
		price = 62,
		stats = table.freeze({}),
		structure = "StormFamiliar",
		tags = table.freeze({ "engineering", "structure" }),
	})
)

-- Pacifist's mandatory native start item; original artwork is locally prepared, with no fabricated upload id.
table.insert(
	LIST,
	table.freeze({
		id = "LumberjackShirt",
		displayName = "Lumberjack Shirt",
		tier = 1,
		price = 15,
		limit = 1,
		available = false,
		stats = table.freeze({}),
		tags = table.freeze({ "exploration" }),
		effects = table.freeze({ table.freeze({ trigger = "Always", action = "OneShotTrees" }) }),
	})
)

-- Dig Site supplies Shovel's original lifetime digging challenge; local artwork remains gated.
table.insert(
	LIST,
	table.freeze({
		id = "DigSite",
		displayName = "Dig Site",
		tier = 2,
		price = 45,
		limit = 2,
		available = false,
		nativeWinWith = "Archaeologist",
		nativeChallenge = "chal_archaeologist",
		stats = table.freeze({ luck = -3 }),
		tags = table.freeze({ "luck" }),
		description = "1 dig site appears every 3 waves, stay on it for 5 to 6 seconds to dig up a crate",
		effects = table.freeze({ table.freeze({ trigger = "Always", action = "DigSites", amount = 1, per = 3 }) }),
	})
)
-- Original pet actors stay artwork-gated until actual original uploads are supplied.
table.insert(
	LIST,
	table.freeze({
		id = "Ratzilla",
		displayName = "Ratzilla",
		tier = 1,
		price = 30,
		available = false,
		stats = table.freeze({}),
		structure = "Ratzilla",
		pet = "Ratzilla",
		tags = table.freeze({ "maxHp", "pet" }),
	})
)
table.insert(
	LIST,
	table.freeze({
		id = "BonkDog",
		displayName = "Bonk Dog",
		tier = 2,
		price = 40,
		available = false,
		stats = table.freeze({}),
		structure = "BonkDog",
		pet = "BonkDog",
		tags = table.freeze({ "meleeDamage", "explosive", "pet" }),
	})
)
table.insert(
	LIST,
	table.freeze({
		id = "BotOMine",
		displayName = "Bot-O-Mine",
		tier = 2,
		price = 55,
		available = false,
		stats = table.freeze({}),
		structure = "BotOMine",
		pet = "BotOMine",
		tags = table.freeze({ "engineering", "pet", "structure" }),
	})
)
table.insert(
	LIST,
	table.freeze({
		id = "Blazemander",
		displayName = "Blazemander",
		tier = 2,
		price = 40,
		available = false,
		stats = table.freeze({}),
		structure = "Blazemander",
		pet = "Blazemander",
		tags = table.freeze({ "elementalDamage", "pet" }),
	})
)
table.insert(
	LIST,
	table.freeze({
		id = "CatlingGun",
		displayName = "Catling Gun",
		tier = 2,
		price = 34,
		available = false,
		stats = table.freeze({}),
		structure = "CatlingGun",
		pet = "CatlingGun",
		tags = table.freeze({ "pet", "rangedDamage" }),
	})
)
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
