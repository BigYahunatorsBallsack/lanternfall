--!strict
-- Real material drops, Farmer growth, Entrepreneur recycling and wave-start reset/retry isolation.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
Config.Classes.Farmer.available = true
Config.Classes.Entrepreneur.available = true
local S = Server.Services
local Run = require(S.RunDirector)
local Stats = require(S.StatService)
local Shop = require(S.ShopService)
local XP = require(S.ExperienceService)
local Enemy = require(S.EnemySim)
local Weapons = require(S.WeaponService)
local Random = require(S.RandomService)
local Schedule = require(Shared.Util.RunSchedule)
local ShopRules = require(S.ShopService.ShopRules)
local me = world.addPlayer("Farmer", 1, true)
local peer = world.addPlayer("Entrepreneur", 2, false)
world.advance(0.5)
for _, player in { me, peer } do
	require(S.PlayerDataService).unlockAll(player)
end
assert(Run.selectClass(me, "Farmer"))
assert(Run.selectClass(peer, "Entrepreneur"))
require(S.SpawnDirector).setPaused(true)
Weapons.setPaused(true)
require(S.LootService).setDropsPaused(true)
Run.setHoldWaves(true)
Run.setReady(me, true)
Run.setReady(peer, true)
world.advance(3.5)
Enemy.killAll()
local function finishWave()
	Run.skipTo(Schedule.wave(Run.getWave()).endsAt)
	expect(Run.getPhase()).toBe("Shop")
end
local function nextWave()
	world.fireServerAs(me, "SetShopReady", true)
	world.fireServerAs(peer, "SetShopReady", true)
	world.advance(0.2)
	expect(Run.getPhase()).toBe("Running")
end
describe("Native character economy in services", function()
	it("applies averaged Farmer material reduction before orb allocation, without changing the collector", function()
		local original = Random.number
		local ok, err = pcall(function()
			for _, roll in { 0.9, 0.1 } do
				Random.number = function(channel, player)
					if channel == "Loot" then
						return roll
					end
					return original(channel, player)
				end
				local id = assert(Enemy.spawn("Shadeling", 40, 40, 1, 1))
				Enemy.damage(id, 1000, peer)
				-- 2 players: 1 * (1 + co-op 43 %) * (1 - 25 % averaged Farmer) = 1.08, so every kill drops an orb now
				expect(XP.getOrbCount()).toBe(if roll == 0.9 then 1 else 2)
			end
		end)
		Random.number = original
		assert(ok, err)
	end)
	it(
		"pays Farmer harvesting before growing it by eight percent and keeps the peer's gain multiplier personal",
		function()
			XP.setPaused(true)
			Stats.addStats(me, { harvesting = 101 - Stats.getStat(me, "harvesting") })
			Stats.addStats(peer, { harvesting = -Stats.getStat(peer, "harvesting") / 1.5 })
			Shop.addShards(me, 1000)
			Shop.addShards(peer, 1000)
			finishWave()
			expect(Shop.getShards(me)).toBe(1101 + Config.Shop.startShards)
			expect(Stats.getStat(me, "harvesting")).toBe(110)
			expect(Shop.getShards(peer)).toBe(1000)
			expect(Stats.getStat(peer, "harvesting")).toBe(0)
		end
	)
	it("recycles Entrepreneur weapons at the native fifty-percent share of the discounted price", function()
		assert(Weapons.addWeapon(peer, "RitualDirk"))
		local weapon = Weapons.getWeapons(peer)[1]
		local discounted = ShopRules.weaponPrice(weapon.id, weapon.tier, Run.getWave(), 0.75)
		local before = Shop.getShards(peer)
		world.fireServerAs(peer, "SellWeapon", weapon.uid)
		expect(Shop.getShards(peer)).toBe(before + math.floor(discounted * 0.5))
		expect(#Weapons.getWeapons(peer)).toBe(1)
	end)
	it("resets only Entrepreneur at the next actual wave start and saves the reset wallet for retry", function()
		local farmerGold = Shop.getShards(me)
		nextWave()
		expect(Shop.getShards(me)).toBe(farmerGold)
		expect(Shop.getShards(peer)).toBe(0)
		Shop.addShards(peer, 123)
		Run.setParticipantState(me, "Down")
		Run.setParticipantState(peer, "Down")
		world.advance(0.1)
		expect(Run.getPhase()).toBe("Ended")
		assert(Run.retryWave(peer))
		expect(Shop.getShards(peer)).toBe(0)
		expect(Shop.getShards(me)).toBe(farmerGold)
		expect(#world.errors).toBe(0)
	end)
end)
