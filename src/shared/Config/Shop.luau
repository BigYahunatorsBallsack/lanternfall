--!strict
-- Shop between waves (DESIGN.md section 3, Brotato direction since B1, complete since B3): Shards, offers, prices,
-- rerolls, locking, selling and the weapon pool.
-- Read by ShopService (server), ShopController and the HUD (client). Formulas follow Brotato's shop (assumption
-- where noted); item and weapon names are our own. Item prices and rarity chances live in Config.Items.

local Shop = {
	phaseSeconds = 40, -- shop timer between two waves; cut short once every living participant pressed Ready
	slots = 4, -- offers per shop
	weaponChance = 0.35, -- share of weapon offers in a freely rolled slot (rest: items)
	-- minimum number of weapon offers for shops after wave <= untilWave (first matching entry applies)
	guaranteedWeapons = table.freeze({
		table.freeze({ untilWave = 2, count = 2 }),
		table.freeze({ untilWave = 5, count = 1 }),
	}),
	-- Which weapon a weapon slot offers (Brotato): with `owned` chance one the player already has, else with
	-- `sameClass` chance one that shares a class with one of theirs, else any weapon (all of them only if nothing fits)
	weaponPool = table.freeze({ owned = 0.2, sameClass = 0.15 }),

	-- price = floor((base + wave * waveAdd + base * waveFactor * wave) * multiplier), at least 1; wave = the wave
	-- that just ended
	price = table.freeze({ waveAdd = 1, waveFactor = 0.1, multiplier = 1 }),
	-- tier I base prices of the weapons (Config.Weapons; items have theirs in Config.Items). Since B3 a weapon's tier
	-- (I-IV) is rolled like an item's rarity; its base price is the tier I price times tierPriceFactors[tier]
	-- (Brotato's weapon tables roughly double the price per tier).
	weaponPrices = table.freeze({
		OrbitBlades = 18,
		SparkBolt = 18,
		Shockwave = 22,
		ChainLightning = 25,
		ThornTrail = 20,
		BoomerangAxe = 24,
	}),
	tierPriceFactors = table.freeze({ 1, 1.9, 3.7, 7.4 }),
	-- Selling a weapon (Brotato's recycling) gives this share of its current shop price (wave and tier), rounded down
	sellShare = 0.25,
	-- Every this many purchases in one shop earn one free reroll (it does not raise the reroll price)
	freeRerollAfterBuys = 4,
	-- reroll: increase = max(1, floor(increaseFactor * wave)); first = floor(firstFactor * wave) + increase;
	-- every further reroll in the same shop adds the increase again. Level-up cards reroll at the same prices.
	reroll = table.freeze({ increaseFactor = 0.4, firstFactor = 0.75 }),

	shardsPerXp = 1, -- Shards a player gets per XP of an orb they pick up (orbs are Brotato's materials)
	waveEnd = table.freeze({
		healFraction = 1, -- every participant heals to this share of max HP when a wave ends
		reviveDown = true, -- players who are down stand up again when a wave ends
	}),
}

return table.freeze(Shop)
