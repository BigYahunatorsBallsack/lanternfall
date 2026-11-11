--!strict
-- Shop between waves (DESIGN.md section 3, Brotato direction since B1, complete since B3): Shards, offers, prices,
-- rerolls, locking, selling and the weapon pool.
-- Read by ShopService (server), ShopController and the HUD (client). Formulas follow Brotato's shop (assumption
-- where noted); item and weapon names are our own. Item prices and rarity chances live in Config.Items.

local Shop = {
	materialSyncSeconds = 0.2, -- transport only: coalesce material HUD updates; balances and pickup effects stay immediate
	phaseSeconds = 40, -- shop timer between two waves; cut short once every living participant pressed Ready
	slots = 4, -- offers per shop
	weaponChance = 0.35, -- share of weapon offers in a freely rolled slot (rest: items)
	-- minimum number of weapon offers for shops after wave <= untilWave (first matching entry applies); `exact`: that
	-- many weapons and no more, every other new slot is an item (Brotato's shops 1-2: exactly 2 weapons + 2 items)
	guaranteedWeapons = table.freeze({
		table.freeze({ untilWave = 2, count = 2, exact = true }),
		table.freeze({ untilWave = 5, count = 1, exact = false }),
	}),
	-- Which weapon a weapon slot offers (Brotato ItemService._get_rand_item_for_wave), from one roll r:
	--   owned chance = owned + max(0, (bonusWaves + 1 - wave) * ownedWaveBonus / bonusWaves) + n * ownedPerWeapon
	--   class chance = sameClass + max(0, (bonusWaves + 1 - wave) * classWaveBonus / bonusWaves) + n * classPerWeapon
	-- (n = different weapons owned, at most maxWeapons). r < owned chance: one of the player's weapons; else r < class
	-- chance: a weapon they do not own that shares a class with theirs; else any weapon they do not own. An empty pool
	-- falls back to every weapon of the tier.
	weaponPool = table.freeze({
		owned = 0.23,
		ownedWaveBonus = 0.07,
		ownedPerWeapon = 0.02,
		sameClass = 0.35,
		classWaveBonus = 0.2,
		classPerWeapon = 0.01,
		bonusWaves = 5,
		maxWeapons = 6,
	}),

	-- price = floor((base + wave * waveAdd + base * waveFactor * wave) * multiplier), at least 1; wave = the wave
	-- that just ended
	price = table.freeze({ waveAdd = 1, waveFactor = 0.1, multiplier = 1 }),
	-- tier I base prices of the weapons (Config.Weapons; items have theirs in Config.Items). Since B3 a weapon's tier
	-- (I-IV) is rolled like an item's rarity; its base price is the tier I price times tierPriceFactors[tier]
	-- (Brotato's weapon tables roughly double the price per tier).
	weaponPrices = table.freeze({
		CactiClub = 20,
		Chopper = 15,
		OrbitBlades = 46,
		Claw = 15,
		Drill = 250,
		Excalibur = 230,
		Quarterstaff = 15,
		BrassKnuckles = 10,
		FlamingBrassKnuckles = 46,
		WraithHatchet = 20,
		SpiritFlint = 12,
		Shockwave = 46,
		TithePalm = 10,
		Hatchet = 10,
		JoustingLance = 20,
		RitualDirk = 10,
		ChainLightning = 18,
		Plank = 15,
		PlasmaSledge = 136,
		PowerFist = 110,
		ThornTrail = 15,
		Gravestone = 10,
		Scissors = 15,
		RuneAwl = 10,
		Scythe = 285,
		LamplighterPike = 20,
		SpikyShield = 15,
		Stick = 10,
		DuskSabre = 51,
		ThiefDagger = 12,
		ThunderSword = 119,
		Torch = 10,
		FoundryKey = 20,
		ChainGun = 300,
		BoomerangAxe = 16,
		ScatterBell = 20,
		CinderBreath = 56,
		CathedralEngine = 290,
		GhostScepter = 15,
		LaserGun = 15,
		LeechCarbine = 15,
		Minigun = 127,
		NuclearLauncher = 144,
		Obliterator = 127,
		WatchmanPistol = 10,
		PotatoThrower = 36,
		Railgun = 20,
		Revolver = 20,
		MortarLantern = 56,
		ShrapnelOrgan = 15,
		Shuriken = 12,
		Slingshot = 15,
		RattleRepeater = 20,
		SniperGun = 115,
		GalvanicFork = 15,
		SparkBolt = 10,
		DEXtroyer = 315,
		Fireball = 36,
		WinterNeedle = 18,
		ParticleAccelerator = 144,
		SharpTooth = 12,
		VorpalSword = 55,
	}),
	weaponTierPrices = {
		CactiClub = { 20, 39, 74, 149 },
		Chopper = { 15, 31, 61, 122 },
		OrbitBlades = { 46, 46, 86, 173 },
		Claw = { 15, 28, 55, 110 },
		Drill = { 250, 250, 250, 250 },
		Excalibur = { 230, 230, 230, 230 },
		Quarterstaff = { 15, 31, 61, 122 },
		BrassKnuckles = { 10, 22, 45, 91 },
		FlamingBrassKnuckles = { 46, 46, 86, 173 },
		WraithHatchet = { 20, 39, 74, 149 },
		SpiritFlint = { 12, 26, 52, 105 },
		Shockwave = { 46, 46, 86, 151 },
		TithePalm = { 10, 22, 45, 91 },
		Hatchet = { 10, 22, 45, 91 },
		JoustingLance = { 20, 36, 72, 132 },
		RitualDirk = { 10, 22, 45, 91 },
		ChainLightning = { 18, 36, 66, 142 },
		Plank = { 15, 31, 61, 122 },
		PlasmaSledge = { 136, 136, 136, 272 },
		PowerFist = { 110, 110, 110, 221 },
		ThornTrail = { 15, 28, 52, 95 },
		Gravestone = { 10, 22, 45, 91 },
		Scissors = { 15, 31, 61, 122 },
		RuneAwl = { 10, 22, 45, 91 },
		Scythe = { 285, 285, 285, 285 },
		LamplighterPike = { 20, 39, 74, 149 },
		SpikyShield = { 15, 31, 61, 122 },
		Stick = { 10, 22, 45, 91 },
		DuskSabre = { 51, 51, 95, 190 },
		ThiefDagger = { 12, 26, 52, 105 },
		ThunderSword = { 119, 119, 119, 238 },
		Torch = { 10, 22, 45, 91 },
		FoundryKey = { 20, 39, 74, 149 },
		ChainGun = { 300, 300, 300, 300 },
		BoomerangAxe = { 16, 34, 62, 132 },
		ScatterBell = { 20, 39, 74, 149 },
		CinderBreath = { 56, 56, 103, 207 },
		CathedralEngine = { 290, 290, 290, 290 },
		GhostScepter = { 15, 31, 61, 122 },
		LaserGun = { 15, 31, 61, 122 },
		LeechCarbine = { 15, 31, 61, 122 },
		Minigun = { 127, 127, 127, 255 },
		NuclearLauncher = { 144, 144, 144, 289 },
		Obliterator = { 127, 127, 127, 255 },
		WatchmanPistol = { 10, 22, 45, 91 },
		PotatoThrower = { 36, 36, 69, 139 },
		Railgun = { 20, 40, 80, 160 },
		Revolver = { 20, 34, 70, 130 },
		MortarLantern = { 56, 56, 103, 207 },
		ShrapnelOrgan = { 15, 31, 61, 122 },
		Shuriken = { 12, 26, 52, 105 },
		Slingshot = { 15, 31, 61, 122 },
		RattleRepeater = { 20, 39, 74, 149 },
		SniperGun = { 115, 115, 115, 245 },
		GalvanicFork = { 15, 31, 61, 122 },
		SparkBolt = { 10, 22, 45, 91 },
		DEXtroyer = { 315, 315, 315, 315 },
		Fireball = { 36, 36, 66, 140 },
		WinterNeedle = { 18, 36, 66, 140 },
		ParticleAccelerator = { 144, 144, 144, 289 },
		SharpTooth = { 12, 26, 52, 105 },
		VorpalSword = { 55, 55, 100, 200 },
	},
	tierPriceFactors = table.freeze({ 1, 1.9, 3.7, 7.4 }),
	-- Selling a weapon (Brotato's recycling) gives this share of its current shop price (wave and tier), rounded down
	sellShare = 0.25,
	-- reroll: increase = max(1, floor(increaseFactor * wave * sqrt(1 + endless factor))); first = floor(firstFactor *
	-- wave) + increase;
	-- every further reroll in the same shop adds the increase again. Level-up cards reroll at the same prices.
	reroll = table.freeze({ increaseFactor = 0.4, firstFactor = 0.75 }),

	-- Brotato 1.2.0.1: RunData.set_player_count gives every player DebugService.starting_gold = 30 materials (not a
	-- debug-only value; reset() keeps it at 30). Character-specific starting grants are applied separately.
	startShards = 30,
	shardsPerXp = 1, -- Shards a player gets per XP of an orb they pick up (orbs are Brotato's materials)
	waveEnd = table.freeze({
		healFraction = 1, -- every participant heals to this share of max HP when a wave ends
		reviveDown = true, -- players who are down stand up again when a wave ends
	}),
}

Shop.wantedTagChance = 0.05 -- B10: dedicated matching-tag draw; empty pools fall back.
local weaponPrices = table.clone(Shop.weaponPrices)
for id, prices in require(script.Parent.CharacterWeaponData).prices do
	weaponPrices[id] = prices[1]
	Shop.weaponTierPrices[id] = prices
end
Shop.weaponPrices = table.freeze(weaponPrices)
return table.freeze(Shop)
