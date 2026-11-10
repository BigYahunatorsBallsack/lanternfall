--!strict
-- Physical digging pauses while empty, progresses once for multiple diggers, grants one crate and persists the personal Shovel challenge.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local C = require(Shared.Config.Digging)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Stats, Data = require(S.RunDirector), require(S.StatService), require(S.PlayerDataService)
local Digging, Weapons, Enemy = require(S.DiggingService), require(S.WeaponService), require(S.EnemySim)
local Access = require(Shared.Util.CharacterAccess)
local lastFeed
world.netWatch = function(name, _, rows)
	if name == "DigSites" then
		lastFeed = rows
	end
end
local me, peer = world.addPlayer("Owner", 1, true), world.addPlayer("Peer", 2, false)
world.advance(0.5)
Run.setHoldWaves(true)
assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
require(S.SpawnDirector).setPaused(true)
for _, player in { me, peer } do
	require(S.CombatService).protect(player, 10000)
	for _, weapon in Weapons.getWeapons(player) do
		Weapons.removeWeapon(player, weapon.uid)
	end
	assert(Stats.addItem(player, "DigSite"))
end
local function nextWave()
	Run.skipTo(require(Shared.Util.RunSchedule).wave(Run.getWave()).endsAt)
	world.advance(0.1)
	for _, player in { me, peer } do
		world.fireServerAs(player, "SetShopReady", true)
	end
	world.advance(1)
	require(S.SpawnDirector).setPaused(true)
	Enemy.killAll()
end
local function move(player, site)
	player.Character.HumanoidRootPart.Position = if site
		then Vector3.new(site.x, Config.Map.arena.center.Y, site.z - C.playerBodyOffsetZ)
		else Config.Map.arena.center
end
describe("Native digging runtime", function()
	it("spawns the two equipped item sites on wave three and pauses unoccupied progress", function()
		expect(#Digging.getSnapshot()).toBe(0)
		nextWave()
		expect(#Digging.getSnapshot()).toBe(0)
		nextWave()
		expect(Run.getWave()).toBe(3)
		expect(#Digging.getSnapshot()).toBe(2)
		local first = Digging.getSnapshot()[1]
		move(me, first)
		world.advance(2)
		local progress = Digging.getSnapshot()[1].progress
		assert(progress > 0 and progress < 1)
		move(me, nil)
		world.advance(1)
		expect(Digging.getSnapshot()[1].progress).toBeNear(progress)
	end)
	it("does not multiply digging speed and credits only those digging at completion", function()
		local first = Digging.getSnapshot()[1]
		Data.get(me).nativeCounts.digSitesDug = 8
		move(me, first)
		move(peer, first)
		world.advance(1)
		expect(Digging.getSnapshot()[1].dug).toBe(false)
		world.advance(3.2)
		expect(Digging.getSnapshot()[1].dug).toBe(true)
		expect(lastFeed[1].dug).toBe(true)
		expect(Data.get(me).nativeCounts.digSitesDug).toBe(9)
		expect(Data.get(peer).nativeCounts.digSitesDug).toBe(1)
		expect(Access.weaponUnlocked(Data.get(me), "Shovel")).toBe(false)
		move(peer, nil)
		move(me, Digging.getSnapshot()[2])
		world.advance(6.2)
		expect(Data.get(me).nativeCounts.digSitesDug).toBe(10)
		expect(Data.get(peer).nativeCounts.digSitesDug).toBe(1)
		expect(Access.weaponUnlocked(Data.get(me), "Shovel")).toBe(true)
		expect(Access.weaponUnlocked(Data.get(peer), "Shovel")).toBe(false)
		expect(Data.get(me).achievements[Access.challengeKey(C.challengeId)]).toBe(true)
		world.advance(1)
		expect(Data.get(me).nativeCounts.digSitesDug).toBe(10)
	end)
	it("clears scenes on the next wave while retaining lifetime credit", function()
		nextWave()
		expect(#Digging.getSnapshot()).toBe(0)
		expect(Data.get(me).nativeCounts.digSitesDug).toBe(10)
		expect(#world.errors).toBe(0)
	end)
	it("locks the item until its personal Archaeologist win without exposing missing artwork", function()
		expect(Data.lockedSet(peer, "items").DigSite).toBe(true)
		Data.get(peer).characterStats.Archaeologist = { wins = 1 }
		expect(Data.lockedSet(peer, "items").DigSite).toBe(nil)
		expect(Data.lockedSet(me, "items").DigSite).toBe(true)
		expect(Config.Items.byId.DigSite.available).toBe(false)
	end)
end)
