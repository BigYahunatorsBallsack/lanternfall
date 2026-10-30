--!strict
-- Items (DESIGN.md section 6, Brotato direction since B2; they replace the six passives). Bought in the shop between
-- waves or found in elite chests. Every item changes stats (Config.Stats ids, in the units the player sees), most
-- with a downside, and stacks without limit unless `limit` says otherwise. The stat packages follow Brotato's items
-- (HP times Config.Stats.hpScale); names and looks are our own. Vitality, Haste, Focus, Magnet, Might and Armor keep
-- the ids of the old passives, so the evolutions (Config.Evolutions) still find them.
-- Since B4 items can also have effects (Config.Effects: standing still, "per X", growth at the end of a wave, next wave,
-- on kill, on dodge ...; EffectService runs them). The items after the 46 of B2 each take one Brotato item's
-- mechanics and numbers (named in the comment, HP times hpScale); what needs a later package is left out and noted.
-- Since B5 12 more for the combat stats and effects (burning, explosions, piercing, bouncing, knockback), since B8
-- 24 more (kills, pickups, rerolls, level-ups, fruits and crates, living enemies, HP drain, strikes on enemies).
-- Also the rarity tiers: their chances by wave (shop) or level (level-up cards), raised by Luck (Util/StatMath).
-- Read by StatService, EffectService, ShopService/ShopRules, UpgradeService and the client (texts, colors).

local Effects = require(script.Parent.Effects)

export type Item = {
	id: string,
	displayName: string,
	tier: number, -- 1 Common, 2 Uncommon, 3 Rare, 4 Legendary
	price: number, -- base price in Shards (Config.Shop.price adds to it per wave)
	stats: { [string]: number },
	limit: number?, -- most you can own; nil = no limit
	effects: { Effects.Effect }?, -- since B4 (Config.Effects)
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
	limit: number?,
	effects: { Effects.Effect }?
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
	return table.freeze({
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
	-- Common with Brotato's secondary stats and effects (since B4)
	item("PawnTicket", "Pawn Ticket", 1, 15, { itemPrice = -5 }, 5), -- Coupon
	item("ChitteringFamiliar", "Chittering Familiar", 1, 25, { shardHealing = 8, rangedDamage = -1 }, 13), -- Cute Monkey
	item("BoneCharm", "Bone Charm", 1, 15, {}, nil, { -- Jelly
		{ trigger = "Always", action = "PerX", source = "distinctWeapons", per = 1, stats = { maxHp = 10 } },
	}),
	item("Satchel", "Satchel", 1, 15, { speed = -1 }, 3, { -- Bag (Brotato's crates are our chests)
		{ trigger = "Chest", action = "Shards", amount = 15 },
	}),
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
	-- Uncommon with effects (since B4)
	item("BitterTonic", "Bitter Tonic", 2, 35, {}, nil, { -- Celery Tea
		{ trigger = "WaveEnd", action = "Grow", stats = { xpGain = 5 } },
		{ trigger = "Acquire", action = "NextWaveStats", stats = { xpGain = 50, enemyHp = 100 } },
	}),
	item("JesterBell", "Jester's Bell", 2, 30, { freeRerolls = 1 }, 3), -- Dangerous Bunny
	-- Metal Detector without its +2 Engineering (B12)
	item("DowsingRod", "Dowsing Rod", 2, 40, { doubleShards = 5, luck = 6, damage = -5 }, 20),
	item("QuiltedCoat", "Quilted Coat", 2, 45, { maxHp = 30 }, 1, { -- Padding
		{ trigger = "Always", action = "PerX", source = "shards", per = 80, stats = { maxHp = 10 } },
	}),
	item("TitheBox", "Tithe Box", 2, 40, {}, 1, { -- Piggy Bank: stops working at wave 20
		{ trigger = "WaveStart", action = "ShardShare", amount = 20, untilWave = 19 },
	}),
	item("RottingHeart", "Rotting Heart", 2, 30, {}, nil, { -- Decomposing Flesh
		{ trigger = "LevelUp", action = "Grow", stats = { lifeSteal = 1, maxHp = -10 } },
	}),
	item("ScrapAltar", "Scrap Altar", 2, 35, { sellValue = 35 }, 1), -- Recycling Machine
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
	-- Rare with effects (since B4)
	item("IronVigil", "Iron Vigil", 3, 75, { speed = -5 }, 1, { -- Barricade without its +3 Knockback (B5)
		{ trigger = "Always", action = "Stats", state = "Still", stats = { armor = 8 } },
	}),
	item("StillVeil", "Still Veil", 3, 70, { dodge = 3, damage = -4 }, nil, { -- Chameleon
		{ trigger = "Always", action = "Stats", state = "Still", stats = { dodge = 20 } },
	}),
	item("StoneIdol", "Stone Idol", 3, 60, { speed = -10 }, nil, { -- Statue
		{ trigger = "Always", action = "Stats", state = "Still", stats = { attackSpeed = 40 } },
	}),
	item("GildedPlume", "Gilded Plume", 3, 50, { xpGain = 25 }, nil, { -- Peacock
		{ trigger = "Acquire", action = "NextWaveStats", stats = { xpGain = 100, enemyDamage = 50 } },
	}),
	item("OathRing", "Oath Ring", 3, 92, {}, nil, { -- Vigilante Ring
		{ trigger = "WaveEnd", action = "Grow", stats = { damage = 3 } },
	}),
	item("PulseDraught", "Pulse Draught", 3, 60, { dodge = 5 }, 1, { -- Adrenaline
		{ trigger = "Dodge", action = "Heal", amount = 50, chance = 0.5 },
	}),
	item("HuntersTally", "Hunter's Tally", 3, 55, {}, 3, { -- Hunting Trophy
		{ trigger = "Kill", action = "Shards", amount = 1, chance = 0.33, crit = true },
	}),
	item("GalvanicCoil", "Galvanic Coil", 3, 65, { damage = -5 }, 1, { -- Power Generator
		{ trigger = "Always", action = "PerX", source = "speed", per = 1, stats = { damage = 1 } },
	}),
	item("MourningVeil", "Mourning Veil", 3, 50, { hpRegen = 8 }, 1, { -- Sad Tomato
		{ trigger = "WaveStart", action = "HpFraction", amount = 0.5 },
	}),
	item("MossWard", "Moss Ward", 3, 50, {}, nil, { -- Tardigrade
		{ trigger = "WaveStart", action = "Shields", amount = 1 },
	}),
	item("PlagueRat", "Plague Rat", 3, 55, { lifeSteal = 5, enemyCount = 10, harvesting = -5 }, 5), -- Mouse
	-- Candle (its fog rule for Nightmare does not apply here)
	item("HushCandle", "Hush Candle", 3, 65, { elementalDamage = 4, hpRegen = 1, enemyCount = -10, damage = -5 }, 1),
	item("Changeling", "Changeling", 3, 80, { maxHp = 150, enemyHp = 10 }), -- Alien Baby
	item("SweetReliquary", "Sweet Reliquary", 3, 70, {}, 1, { -- Candy Bag without the extra elites (B11)
		{ trigger = "WaveEnd", action = "RandomStats", amount = 8 },
	}),
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
	-- Legendary with effects (since B4)
	item("ClockworkArm", "Clockwork Arm", 4, 100, {}, nil, { -- Robot Arm without its +3 Engineering (B12)
		{ trigger = "WaveEnd", action = "Grow", stats = { meleeDamage = 3, maxHp = -10 } },
	}),
	item("EvergreenSprig", "Evergreen Sprig", 4, 110, {}, nil, { -- Grind's Magical Leaf
		{ trigger = "WaveEnd", action = "Grow", stats = { maxHp = 30, hpRegen = 1, lifeSteal = 1 } },
	}),
	item("FortuneCoin", "Fortune Coin", 4, 105, { armor = -2 }, 1, { -- Lucky Coin
		{ trigger = "Always", action = "PerX", source = "critChance", per = 1, stats = { luck = 2 } },
	}),
	item("EightEyedIdol", "Eight-Eyed Idol", 4, 110, { damage = 12, dodge = -3, harvesting = -5 }, nil, { -- Spider
		{ trigger = "Always", action = "PerX", source = "distinctWeapons", per = 1, stats = { attackSpeed = 6 } },
	}),
	item("LoneFlame", "Lone Flame", 4, 110, { damage = 30 }, nil, { -- Focus
		{ trigger = "Always", action = "PerX", source = "distinctWeapons", per = 1, stats = { attackSpeed = -3 } },
	}),
	item("FieldCenser", "Field Censer", 4, 95, { hpRegen = 10, luck = -10 }, nil, { -- Medikit
		{ trigger = "Timer", action = "WaveStats", interval = 5, stats = { hpRegen = 2 } },
	}),
	item("EmberAnvil", "Ember Anvil", 4, 120, {}, 1, { -- Anvil
		{ trigger = "ShopEnter", action = "UpgradeWeapon", stats = { armor = 2 } },
	}),
	-- Combat (since B5: burning, explosions, piercing, bouncing, knockback; Config.Combat). Brotato item in the
	-- comment; prices marked "assumption" are not known from Brotato.
	item("SmolderingWick", "Smoldering Wick", 1, 25, {}, 4, { -- Scared Sausage
		{ trigger = "Hit", action = "Burn", chance = 0.25, amount = 1, scaling = { elementalDamage = 1 }, ticks = 3 },
	}),
	item("AshSerpent", "Ash Serpent", 1, 25, { burnSpread = 1, maxHp = -10 }), -- Snake
	item("Bellows", "Bellows", 2, 40, { burnSpeed = 20 }, 2), -- Eyes Surgery (price assumption)
	item("BlackPowder", "Black Powder", 1, 20, { explosionDamage = 15 }), -- Dynamite (price assumption)
	item("FulminateJar", "Fulminate Jar", 3, 60, { explosionSize = 25 }), -- Plastic Explosive (price assumption)
	item("BurstingSigil", "Bursting Sigil", 3, 65, {}, nil, { -- Rip and Tear (price assumption)
		{
			trigger = "Kill",
			action = "Explode",
			chance = 0.2,
			amount = 10,
			scaling = { meleeDamage = 0.5 },
			size = 0.65,
		},
	}),
	item("NeedleCharm", "Needle Charm", 3, 75, { piercing = 1, damage = -10 }), -- Bandana
	item( -- Sharp Bullet
		"HollowNail",
		"Hollow Nail",
		1,
		25,
		{ piercing = 1, piercingDamage = -20, damage = -5, knockback = -3 },
		1
	),
	item("GourdLantern", "Gourd Lantern", 2, 40, { piercingDamage = 15, damage = -2 }), -- Pumpkin
	item("MirrorShard", "Mirror Shard", 4, 110, { bounce = 1, damage = -25 }), -- Ricochet
	item("IronGauntlet", "Iron Gauntlet", 1, 20, { knockback = 3 }), -- Boxing Glove (price assumption)
	item("RecoilSpring", "Recoil Spring", 3, 60, { knockback = 5 }, 3, { -- Coil (price assumption)
		{ trigger = "Always", action = "PerX", source = "knockback", per = 1, stats = { damage = 1 } },
	}),
	-- Item package (since B8): Brotato item in the comment, its numbers (HP times hpScale); Engineering, curses and
	-- structures are left out until their packages.
	-- Common
	item("GrubTincture", "Grub Tincture", 1, 15, { maxHp = 30, hpRegen = 2, fruitHeal = -10 }), -- Alien Worm
	item("BeckoningBell", "Beckoning Bell", 1, 30, { maxHp = 20, damage = 5, enemyCount = 5 }, 10), -- Gentle Alien
	item("TaintedElixir", "Tainted Elixir", 1, 20, { maxHp = 20, meleeDamage = 2, attackSpeed = -3 }), -- Defective Steroids
	item("HookedTongue", "Hooked Tongue", 1, 25, { pickupRange = 30, knockback = 1 }), -- Alien Tongue
	item("CrackedSkull", "Cracked Skull", 1, 25, { damage = 6, range = -8 }), -- Head Injury
	item("WispJar", "Wisp Jar", 1, 22, {}, nil, { -- Baby Elephant
		{
			trigger = "Pickup",
			action = "Strike",
			target = "random",
			chance = 0.25,
			amount = 1,
			scaling = { luck = 0.25 },
		},
	}),
	-- Uncommon
	item("OrderSash", "Sash of the Order", 2, 50, { xpGain = 25, meleeDamage = 3, knockback = 3, luck = -8 }), -- Black Belt
	item("RollingEye", "Rolling Eye", 2, 30, {}, nil, { -- Cyberball
		{
			trigger = "Kill",
			action = "Strike",
			target = "random",
			chance = 0.25,
			amount = 1,
			scaling = { luck = 0.25 },
		},
	}),
	item("InkPolyp", "Ink Polyp", 2, 55, { attackSpeed = -3 }, nil, { -- Baby Squid
		{ trigger = "LevelUp", action = "Grow", stats = { hpRegen = 1 } },
	}),
	item("Knucklebones", "Knucklebones", 2, 30, {}, 2, { -- Bone Dice
		{ trigger = "Reroll", action = "Grow", chance = 0.5, stats = { damage = 1 } },
		{ trigger = "Reroll", action = "Grow", chance = 0.1, stats = { maxHp = -10 } },
	}),
	item("WitchKettle", "Witch's Kettle", 2, 35, { pickupRange = 50, hpRegen = -2 }, 1, { -- Cauldron
		{ trigger = "Consumable", action = "TimedStats", seconds = 2, stats = { damage = 20 } },
	}),
	item("SaltCoral", "Salt Coral", 2, 40, { range = -10 }, nil, { -- Coral
		{ trigger = "Always", action = "Stats", state = "Still", stats = { hpRegen = 10 } },
	}),
	-- Rare
	item("AstralPhilter", "Astral Philter", 3, 85, { maxHp = 80, hpRegen = 3, luck = -8 }), -- Alien Magic
	item( -- Honey
		"AmberResin",
		"Amber Resin",
		3,
		70,
		{ rangedDamage = 3, explosionDamage = 10, explosionSize = 5, speed = -3, dodge = -3 }
	),
	item("RabbleBanner", "Rabble Banner", 3, 75, { armor = -2 }, 1, { -- Community Support
		{ trigger = "Always", action = "PerX", source = "enemies", per = 1, stats = { attackSpeed = 1 } },
	}),
	item("HearthSprite", "Hearth Sprite", 3, 85, {}, 1, { -- Fairy
		{ trigger = "Always", action = "PerX", source = "distinctItemsTier1", per = 1, stats = { hpRegen = 1 } },
		{ trigger = "Always", action = "PerX", source = "distinctItemsTier4", per = 1, stats = { hpRegen = -3 } },
	}),
	item("BloodChalice", "Blood Chalice", 3, 70, { hpRegen = -3 }, 3, { -- Goblet
		{ trigger = "Kill", action = "Heal", chance = 0.15, amount = 10 },
	}),
	-- Legendary
	item("CrimsonHand", "Crimson Hand", 4, 110, { lifeSteal = 10 }, 1, { -- Bloody Hand
		{ trigger = "Always", action = "PerX", source = "lifeSteal", per = 1, stats = { damage = 2 } },
		{ trigger = "Timer", action = "Drain", interval = 1, amount = 10 },
	}),
	item("VelvetDivan", "Velvet Divan", 4, 100, { maxHp = 50, speed = -20 }, 1, { -- Esty's Couch
		{ trigger = "Always", action = "PerX", source = "speed", per = -1, min = 0, stats = { hpRegen = 2 } },
	}),
	item( -- Exoskeleton without its +5 Engineering (B12)
		"BrassCarapace",
		"Brass Carapace",
		4,
		90,
		{ armor = 3, critChance = 5, speed = 5, hpRegen = -2, lifeSteal = -2 }
	),
	item("ThunderShells", "Thunder Shells", 4, 100, { explosionDamage = 60, explosionSize = 15, damage = -15 }), -- Explosive Shells
	item("SecondStomach", "Second Stomach", 4, 100, {}, 1, { -- Extra Stomach
		{ trigger = "Consumable", action = "Grow", fullHp = true, maxPerWave = 8, stats = { maxHp = 10 } },
	}),
	item("TitanGirdle", "Titan's Girdle", 4, 110, {}, 1, { -- Giant Belt
		{ trigger = "Crit", action = "Strike", hpShare = 0.1, eliteHpShare = 0.01 },
	}),
	item("PyreAshes", "Pyre Ashes", 4, 100, { damage = 20, attackSpeed = 20, range = 100 }, nil, { -- Ashes
		{ trigger = "WaveEnd", action = "Grow", stats = { armor = -1 } },
	}),
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
