--!strict
-- Pacifist selection, mandatory shirt, zero-damage tree hits and personal material-object progression.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Stats, Weapons = require(S.RunDirector), require(S.StatService), require(S.WeaponService)
local Enemy, Data, XP = require(S.EnemySim), require(S.PlayerDataService), require(S.ExperienceService)
local Access = require(Shared.Util.CharacterAccess)
local me, peer = world.addPlayer("Owner", 1, true), world.addPlayer("Peer", 2, false)
world.advance(0.5)
XP.setPaused(true)
local originalAvailability = Config.Classes.Pacifist.available
Config.Classes.Pacifist.available = true
Run.setHoldWaves(true)
local function start(weapon)
	if Run.isOngoing() then
		Run.endRun("Abandoned")
	end
	if Run.getPhase() == "Ended" then
		world.advance(Config.Run.flow.resultsSeconds + 0.1)
	end
	assert(Run.selectClass(me, "Pacifist"))
	assert(Weapons.selectStartWeapon(me, "Pacifist", weapon))
	assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
	require(S.SpawnDirector).setPaused(true)
	require(S.LootService).setDropsPaused(true)
	Enemy.killAll()
	require(S.CombatService).protect(me, 10000)
	require(S.CombatService).protect(peer, 10000)
	peer.Character.HumanoidRootPart.Position = Vector3.new(200, 0, 200)
end
local function near(kind, hp)
	local at = me.Character.HumanoidRootPart.Position
	return assert(Enemy.spawn(kind, at.X + 3, at.Z, hp or 100, 1, nil, nil, 0))
end
describe("Native Pacifist package", function()
	it("keeps selection locked until 10000 collected objects and preserves the original art gate", function()
		expect(Config.Classes.Pacifist.nativeCodeReady).toBe(true)
		expect(originalAvailability).toBe(false)
		expect(Run.selectClass(me, "Pacifist")).toBe(false)
		Data.get(me).nativeCounts.materialsCollected = 9999
		-- Pickup effects count physical objects, not rotated money or the orb's doubled value.
		XP.OrbsCollected:Fire(me, 100)
		expect(Access.characterUnlocked(Data.get(me), "Pacifist")).toBe(false)
		XP.OrbsPickedUp:Fire(me, 1)
		expect(Access.characterUnlocked(Data.get(me), "Pacifist")).toBe(true)
		expect(Access.characterUnlocked(Data.get(peer), "Pacifist")).toBe(false)
		expect(Data.get(me).nativeCounts.materialsCollected).toBe(10000)
	end)
	it(
		"starts every original weapon with exactly one mandatory shirt and destroys trees despite -100 Damage",
		function()
			for _, weapon in { "TithePalm", "GalvanicFork", "ThornTrail" } do
				start(weapon)
				expect(Weapons.getWeapons(me)[1].id).toBe(weapon)
				expect(Stats.getStat(me, "damage")).toBe(-100)
				expect(Stats.getStat(me, "engineering")).toBe(-100)
				expect(Stats.getItemCounts(me).LumberjackShirt).toBe(1)
				expect(Stats.getItemCounts(peer).LumberjackShirt).toBe(nil)
				local tree, enemy = near("Tree", 10000), near("Brute", 10000)
				local hp = Enemy.getHealth(enemy)
				expect(Weapons.getWeapons(me)[1].stats.damage).toBe(1)
				world.advance(2)
				expect(Enemy.isAlive(tree)).toBe(false)
				expect(Enemy.getHealth(enemy) > 0 and Enemy.getHealth(enemy) < hp).toBe(true)
			end
		end
	)
	it("limits tree execution to the shirt owner and retains actual damage accounting", function()
		Enemy.killAll()
		local tree = near("Tree", 10000)
		local killed, dealt = Enemy.damage(tree, 1, peer)
		expect(killed).toBe(false)
		expect(dealt).toBe(1)
		expect(Enemy.damage(tree, 0, me)).toBe(false) -- stat strikes have no native hitbox
		killed, dealt = Enemy.damage(tree, 0, me, nil, true)
		expect(killed).toBe(true)
		expect(dealt).toBe(0)
		local ordinary = near("Brute", 10000)
		local hp = Enemy.getHealth(ordinary)
		expect(Enemy.damage(ordinary, 0, me)).toBe(false)
		expect(Enemy.getHealth(ordinary)).toBe(hp)
	end)
	it("counts actual doubled pickups once for their collector and keeps the cumulative count across runs", function()
		XP.setPaused(false)
		assert(Stats.addStats(me, { doubleShards = 100 }))
		local shop = require(S.ShopService)
		local money = shop.getShards(me) + shop.getShards(peer)
		local before = Data.get(me).nativeCounts.materialsCollected
		local theirs = Data.get(peer).nativeCounts.materialsCollected
		local at = me.Character.HumanoidRootPart.Position
		local id = assert(Enemy.spawn("Shadeling", at.X, at.Z, 1, 1, nil, nil, 0))
		Enemy.damage(id, math.huge, peer)
		world.advance(0.3)
		expect(Data.get(me).nativeCounts.materialsCollected).toBe(before + 1)
		-- two players: the orb is worth 1 * (1 + 43 % co-op materials), so 1 or 2, doubled by doubleShards
		local gained = shop.getShards(me) + shop.getShards(peer) - money
		local xp = Config.Enemies.types.Shadeling.xp
		expect(gained == 2 * xp or gained == 4 * xp).toBe(true)
		expect(Data.get(peer).nativeCounts.materialsCollected).toBe(theirs)
		start("TithePalm")
		expect(Data.get(me).nativeCounts.materialsCollected).toBe(before + 1)
		expect(Stats.getItemCounts(me).LumberjackShirt).toBe(1)
		expect(#world.errors).toBe(0)
	end)
	it("keeps lifetime pickups through retry and clears the Shirt when a different class starts", function()
		local before = Data.get(me).nativeCounts.materialsCollected
		Run.endRun("Defeat")
		assert(Run.retryWave(me))
		expect(Data.get(me).nativeCounts.materialsCollected).toBe(before)
		expect(Stats.getItemCounts(me).LumberjackShirt).toBe(1)
		Run.endRun("Abandoned")
		world.advance(Config.Run.flow.resultsSeconds + 0.1)
		assert(Run.selectClass(me, "NightWatch"))
		assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		Enemy.killAll()
		expect(Stats.getItemCounts(me).LumberjackShirt).toBe(nil)
		local tree = near("Tree", 10000)
		expect(Enemy.damage(tree, 1, me, nil, true)).toBe(false)
		expect(Data.get(me).nativeCounts.materialsCollected).toBe(before)
	end)
	it("persists the cumulative count and unlock through a saved profile reload", function()
		Run.endRun("Abandoned")
		local before = Data.get(me).nativeCounts.materialsCollected
		world.removePlayer(me)
		world.advance(0.1)
		local rejoined = world.addPlayer("Owner", 1, true)
		world.advance(0.5)
		expect(Data.get(rejoined).nativeCounts.materialsCollected).toBe(before)
		expect(Access.characterUnlocked(Data.get(rejoined), "Pacifist")).toBe(true)
	end)
end)
