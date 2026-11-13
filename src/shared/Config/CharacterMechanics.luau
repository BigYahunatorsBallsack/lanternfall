--!strict
-- Shared native character rule constants and source stat names; read by CharacterService rules and runtime.
return table.freeze({
	hordeChanceOverrides = table.freeze({ Jack = 0 }),
	fisherman = table.freeze({
		groupEvery = 10,
		baseCount = 1,
		randomSplit = 0.5,
		maximumDanger = 9999,
		maximumWave = 99999,
		bonusEvery = 15,
		timingSpan = 50,
		minimumTiming = 15,
		areaMinimum = 20,
		areaMaximum = 30,
		repeatMinimum = 6,
		repeatMaximum = 8,
		repeats = 999,
		enemy = "Hookfang",
	}),
	explorerTreesStartSeconds = 5,
	steps = table.freeze({ animationSeconds = 0.6, perAnimation = 2, baseSpeed = 45 }),
	economy = table.freeze({
		priceEndlessDivisor = 5,
		demonPriceDivisor = 20, -- stable ItemService.get_value
		endlessNegativeWalletPercent = -100, -- stable main.gdc negative start-wave effects in endless
		minimumMaterialFactor = 0.5, -- stable main.gdc MIN_GOLD_CHANCE
		-- stable CoopService.ADDITIONAL_MATERIALS_FACTOR: materials +(n / (1 + 0.3 (n - 1)) - 1) * 0.8 for n players
		coopMaterialsFactor = 0.8,
		minimumRecycleShare = 0.01, -- stable ItemService.get_recycling_value
		maximumRecycleShare = 1,
		minimumRecycleValue = 1,
		endlessHarvestingDecrease = 0.2, -- stable RunData.ENDLESS_HARVESTING_DECREASE = 20
	}),
	periodSeconds = 1,
	halfWaveShare = 0.5, -- stable WaveTimer starts its HalfWaveTimer at wait_time / 2
	lowHealthShare = 0.5,
	minimumStatStrike = 1,
	weaponSlotUpgrade = table.freeze({
		amount = 1,
		source = "res://items/upgrades/weapon_slot/weapon_slot_effect.tres",
	}),
	movementIntent = table.freeze({
		maxDirectionMagnitude = 1.001, -- unit-vector floating-point tolerance, never a client-selected speed
		minSendSeconds = 0.05,
		heartbeatSeconds = 0.5,
		lifetimeSeconds = 1.5,
		rateCount = 24,
		rateSeconds = 1,
	}),
	statIds = table.freeze({
		stat_max_hp = "maxHp",
		stat_hp_regeneration = "hpRegen",
		stat_lifesteal = "lifeSteal",
		stat_percent_damage = "damage",
		stat_melee_damage = "meleeDamage",
		stat_ranged_damage = "rangedDamage",
		stat_elemental_damage = "elementalDamage",
		stat_engineering = "engineering",
		stat_attack_speed = "attackSpeed",
		stat_crit_chance = "critChance",
		stat_range = "range",
		stat_armor = "armor",
		stat_dodge = "dodge",
		stat_speed = "speed",
		stat_luck = "luck",
		stat_harvesting = "harvesting",
		stat_curse = "curse",
		stat_evolution = "evolution",
		xp_gain = "xpGain",
		pickup_range = "pickupRange",
		items_price = "itemPrice",
		knockback = "knockback",
		explosion_damage = "explosionDamage",
		explosion_size = "explosionSize",
		piercing = "piercing",
		piercing_damage = "piercingDamage",
		bounce_damage = "bounceDamage",
		damage_against_bosses = "eliteDamage",
		number_of_enemies = "enemyCount",
		enemy_health = "enemyHp",
		enemy_damage = "enemyDamage",
		enemy_speed = "enemySpeed",
		consumable_heal = "fruitHeal",
		trees = "trees",
		structure_attack_speed = "structureAttackSpeed",
		structure_range = "structureRange",
	}),
})
