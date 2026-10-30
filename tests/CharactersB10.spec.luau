--!strict
-- B10 integration: untouched catalog, real server/client bootstraps, every character and hostile intents.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local Services = Server.Services
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Rules = require(Shared.Util.CharacterRules)
local Run = require(Services.RunDirector)
local Stats = require(Services.StatService)
local Weapons = require(Services.WeaponService)
local Shop = require(Services.ShopService)
local ShopRules = require(Services.ShopService.ShopRules)
local Experience = require(Services.ExperienceService)
local Combat = require(Services.CombatService)
local Spawn = require(Services.SpawnDirector)
local Check = require(Server.ConfigCheck)
local me = world.addPlayer("Owner", 1, true)
local peer = world.addPlayer("Peer", 2, false)
world.step()
runScript(folderProxy("src/client", "Client"), "init.client.luau")
world.advance(0.5)
Spawn.setPaused(true)
Run.setHoldWaves(true)

local function intent(player, name, ...)
	world.fireServerAs(player, name, ...)
	world.advance(0.3)
end

local function start(classId, weaponId)
	if Run.isOngoing() then
		Run.endRun("Defeat")
	end
	if Run.getPhase() == "Ended" then
		world.advance(Config.Run.flow.resultsSeconds + 0.1)
	end
	intent(me, "SelectClass", classId)
	intent(me, "SelectStartWeapon", classId, weaponId or Config.Classes[classId].startWeapon)
	intent(me, "SetReady", true)
	intent(peer, "SetReady", true)
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.1)
	expect(Run.getPhase()).toBe("Running")
	Weapons.setPaused(true)
	Combat.protect(me, 100)
	Combat.protect(peer, 100)
end

local function clearWeapons()
	for _, weapon in Weapons.getWeapons(me) do
		assert(Weapons.removeWeapon(me, weapon.uid))
	end
end

local function give(id)
	local ok, reason, uid = Weapons.addWeapon(me, id)
	assert(ok, reason)
	return uid
end

describe("B10 character catalog", function()
	it("validates all ten packages and real client UI", function()
		expect(#Check.run()).toBe(0)
		local count = 0
		for id, class in Config.Classes do
			if class.available then
				count += 1
				assert(world.gui("Lobby", id))
				for _, weaponId in class.startWeapons do
					expect(Rules.weaponAllowed(id, weaponId)).toBe(true)
				end
			end
		end
		expect(count).toBe(10)
	end)

	it("uses an acknowledged weapon selection and refuses forged choices", function()
		intent(me, "SelectClass", "BladeWarden")
		world.click(world.gui("Lobby", "Start_RitualDirk"))
		world.advance(0.4)
		expect(world.gui("Lobby", "Start_RitualDirk").BackgroundColor3).toBe(
			require(folderProxy("src/client", "Client").UI.Theme).accent
		)
		intent(me, "SelectStartWeapon", "BladeWarden", "CathedralEngine") -- known but not a starting choice
		intent(me, "SelectStartWeapon", "NightWatch", "RattleRepeater") -- wrong character
		intent(me, "SetReady", true)
		intent(peer, "SetReady", true)
		world.advance(3.2)
		Weapons.setPaused(true)
		expect(Weapons.getWeapons(me)[1].id).toBe("RitualDirk")
		expect(Stats.getStat(me, "maxHp")).toBe(150)
		expect(Stats.getStat(me, "speed")).toBe(5)
		expect(Stats.getStat(me, "harvesting")).toBe(8)
		intent(me, "SelectClass", "SoleConductor")
		intent(me, "SelectStartWeapon", "BladeWarden", "Gravestone")
		expect(Run.getParticipantClassId(me)).toBe("BladeWarden")
		expect(Weapons.getWeapons(me)[1].id).toBe("RitualDirk")
	end)

	it("starts Mage items once and scales item/card/dynamic gains", function()
		start("SparkMage", "WinterNeedle")
		expect(Stats.getItemCounts(me).AshSerpent).toBe(1)
		expect(Stats.getItemCounts(me).SmolderingWick).toBe(1)
		expect(Stats.getStat(me, "maxHp")).toBe(90)
		Stats.addStats(me, { elementalDamage = 4, meleeDamage = 20, rangedDamage = 20, engineering = 4 })
		expect(Stats.getStat(me, "elementalDamage")).toBe(5)
		expect(Stats.getStat(me, "meleeDamage")).toBe(0)
		expect(Stats.getStat(me, "rangedDamage")).toBe(0)
		expect(Stats.getStat(me, "engineering")).toBe(2)
		Stats.setDynamic(me, { elementalDamage = 4, rangedDamage = 10 })
		expect(Stats.getStat(me, "elementalDamage")).toBe(10)
		expect(Stats.getStat(me, "rangedDamage")).toBe(0)
		expect(Stats.getStat(peer, "elementalDamage")).toBe(0)
		start("SparkMage")
		expect(Stats.getItemCounts(me).AshSerpent).toBe(1)
		expect(Stats.getStat(me, "elementalDamage")).toBe(0)
	end)

	it("gives Ranger an extra pistol and forbids melee through service and shop", function()
		start("NightWatch", "ScatterBell")
		expect(#Weapons.getWeapons(me)).toBe(2)
		expect(Weapons.getWeapons(me)[2].id).toBe("WatchmanPistol")
		expect(Weapons.addWeapon(me, "RitualDirk")).toBe(false)
		Stats.addStats(me, { rangedDamage = 4, maxHp = 40 })
		expect(Stats.getStat(me, "rangedDamage")).toBe(6)
		expect(Stats.getStat(me, "maxHp")).toBe(130)
		Run.skipTo(20)
		world.advance(0.1)
		for _, offer in Shop.getOffers(me) do
			if offer.kind == "Weapon" then
				expect(Config.Weapons[offer.itemId].kind).toBe("Ranged")
			end
		end
	end)

	it("enforces twelve slots and updates damage after adding, merging and selling", function()
		start("ManyHands")
		clearWeapons()
		local first = give("WatchmanPistol")
		for _ = 2, 12 do
			give("WatchmanPistol")
		end
		expect(#Weapons.getWeapons(me)).toBe(12)
		expect(Stats.getStat(me, "damage")).toBe(-40)
		expect(Weapons.addWeapon(me, "WatchmanPistol")).toBe(false)
		expect(Weapons.merge(me, first)).toBe(true)
		expect(Stats.getStat(me, "damage")).toBe(-35)
		Weapons.removeWeapon(me, first)
		expect(Stats.getStat(me, "damage")).toBe(-30)
		expect(Weapons.getMaxWeapons(peer)).toBe(6)
	end)

	it("lets a full one-slot character buy a matching tier instead of a second weapon", function()
		start("SoleConductor", "RattleRepeater")
		expect(Stats.getStat(me, "attackSpeed")).toBe(200)
		Stats.addStats(me, { damage = 5 })
		expect(Stats.getStat(me, "damage")).toBe(10)
		expect(Weapons.addWeapon(me, "RitualDirk")).toBe(false)
		local merges, blocked =
			ShopRules.weaponStatus("RattleRepeater", 1, Weapons.getWeapons(me), 1, 4, "SoleConductor")
		expect(merges).toBe(true)
		expect(blocked).toBe(false)
		Run.skipTo(20)
		world.advance(0.1)
		Shop.addShards(me, 10000)
		local offer = Shop.getOffers(me)[1]
		-- The shop owns the offer; force only its random outcome to test the real purchase path.
		offer.kind, offer.itemId, offer.tier = "Weapon", "RattleRepeater", 1
		Shop.addShards(me, 0) -- recompute price and blocked/merge status of the controlled offer
		intent(me, "BuyShopOffer", offer.id)
		expect(#Weapons.getWeapons(me)).toBe(1)
		expect(Weapons.getWeapons(me)[1].tier).toBe(2)
	end)

	it("counts different Gladiator weapons, not copies", function()
		start("DuelMaestro")
		expect(Stats.getStat(me, "attackSpeed")).toBe(-20)
		give("RitualDirk")
		expect(Stats.getStat(me, "attackSpeed")).toBe(-20)
		give("BrassKnuckles")
		expect(Stats.getStat(me, "attackSpeed")).toBe(0)
		expect(Weapons.addWeapon(me, "WatchmanPistol")).toBe(false)
	end)

	it("converts Hunter range including dynamic gains without accumulating", function()
		start("FarSeer")
		expect(Stats.getStat(me, "damage")).toBe(10)
		Stats.addStats(me, { range = 20, harvesting = 20, critChance = 4 })
		expect(Stats.getStat(me, "damage")).toBe(12)
		expect(Stats.getStat(me, "harvesting")).toBe(0)
		expect(Stats.getStat(me, "critChance")).toBe(5)
		for _ = 1, 3 do
			Stats.setDynamic(me, { range = 30 })
		end
		expect(Stats.getStat(me, "damage")).toBe(15)
		Stats.setDynamic(me, {})
		expect(Stats.getStat(me, "damage")).toBe(12)
	end)

	it("converts Chunky HP in x10 units and blocks speed modifications", function()
		start("MarbleHost", "ScatterBell")
		expect(Stats.getStat(me, "damage")).toBe(3)
		Stats.addStats(me, { maxHp = 40, speed = 20, dodge = 10, hpRegen = 4 })
		expect(Stats.getStat(me, "maxHp")).toBe(150)
		expect(Stats.getStat(me, "damage")).toBe(5)
		expect(Stats.getStat(me, "speed")).toBe(0)
		expect(Stats.getStat(me, "dodge")).toBe(5)
		expect(Stats.getStat(me, "hpRegen")).toBe(2)
		expect(Stats.getStat(me, "fruitHeal")).toBe(30)
		Stats.setDynamic(me, { maxHp = 40 })
		expect(Stats.getStat(me, "maxHp")).toBe(200)
		expect(Stats.getStat(me, "damage")).toBe(5) -- temporary HP does not feed Chunky's conversion
	end)

	it("enforces independent Generalist slots and simultaneous conversions", function()
		start("TwinLedger")
		clearWeapons()
		give("RitualDirk")
		give("RitualDirk")
		give("RitualDirk")
		expect(Weapons.addWeapon(me, "BrassKnuckles")).toBe(false)
		give("WatchmanPistol")
		give("WatchmanPistol")
		give("WatchmanPistol")
		expect(#Weapons.getWeapons(me)).toBe(6)
		clearWeapons() -- remove weapon-class bonuses before testing the conversion math
		Stats.addStats(me, { meleeDamage = 6, rangedDamage = 2 })
		expect(Stats.getStat(me, "meleeDamage")).toBe(10)
		expect(Stats.getStat(me, "rangedDamage")).toBe(5)
		Stats.setDynamic(me, { meleeDamage = 2 })
		expect(Stats.getStat(me, "meleeDamage")).toBe(12)
		expect(Stats.getStat(me, "rangedDamage")).toBe(6)
	end)

	it("applies Apprentice gains to team levels and resets everything in the next run", function()
		start("CandleScholar", "RattleRepeater")
		Experience.grantLevel()
		expect(Stats.getStat(me, "meleeDamage")).toBe(2)
		expect(Stats.getStat(me, "rangedDamage")).toBe(1)
		expect(Stats.getStat(me, "elementalDamage")).toBe(1)
		expect(Stats.getStat(me, "engineering")).toBe(1)
		expect(Stats.getStat(me, "maxHp")).toBe(90)
		expect(Stats.getStat(peer, "maxHp")).toBe(160)
		start("BladeWarden")
		expect(Stats.getStat(me, "maxHp")).toBe(150)
		expect(Stats.getStat(me, "meleeDamage")).toBe(0)
		expect(next(Stats.getItemCounts(me))).toBe(nil)
		expect(#world.errors).toBe(0)
	end)

	it("keeps tag draws within the rolled rarity and falls back to the normal pool", function()
		local function offers(tagRoll)
			local n = 0
			return ShopRules.roll({
				classId = "NightWatch",
				wave = 10,
				luck = 0,
				weapons = {},
				ownedWeapons = {},
				ownedItems = {},
				maxWeapons = 6,
				maxTier = 4,
				nextId = function()
					return "test"
				end,
				random = function()
					n += 1
					if n == 4 then
						return tagRoll
					end
					if n == 5 then
						return 0
					end
					return 0.99
				end,
			})
		end
		local tagged = offers(0.049)[1]
		expect(tagged.tier).toBe(1)
		local tags = Config.Items.byId[tagged.itemId].tags
		expect(table.find(tags, "rangedDamage") ~= nil or table.find(tags, "range") ~= nil).toBe(true)
		local ordinary = offers(0.05)[1]
		expect(ordinary.itemId == tagged.itemId).toBe(false)
		expect(ShopRules.pickItem(1, {}, {}, function()
			return 0
		end, { "explosionSize" })).toBe(nil)
	end)

	it("filters wished tags with limit/duplicate exclusions and falls back when absent", function()
		local id = ShopRules.pickItem(1, {}, {}, function()
			return 0
		end, { "rangedDamage" })
		assert(id)
		expect(table.find(Config.Items.byId[id].tags, "rangedDamage") ~= nil).toBe(true)
		expect(ShopRules.pickItem(1, {}, {}, function()
			return 0
		end, { "no-such-tag" })).toBe(nil)
		expect(Config.Shop.wantedTagChance).toBe(0.05)
	end)
end)
