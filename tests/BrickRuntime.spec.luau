--!strict
-- Real Brick hit break removes one weapon, spawns physical materials through native modifiers/bag/cap and restores on retry.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Weapons, XP, Enemy =
	require(S.RunDirector), require(S.WeaponService), require(S.ExperienceService), require(S.EnemySim)
local Random = require(S.RandomService)
local me = world.addPlayer("Owner", 1, true)
world.advance(0.5)
Config.Weapons.Brick.available = true
Config.Classes.NightWatch.weaponKind = nil
Run.setHoldWaves(true)
Run.setReady(me, true)
world.advance(3.5)
require(S.SpawnDirector).setPaused(true)
Enemy.killAll()
require(S.CombatService).protect(me, 10000)
require(S.LootService).setDropsPaused(true)
local sold = 0
require(S.ShopService).Sold:Connect(function()
	sold += 1
end)
local original = Random.number
Random.number = function(channel, player)
	return if channel == "Combat" then 0.01 elseif channel == "Loot" then 0.99 else original(channel, player)
end
local function equip(tier)
	for _, w in Weapons.getWeapons(me) do
		Weapons.removeWeapon(me, w.uid)
	end
	assert(Weapons.addWeapon(me, "Brick", tier))
end
local function hit()
	local at = me.Character.HumanoidRootPart.Position
	local victim = assert(Enemy.spawn("Brute", at.X + 6, at.Z, 1000, 0, nil, nil, 0))
	local hp = Enemy.getHealth(victim)
	world.advance(0.08)
	return victim, hp
end
describe("Native Brick break", function()
	it(
		"breaks at the inclusive one-percent boundary, deals its hit and drops10 physical materials without direct payment",
		function()
			equip(1)
			local Shop = require(S.ShopService)
			local before = Shop.getShards(me)
			local victim, hp = hit()
			expect(#Weapons.getWeapons(me)).toBe(0)
			expect(Enemy.getHealth(victim)).toBe(hp - 45)
			expect(XP.getOrbCount()).toBe(10)
			expect(Shop.getShards(me)).toBe(before)
		end
	)
	it("keeps full tierIII/IV material value above the fifty-orb cap and does not fire recycling events", function()
		Enemy.killAll()
		Run.skipTo(require(Shared.Util.RunSchedule).wave(Run.getWave()).endsAt)
		world.advance(0.1)
		world.fireServerAs(me, "SetShopReady", true)
		world.advance(1)
		require(S.SpawnDirector).setPaused(true)
		Enemy.killAll()
		XP.setPaused(false)
		equip(4)
		XP.addToBag(100)
		local bag = XP.getBag()
		-- Existing bag must be emptied to isolate the raw tierIV material count.
		local expected = 200 + bag
		hit()
		expect(#Weapons.getWeapons(me)).toBe(0)
		expect(XP.getOrbCount()).toBe(50)
		expect(XP.getBag()).toBe(bag - 50)
		Run.skipTo(require(Shared.Util.RunSchedule).wave(Run.getWave()).endsAt)
		expect(XP.getBag()).toBe(expected)
		expect(sold).toBe(0)
		expect(#world.errors).toBe(0)
	end)
end)
