--!strict
-- Shop between waves (DESIGN.md section 3, Brotato direction since B1): Shards, offers, prices and rerolls.
-- Read by ShopService (server), ShopController and the HUD (client). Formulas follow Brotato's shop (assumption
-- where noted); item and weapon names are our own.

local Shop = {
	phaseSeconds = 40, -- shop timer between two waves; cut short once every living participant pressed Ready
	slots = 4, -- offers per shop
	weaponChance = 0.35, -- share of weapon offers in a freely rolled slot (rest: passive items)
	-- minimum number of weapon offers for shops after wave <= untilWave (first matching entry applies)
	guaranteedWeapons = table.freeze({
		table.freeze({ untilWave = 2, count = 2 }),
		table.freeze({ untilWave = 5, count = 1 }),
	}),
	ownedItemWeight = 2, -- owned weapons and items are this many times as likely to be offered

	-- price = floor((base + wave * waveAdd + base * waveFactor * wave) * multiplier), at least 1; wave = the wave
	-- that just ended
	price = table.freeze({ waveAdd = 1, waveFactor = 0.1, multiplier = 1 }),
	-- base prices by item id (Config.Weapons and Config.Passives). Buying something the player already owns raises
	-- it one level at the same price (stands in for Brotato's weapon merging until B3).
	basePrices = table.freeze({
		OrbitBlades = 18,
		SparkBolt = 18,
		Shockwave = 22,
		ChainLightning = 25,
		ThornTrail = 20,
		BoomerangAxe = 24,
		Vitality = 15,
		Haste = 14,
		Focus = 20,
		Magnet = 12,
		Might = 20,
		Armor = 16,
	}),
	-- reroll: increase = max(1, floor(increaseFactor * wave)); first = floor(firstFactor * wave) + increase;
	-- every further reroll in the same shop adds the increase again
	reroll = table.freeze({ increaseFactor = 0.4, firstFactor = 0.75 }),

	shardsPerXp = 1, -- Shards a player gets per XP of an orb they pick up (orbs are Brotato's materials)
	waveEnd = table.freeze({
		healFraction = 1, -- every participant heals to this share of max HP when a wave ends
		reviveDown = true, -- players who are down stand up again when a wave ends
	}),
}

return table.freeze(Shop)
