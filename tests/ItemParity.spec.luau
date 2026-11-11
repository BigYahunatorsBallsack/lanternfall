--!strict
-- Checks the main-game source facts, item-specific combat rules and server effects without a rendering client.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local StatMath = require(Shared.Util.StatMath)
local UpgradeText = require(Shared.Util.UpgradeText)
local TooltipText = require(Shared.Util.TooltipText)
local Source = loadHelper("tests/fixtures/ItemCatalogSource.luau")
local Server = game:GetService("ServerScriptService").Server
local S = Server.Services
local Weapons = require(S.WeaponService)
local hitListener
local originalSetListener = Weapons.setHitListener
Weapons.setHitListener = function(listener)
	hitListener = listener
	originalSetListener(listener)
end
runScript(Server, "init.server.luau")
local Run = require(S.RunDirector)
local Stats = require(S.StatService)
local Combat = require(S.CombatService)
local Enemy = require(S.EnemySim)
local Spawn = require(S.SpawnDirector)
local Boss = require(S.BossService)
local RandomService = require(S.RandomService)
local Vitals = require(S.CombatService.Vitals)
local WeaponStats = require(S.WeaponService.WeaponStats)
local StructureRules = require(S.StructureService.Rules)
local me = world.addPlayer("Owner", 1, true)
local teammate = world.addPlayer("Teammate", 2, false)
world.advance(0.5)
assert(Run.setReady(me, true))
assert(Run.setReady(teammate, true))
world.advance(3.5)
Run.setHoldWaves(true)
Weapons.setPaused(true)
Spawn.setPaused(true)
Enemy.killAll()

describe("Main-game item catalog", function()
	it("replaces every old entry with one unique original", function()
		expect(#Config.Items.list).toBe(#Source + 5)
		expect(Config.Items.byId.DigSite.available).toBe(false)
		expect(Config.Items.byId.LumberjackShirt.available).toBe(false)
		expect(Config.Items.byId.Ratzilla.available).toBe(false)
		expect(Config.Items.byId.BonkDog.available).toBe(false)
		expect(Config.Items.byId.BotOMine.available).toBe(false)
		local seen = {}
		for _, item in Config.Items.list do
			assert(not seen[item.displayName], item.displayName)
			seen[item.displayName] = true
		end
	end)
	for _, row in Source do
		it(`matches {row.name}: price, tier, limit and every stat`, function()
			local item = assert(Config.Items.byId[row.id])
			expect(item.displayName).toBe(row.name)
			expect(item.price).toBe(row.price)
			expect(item.tier).toBe(row.tier)
			expect(item.limit).toBe(row.limit)
			for id, value in row.stats do
				local scale = if id == "maxHp" or id == "fruitHeal" then Config.Stats.hpScale else 1
				expect(item.stats[id]).toBe(value * scale)
			end
			for id in item.stats do
				assert(row.stats[id] ~= nil, `Unexpected {id} on {row.name}`)
			end
		end)
	end
	it("keeps the six DLC replacements out of the catalog", function()
		local forbidden =
			{ ["Baby Squid"] = true, ["Bone Dice"] = true, Cauldron = true, Coral = true, Goblet = true, Ashes = true }
		for _, item in Config.Items.list do
			assert(not forbidden[item.displayName])
		end
	end)
end)

describe("Original item combat rules", function()
	it("applies Ball and Chain before the separate native structure-speed modifier", function()
		local sheet = { attackSpeed = 1000, weaponCooldownMin = Config.Items.byId.IronShackle.stats.weaponCooldownMin }
		local result = WeaponStats.compute(Config.Weapons.SparkBolt, 4, sheet, nil, Config.Player.minWeaponCooldown)
		expect(result.cooldown).toBe(0.75)
		expect(StructureRules.interval(Config.Structures.kinds.BrassSentry, sheet, true)).toBeNear(7 / 60) -- floor(45/(1+5)) frames
		expect(StructureRules.interval(Config.Structures.kinds.BrassSentry, { weaponCooldownMin = 0.75 }, false)).toBe(
			0.75
		)
		assert(string.find(UpgradeText.itemLines("IronShackle"), "0.75s", 1, true))
	end)
	it("allows 70% dodge only for the Ghost Outfit owner", function()
		assert(Stats.addItem(me, "SmokeMantle"))
		assert(Stats.addStats(me, { dodge = 200 }))
		assert(Stats.addStats(teammate, { dodge = 200 }))
		local roll = RandomService.number
		RandomService.number = function()
			return 0.65
		end
		local _, ownDodge = Combat.damagePlayer(me, 10)
		local _, otherDodge = Combat.damagePlayer(teammate, 10)
		RandomService.number = roll
		expect(ownDodge).toBe(true)
		expect(otherDodge).toBe(false)
		local _, hint = TooltipText.stat("dodge", 200, Stats.getSheet(me))
		assert(string.find(hint, "70%", 1, true))
		expect(StatMath.dodgeChance(200)).toBe(0.6)
	end)
	it("applies lethal self-damage through timed protection and without granting it", function()
		local vitals = Vitals.new(10, { minDamagePerHit = 1, hitInvulnerabilityMin = 0.4, hitInvulnerabilityMax = 0.4 })
		vitals:setDefense(0.01, 1)
		vitals:protect(0, 100)
		vitals.shielded = true -- damage drains do not use the hit-protection path
		expect(vitals:drain(10)).toBe(10)
		expect(vitals:isDown()).toBe(true)
		expect(vitals.invulnerableUntil).toBe(100)
	end)
	it("consumes Tardigrade before self-damage and then permits death", function()
		local vitals = Vitals.new(10, { minDamagePerHit = 1, hitInvulnerabilityMin = 0.4, hitInvulnerabilityMax = 0.4 })
		vitals:setHitShields(1)
		local lost, blocked = vitals:drain(10)
		expect(lost).toBe(0)
		expect(blocked).toBe(true)
		expect(vitals:drain(10)).toBe(10)
	end)
	it("adds Giant Belt from pre-crit HP, without Damage or Silver Bullet modifiers", function()
		assert(Stats.addItem(me, "TitanGirdle"))
		assert(Stats.addStats(me, { damage = 1000, eliteDamage = 1000 }))
		local center = Config.Map.arena.center
		for _, kind in { "Brute", Config.Enemies.eliteWaves.order[1] } do
			local enemy = assert(Enemy.spawn(kind, center.X + 65, center.Z, 100, 0))
			local before = Enemy.getHealth(enemy)
			local _, elite = Enemy.getKind(enemy)
			local killed, dealt = Enemy.damage(enemy, 50, me)
			hitListener(me.UserId, enemy, dealt, true, killed, "Weapon")
			Weapons.setPaused(false)
			world.advance(0.1)
			Weapons.setPaused(true)
			local bonus = math.floor(before * (if elite then 0.01 else 0.1))
			expect(Enemy.getHealth(enemy)).toBe(before - dealt - bonus)
			Enemy.killAll()
		end
	end)
	it("spawns an item champion at the current wave without advancing the elite schedule", function()
		local wave = Run.getWave()
		local previous = Boss.getPendingCount()
		assert(Boss.spawnItemChampion(me))
		expect(Boss.getPendingCount()).toBe(previous + 1)
		expect(Run.getWave()).toBe(wave)
		local effect = Config.Items.byId.SweetReliquary.effects[2]
		expect(effect.action).toBe("SpawnElite")
		expect(effect.chance).toBe(0.1)
	end)
	it("dispatches Candy Bag through the wave event and the authoritative 10% roll", function()
		assert(Stats.addItem(me, "SweetReliquary"))
		local count = 0
		local spawnChampion = Boss.spawnItemChampion
		Boss.spawnItemChampion = function(player)
			expect(player).toBe(me)
			count += 1
			return true
		end
		local random = RandomService.number
		RandomService.number = function(stream, player)
			if stream == "Effects" and player == me then
				return 0.05
			end
			return random(stream, player)
		end
		Run.PhaseChanged:Fire("Running", "Shop")
		expect(count).toBe(1)
		RandomService.number = function(stream, player)
			if stream == "Effects" and player == me then
				return 0.15
			end
			return random(stream, player)
		end
		Run.PhaseChanged:Fire("Running", "Shop")
		expect(count).toBe(1)
		RandomService.number = random
		Boss.spawnItemChampion = spawnChampion
	end)
	it("fires Hurt and downs a player when Bloody Hand self-damage reaches zero HP", function()
		local hurt = 0
		Combat.PlayerDamaged:Connect(function(player, amount)
			if player == me then
				hurt += amount
			end
		end)
		Combat.setHpFraction(me, 0)
		local lost = Combat.drainPlayer(me, Config.Stats.hpScale)
		expect(lost).toBe(1)
		expect(hurt).toBe(1)
		expect(Run.getParticipantState(me)).toBe("Down")
	end)
	it("finishes without new server runtime errors", function()
		expect(#world.errors).toBe(0)
	end)
end)
