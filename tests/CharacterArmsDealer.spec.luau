--!strict
-- Arms Dealer's real selection, recycling unlock, shop-only destruction, personal prices, stock and retry.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Stats, Weapons = require(S.RunDirector), require(S.StatService), require(S.WeaponService)
local Shop, Data, Enemy = require(S.ShopService), require(S.PlayerDataService), require(S.EnemySim)
local Schedule = require(Shared.Util.RunSchedule)
local Rules = require(S.ShopService.ShopRules)
local me, peer = world.addPlayer("Owner", 1, true), world.addPlayer("Peer", 2, false)
world.advance(0.5)
local originalAvailability = Config.Classes.ArmsDealer.available
Config.Classes.ArmsDealer.available = true
Run.setHoldWaves(true)
require(S.SpawnDirector).setPaused(true)
require(S.ExperienceService).setPaused(true)
Weapons.setPaused(true)
local shops = {}
world.getRemote("ShopState").OnClientEvent:Connect(function(state)
	shops[world.localPlayer or me] = state
end)
local function snapshot(player)
	return assert(shops[player])
end
local function launch(class)
	if Run.isOngoing() then
		Run.endRun("Abandoned")
	end
	if Run.getPhase() == "Ended" then
		world.advance(Config.Run.flow.resultsSeconds + 0.1)
	end
	if class then
		assert(Run.selectClass(me, class))
	end
	assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
	Enemy.killAll()
	for _, p in { me, peer } do
		require(S.CombatService).protect(p, 10000)
	end
end
local function endWave()
	Run.skipTo(Schedule.wave(Run.getWave()).endsAt)
	expect(Run.getPhase()).toBe("Shop")
end
local function sellOne(player)
	world.advance(0.3) -- actual remote rate limit remains active
	assert(Weapons.addWeapon(player, "WatchmanPistol", 1))
	local list = Weapons.getWeapons(player)
	local uid = list[#list].uid
	world.fireServerAs(player, "SellWeapon", uid)
	expect(#Weapons.getWeapons(player)).toBe(#list - 1)
	return uid
end
describe("Native Arms Dealer package", function()
	it("requires twelve actual sales in one run and isolates players, merges and failed requests", function()
		expect(Config.Classes.ArmsDealer.nativeCodeReady).toBe(true)
		expect(originalAvailability).toBe(false)
		expect(Run.selectClass(me, "ArmsDealer")).toBe(false)
		launch("NightWatch")
		endWave()
		local beforeMerge = #Weapons.getWeapons(me)
		world.fireServerAs(me, "MergeWeapons", Weapons.getWeapons(me)[1].uid)
		expect(#Weapons.getWeapons(me)).toBe(beforeMerge - 1)
		for _ = 1, 11 do
			sellOne(me)
		end
		expect(Data.isUnlocked(me, "characters", "ArmsDealer")).toBe(false)
		world.fireServerAs(me, "SellWeapon", 999999)
		expect(Data.isUnlocked(me, "characters", "ArmsDealer")).toBe(false)
		sellOne(me)
		expect(Data.isUnlocked(me, "characters", "ArmsDealer")).toBe(true)
		expect(Data.isUnlocked(peer, "characters", "ArmsDealer")).toBe(false)
	end)
	it("starts with Pistol, Dangerous Bunny, Harvesting and all native damage gain modifiers", function()
		launch("ArmsDealer")
		expect(#Weapons.getWeapons(me)).toBe(1)
		expect(Weapons.getWeapons(me)[1].id).toBe("WatchmanPistol")
		expect(Stats.getItemCounts(me).JesterBell).toBe(1)
		expect(Stats.getStat(me, "harvesting")).toBe(30)
		assert(Stats.addStats(me, {
			damage = 10,
			meleeDamage = 10,
			rangedDamage = 10,
			elementalDamage = 10,
			explosionDamage = 10,
			piercingDamage = 10,
			bounceDamage = 10,
			eliteDamage = 10,
		}))
		for _, stat in
			{
				"damage",
				"meleeDamage",
				"rangedDamage",
				"elementalDamage",
				"explosionDamage",
				"piercingDamage",
				"bounceDamage",
				"eliteDamage",
			}
		do
			expect(Stats.getStat(me, stat)).toBeNear(13.3)
		end
		expect(Stats.getStat(peer, "damage")).toBe(0)
	end)
	it("destroys only the owner's weapons at shop entry without recycling credit or payment", function()
		local peerCount = #Weapons.getWeapons(peer)
		endWave()
		expect(#Weapons.getWeapons(me)).toBe(0)
		expect(#Weapons.getWeapons(peer)).toBe(peerCount)
		expect(Shop.getShards(me)).toBe(30)
		for _, offer in Shop.getOffers(peer) do
			if offer.kind == "Weapon" then
				expect(offer.price).toBe(Rules.weaponPrice(offer.itemId, offer.tier, 1, 1))
			end
		end
		local state = snapshot(me)
		expect(state.freeRerolls).toBe(1)
		for _, offer in state.offers do
			if offer.kind == "Weapon" then
				expect(offer.price).toBe(Rules.weaponPrice(offer.itemId, offer.tier, 1, 1, "ArmsDealer"))
			end
		end
	end)
	it("buys and recycles the last weapon at its personal price without destroying new purchases on refresh", function()
		local state = snapshot(me)
		local offer
		for _, v in state.offers do
			if v.kind == "Weapon" then
				offer = v
				break
			end
		end
		local gold = Shop.getShards(me)
		world.fireServerAs(me, "BuyShopOffer", offer.id)
		expect(#Weapons.getWeapons(me)).toBe(1)
		expect(Shop.getShards(me)).toBe(gold - offer.price)
		Data.refresh(me)
		world.fireServerAs(me, "RequestSync")
		expect(#Weapons.getWeapons(me)).toBe(1)
		world.fireServerAs(me, "RerollShop")
		expect(snapshot(me).freeRerolls).toBe(0)
		expect(#Weapons.getWeapons(me)).toBe(1)
		local weapon = Weapons.getWeapons(me)[1]
		local beforeSale = Shop.getShards(me)
		local expectedSale = Rules.sellPrice(weapon.id, weapon.tier, 1, 0, 1, "ArmsDealer")
		world.fireServerAs(me, "SellWeapon", weapon.uid)
		expect(#Weapons.getWeapons(me)).toBe(0)
		expect(Shop.getShards(me)).toBe(beforeSale + expectedSale)
	end)
	it("keeps a purchased weapon through wave start and retry, then destroys it at the next actual shop", function()
		assert(Weapons.addWeapon(me, "WatchmanPistol", 1))
		world.fireServerAs(me, "SetShopReady", true)
		world.fireServerAs(peer, "SetShopReady", true)
		world.advance(0.2)
		expect(Run.getPhase()).toBe("Running")
		expect(#Weapons.getWeapons(me)).toBe(1)
		Run.endRun("Defeat")
		assert(Run.retryWave(me))
		expect(#Weapons.getWeapons(me)).toBe(1)
		expect(Data.isUnlocked(me, "characters", "ArmsDealer")).toBe(true)
		endWave()
		expect(#Weapons.getWeapons(me)).toBe(0)
	end)
	it("resets the unearned recycling count between runs", function()
		for _ = 1, 11 do
			sellOne(peer)
		end
		expect(Data.isUnlocked(peer, "characters", "ArmsDealer")).toBe(false)
		launch("NightWatch")
		endWave()
		sellOne(peer)
		expect(Data.isUnlocked(peer, "characters", "ArmsDealer")).toBe(false)
		expect(#world.errors).toBe(0)
	end)
	it("does not count forced destruction toward the recycling challenge", function()
		Run.endRun("Abandoned")
		world.advance(Config.Run.flow.resultsSeconds + 0.1)
		table.insert(Data.get(peer).classes, "ArmsDealer") -- trusted fixture grant without earning the challenge
		assert(Run.selectClass(peer, "ArmsDealer"))
		launch("NightWatch")
		endWave()
		expect(#Weapons.getWeapons(peer)).toBe(0)
		for _ = 1, 11 do
			sellOne(peer)
		end
		local key = require(Shared.Util.CharacterAccess).challengeKey("chal_recycling")
		expect(Data.get(peer).achievements[key]).toBe(nil)
		sellOne(peer)
		expect(Data.get(peer).achievements[key]).toBe(true)
	end)
end)
