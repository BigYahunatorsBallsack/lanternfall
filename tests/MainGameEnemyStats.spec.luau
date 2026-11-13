--!strict
-- Wiki-derived fixtures verify all main-game stats and the runtime appearance/growth rules.
-- Source: https://brotato.wiki.spellsandguns.com/Enemies (2026-11-06), Crash Zone only.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local EnemyStats = require(Shared.Util.EnemyStats)
local EnemyKinds = require(Shared.Util.EnemyKinds)
local StatMath = require(Shared.Util.StatMath)
local WeaponStats = require(game:GetService("ServerScriptService").Server.Services.WeaponService.WeaponStats)
local SpawnRules = require(game:GetService("ServerScriptService").Server.Services.SpawnDirector.SpawnRules)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)

-- Tree HP is the owner's deliberate deviation (2026-11-08: double Brotato's 10 + 5/wave).
-- ID, wiki reference, HP, HP/wave, minimum/maximum speed, contact damage, damage/wave, knockback, materials, fruit %, crate %.
local fixture = {
	{ "Tree", "Tree", 20, 10, 0, 0, 0, 0, 1, 3, 100, 20 },
	{ "Shadeling", "Baby Alien", 3, 2, 200, 300, 1, 0.6, 0, 1, 1, 1 },
	{ "AbyssShadeling", "Chaser", 1, 1, 380, 380, 1, 0.6, 0, 1, 2, 3 },
	{ "Spitter", "Spitter", 8, 1, 200, 200, 1, 0.6, 0.95, 1, 3, 10 },
	{ "Charger", "Charger", 4, 2.5, 400, 400, 1, 0.85, 0.8, 1, 1, 1 },
	{ "Stalker", "Pursuer", 10, 24, 150, 150, 1, 1.2, 0, 3, 3, 3 },
	{ "Brute", "Bruiser", 20, 11, 300, 300, 2, 0.85, 0.9, 3, 3, 3 },
	{ "Herald", "Buffer", 20, 3, 150, 150, 1, 0.6, 0.95, 2, 1, 1 },
	{ "Thornback", "Fly", 15, 4, 325, 375, 1, 0.85, 0, 1, 1, 1 },
	{ "Mender", "Healer", 10, 8, 400, 400, 1, 0.85, 0, 2, 3, 3 },
	{ "Looter", "Looter", 5, 30, 300, 400, 1, 0.85, 0, 8, 100, 100 },
	{ "IronHusk", "Helmet Alien", 8, 4, 225, 275, 1, 1, 0.5, 1, 1, 1 },
	{ "Splitling", "Fin Alien", 12, 2, 400, 400, 1, 1, 0, 1, 2, 3 },
	{ "Splitter", "Spawner", 10, 1, 120, 120, 1, 0.85, 0.7, 1, 1, 1 },
	{ "Skulker", "Junkie", 5, 4, 300, 300, 1, 1, 0.5, 1, 0, 0 }, -- can_drop_consumables false (1.2.0.1)
	{ "AbyssBrute", "Horned Bruiser", 26, 18, 300, 300, 1, 1.15, 0.9, 3, 3, 3 },
	{ "HornedRusher", "Horned Charger", 12, 5, 425, 425, 1, 1.1, 0.8, 1, 1, 1 },
	{ "BroodEgg", "Slasher Egg", 5, 3, 0, 0, 1, 0.25, 1, 1, 0, 0 },
	{ "Reaper", "Slasher", 50, 25, 250, 300, 1, 1.15, 0.9, 5, 3, 3 }, -- slasher_stats (1.2.0.1)
	{ "DreadTendril", "Tentacle", 100, 20, 175, 175, 1, 1, 0.7, 4, 2, 2 }, -- tentacle_stats (1.2.0.1)
	{ "Hookfang", "Lamprey", 30, 15, 350, 350, 1, 0.75, 0.95, 1, 1, 1 },
	{ "Gobbler", "Gobbler", 5, 30, 300, 400, 1, 0.85, 0.5, 8, 0, 0 }, -- evil_mob: no consumables (1.2.0.1)
}

describe("main-game wiki enemy stats", function()
	for _, row in fixture do
		it(`matches the {row[2]} reference in original units`, function()
			local kind = Config.Enemies.types[row[1]]
			expect(kind ~= nil).toBe(true)
			expect(kind.hp).toBe(row[3])
			expect(kind.hpPerWave).toBe(row[4])
			expect(kind.speed / Config.Player.moveSpeed * 450).toBeNear(row[5])
			expect((kind.speedMax or kind.speed) / Config.Player.moveSpeed * 450).toBeNear(row[6])
			expect(kind.contactDamage).toBe(row[7])
			expect(kind.damagePerWave).toBe(row[8])
			expect(kind.knockbackResistance).toBe(row[9])
			expect(kind.xp).toBe(row[10])
			expect(kind.loot.consumableChance).toBeNear(row[11] / 100)
			expect(kind.loot.crateShare).toBeNear(row[12] / 100)
			for _, wave in { 1, 2, 11, 20 } do
				local hp, damage = SpawnRules.growth(kind.id, wave)
				expect(hp * kind.hp).toBeNear(row[3] + (wave - 1) * row[4])
				expect(damage * kind.contactDamage).toBeNear(row[7] + (wave - 1) * row[8])
			end
		end)
	end

	it("keeps all normal, champion, boss and Gloom snapshot IDs unique", function()
		local seen = {}
		local count = 0
		for _, list in { Config.Enemies.types, Config.Enemies.champions, Config.Enemies.bosses } do
			for _, kind in list do
				expect(seen[kind.typeId]).toBe(nil)
				seen[kind.typeId] = true
				expect(EnemyKinds.byTypeId(kind.typeId)).toBe(kind)
				count += 1
			end
		end
		expect(count).toBe(44) -- original32, sevenNightmare, fourJungle pursuit bodies and neutralEnigmacursor
		for _, kind in Config.Enemies.types do
			expect(seen[kind.typeId + 128]).toBe(nil)
		end
	end)

	it("grows projectile and slash damage independently from contact damage", function()
		for id, perWave in { Spitter = 0.75, Thornback = 1, Reaper = 1, DreadTendril = 1, Hookfang = 0.75, Skulker = 1 } do
			local kind = Config.Enemies.types[id]
			local _, _, shots = SpawnRules.growth(id, 11)
			expect(EnemyStats.baseShot(kind) * shots).toBeNear(1 + perWave * 10)
		end
	end)

	it("heals 200 flat HP at wave 11, independently of the target's maximum HP", function()
		local sim = Config.Simulation
		local world = World.new({
			cellSize = sim.spatialHashCellSize,
			maxEnemies = 140,
			playerRadius = sim.playerRadius,
			contactMargin = sim.contactMargin,
			separationStiffness = sim.separationStiffness,
			separationPasses = sim.separationPasses,
			obstacleSteerMargin = sim.obstacleSteerMargin,
			keepDistanceTolerance = sim.keepDistanceTolerance,
			minX = -500,
			maxX = 500,
			minZ = -500,
			maxZ = 500,
			obstacles = {},
		})
		local healer = world:spawn(Config.Enemies.types.Mender, 0, 0, 10, 1, nil, 0, 11)
		local target = world:spawn(Config.Enemies.types.Reaper, 4, 0, 1000, 1, nil, 0, 11)
		world:damage(healer, 1)
		world:damage(target, 800)
		for _ = 1, 47 do
			world:step(1 / 15, { 100 }, { 0 }, 1)
		end
		expect(world:getHealth(target)).toBe(400)
		expect(world:getHealth(healer)).toBe(9)
	end)

	it("uses the first waves of Brotato's own wave data for every danger tier", function()
		-- danger 0..5; 99 = never in a spawn group (Reaper only hatches from Brood Eggs). Read from the 1.2.0.1
		-- wave files; on danger 0 Charger comes in wave 6, on danger 1 in wave 3 (the wiki lists only wave 3).
		local expected = {
			Shadeling = { 1, 1, 1, 1, 1, 1 },
			AbyssShadeling = { 2, 2, 2, 2, 2, 2 },
			Charger = { 6, 3, 3, 3, 3, 3 },
			Spitter = { 4, 4, 4, 4, 4, 4 },
			Stalker = { 11, 11, 11, 11, 11, 11 },
			Brute = { 8, 8, 8, 8, 8, 8 },
			Herald = { 16, 16, 16, 16, 16, 16 },
			Thornback = { 99, 4, 3, 3, 3, 3 },
			Mender = { 99, 7, 7, 7, 7, 7 },
			IronHusk = { 13, 10, 10, 10, 10, 4 },
			Splitling = { 15, 9, 9, 9, 9, 9 },
			Splitter = { 14, 14, 14, 14, 14, 14 },
			Skulker = { 14, 14, 14, 14, 14, 14 },
			AbyssBrute = { 13, 8, 8, 8, 8, 8 },
			HornedRusher = { 18, 18, 18, 18, 5, 5 },
			BroodEgg = { 99, 99, 99, 99, 15, 7 },
			Reaper = { 99, 99, 99, 99, 99, 99 },
			DreadTendril = { 99, 15, 15, 13, 13, 13 },
		}
		local function firstWave(id: string, danger: number): number
			for wave = 1, 20 do
				for _, group in SpawnRules.groupsFor(wave, danger) do
					for _, unit in group.units do
						if unit.enemy == id and not group.loot and not group.neutral then
							return wave
						end
					end
				end
			end
			return 99
		end
		for id, firsts in expected do
			for danger = 0, 5 do
				expect(`{id} d{danger}: {firstWave(id, danger)}`).toBe(`{id} d{danger}: {firsts[danger + 1]}`)
			end
		end
	end)

	it("reserves trees, loot encounters and lure enemies for their special groups", function()
		for _, id in { "Tree", "Looter", "Gobbler", "Hookfang" } do
			for wave = 1, 20 do
				for _, group in Config.EnemyWaves.waves[wave].groups do
					for _, unit in group.units do
						expect(unit.enemy == id).toBe(false)
					end
				end
			end
		end
		local gobbler
		for _, group in Config.EnemyWaves.allWaves do
			if group.units[1].enemy == "Gobbler" then
				gobbler = group
			end
		end
		expect(gobbler.timing).toBe(10)
		expect(gobbler.units[1].chance).toBe(0.03)
		expect(gobbler.repeating).toBe(0)
		expect(Config.Effects.lure.minCount).toBe(7)
		expect(Config.Effects.lure.maxCount).toBe(8)
	end)

	it("keeps both bosses and all eight elites on the same reference scale", function()
		local speeds = {
			BrassRam = 250,
			Flayer = 200,
			Abbot = 350,
			MireJaw = 350,
			Monolith = 300,
			SickleWraith = 250,
			BroodMatron = 250,
			StoneSeraph = 350,
		}
		for id, kind in Config.Enemies.champions do
			expect(kind.hp).toBe(1)
			expect(kind.hpPerWave).toBe(if id == "Abbot" then 700 else 750)
			expect(kind.contactDamage).toBe(1)
			expect(kind.damagePerWave).toBe(1.5)
			expect(kind.xp).toBe(10)
			expect(kind.speed / Config.Player.moveSpeed * 450).toBeNear(speeds[id])
		end
		for _, kind in Config.Enemies.bosses do
			-- predator/invoker_stats.tres: 15000 + 750 HP and 1 + 1.5 contact damage per wave after the first
			local hp, damage = SpawnRules.growth(kind.id, 20)
			expect(kind.hp * hp).toBeNear(29250)
			expect(kind.contactDamage * damage).toBeNear(29.5)
			expect(kind.hp * hp * 0.75 * 1.4).toBeNear(30712.5)
		end
		expect(Config.Enemies.bosses.HollowSeer.boss.states[2].hpStart).toBe(0.75)
	end)

	it("uses original player HP and healing without dividing weapon damage by ten", function()
		expect(Config.Player.maxHp).toBe(10)
		expect(Config.Stats.hpScale).toBe(1)
		expect(Config.Stats.maxHpPerLevel).toBe(1)
		expect(Config.Stats.byId.maxHp.upgrade[1]).toBe(3)
		expect(Config.Loot.fruit.heal).toBe(3)
		expect(Config.Loot.crate.heal).toBe(3)
		expect(Config.Loot.legendaryCrate.heal).toBe(100)
		expect(StatMath.regenPerSecond(10)).toBeNear(1)
		expect(Config.Items.byId.Vitality.stats.maxHp).toBe(3)
		expect(Config.Classes.BladeWarden).toBe(nil)
		expect(Config.Run.flow.defaultClassId).toBe("NightWatch")
		expect(Config.Classes.MarbleHost.conversions[1].per).toBe(3)
		expect(Config.Classes.MarbleHost.gainMultipliers.maxHp).toBe(1.25)
		expect(Config.Classes.NightWatch.gainMultipliers.maxHp).toBe(0.75)
		expect(Config.Classes.FarSeer.gainMultipliers.maxHp).toBe(0.67)
		expect(Config.WeaponClasses.byId.Dread.bonuses[2].maxHp).toBe(-20)
		local weapon = WeaponStats.compute(Config.Weapons.WatchmanPistol, 1, {}, nil, Config.Player.minWeaponCooldown)
		expect(weapon.damage).toBe(12)
		local smg = WeaponStats.compute(
			Config.Weapons.RattleRepeater,
			1,
			{ rangedDamage = 10 },
			nil,
			Config.Player.minWeaponCooldown
		)
		expect(smg.damage).toBe(8)
	end)
end)
