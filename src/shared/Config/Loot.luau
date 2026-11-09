--!strict
-- Loot like Brotato (DESIGN.md section 3, since B6): how often enemies drop their orb, the bag for orbs left at the
-- end of a wave, fruits and crates (Brotato's consumables), Looters and Trees. Rules in Util/LootRules. Read by
-- ExperienceService (orbs, bag), LootService (fruits, crates), UpgradeService (crate items), SpawnDirector (Looters,
-- Trees) and the client (PickupRenderer). Per enemy type, Config.Enemies `loot` overrides the defaults below.

return table.freeze({
	-- Orbs (Brotato's materials): a normal enemy drops its orb with this chance: 100 % up to wave fullUntilWave, then
	-- 1 - lossPerWave * wave, at least minChance (wave 5: 92.5 %, wave 10: 85 %, wave 20: 70 %). Elites always drop,
	-- and so do enemies whose Config.Enemies loot says alwaysOrbs (Looters, Trees).
	orbDrop = table.freeze({ fullUntilWave = 4, lossPerWave = 0.015, minChance = 0.5 }),
	-- Bag: orbs still on the floor when a wave ends go into the team's bag instead of being paid out. In the next
	-- waves every new orb takes up to pullPerValue times its own value from the bag (picking it up is worth double,
	-- like Brotato) until the bag is empty. The bag is lost when the run ends.
	bag = table.freeze({ pullPerValue = 1 }),

	-- Fruits and crates (Brotato's consumables). A killed enemy drops one with `chance` times (1 + Luck / 100) (Luck =
	-- average of the participants who are not out; -100 Luck: none). It is a crate with crateShare * (1 + Luck / 100)
	-- / (1 + crates dropped this wave), else a fruit, so crate floods slow down. Elites drop chests instead.
	consumables = table.freeze({
		chance = 0.01, -- Brotato's Baby Alien; bigger enemies have more in Config.Enemies
		crateShare = 0.25, -- assumption: Brotato gives no base number
		maxOnFloor = 40, -- more fruits than this are not dropped (crates always are; assumption)
		-- Picked up within the orb pickup radius (Config.Player.pickupRadius, times Pickup Range) like orbs.
	}),
	-- A fruit heals this much HP (Brotato 3 HP), plus the Fruit Healing stat.
	fruit = table.freeze({ heal = 3 }),
	-- A crate heals like a fruit and holds an item: picked up during the wave, opened one by one at the wave end before
	-- the level-up cards (take it or sell it for Config.Shop.sellShare + Sell Value of its price). The rarity is rolled
	-- like a shop item (wave and Luck), at least minTier. Not chosen in autoPickSeconds (Config.Run.levelUp) or before
	-- the next wave: taken.
	crate = table.freeze({ heal = 3, minTier = 1 }),
	-- Legendary crate (Brotato's elite crate, since WP10): from bosses (later also rare elites, B11). Heals 100 HP and holds an item of at least minTier (4 = Legendary); it opens like a crate, before the other crates.
	legendaryCrate = table.freeze({ heal = 100, minTier = 4 }),

	-- Looters (Brotato's Loot Alien): when and how many come is Brotato's own every-wave group (Config.EnemyWaves:
	-- first roll 25 s into a wave, then every 15 s, 10 % each). It runs away from the players and escapes after
	-- lifetimeSeconds; killed it drops a crate and its orb (Config.Enemies.Looter). spawnDistance: debug spawns only.
	looter = table.freeze({
		enemy = "Looter",
		lifetimeSeconds = 12, -- assumption
		spawnDistance = 30, -- studs from the player a debug Looter appears near
	}),

	-- Trees: neutral, they stand still and do nothing; weapons hit them like enemies. When and how many grow is
	-- Brotato's own every-wave group (Config.EnemyWaves: every 10 s from 10 s, 1-2 plus the Trees stat, 33 % each).
	-- Killed they drop a fruit or crate and an orb of 3 (Config.Enemies.Tree). Gone at the wave end like every enemy.
	trees = table.freeze({
		enemy = "Tree",
	}),
})
