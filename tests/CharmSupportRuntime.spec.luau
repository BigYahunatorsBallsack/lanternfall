--!strict
-- Native allied Healer entry events and Buffer boosts run through actual character, stat and structure services.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Stats, Weapons = require(S.RunDirector), require(S.StatService), require(S.WeaponService)
local Enemy, Combat, Structures = require(S.EnemySim), require(S.CombatService), require(S.StructureService)
local me, peer = world.addPlayer("Owner", 1, true), world.addPlayer("Peer", 2, false)
world.advance(0.5)
Config.Classes.Crazy.available = true
require(S.PlayerDataService).unlockAll(me)
Run.setHoldWaves(true)
assert(Run.selectClass(me, "Crazy"))
assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
require(S.SpawnDirector).setPaused(true)
require(S.ExperienceService).setPaused(true)
Weapons.setPaused(true)
for _, p in { me, peer } do
	for _, weapon in Weapons.getWeapons(p) do
		Weapons.removeWeapon(p, weapon.uid)
	end
	Combat.protect(p, 10000)
end
Enemy.killAll()
peer.Character.HumanoidRootPart.Position = Vector3.new(90, 0, 60)
local function charm(kind, at)
	local id = assert(Enemy.spawn(kind, at.X, at.Z, 100, 0, nil, nil, 0, Run.getWave()))
	Enemy.damage(id, Enemy.getHealth(id) * 0.9, nil)
	assert(Enemy.tryCharm(me, id, { charmChance = 1, charmThreshold = 1 }, function()
		return 0
	end))
	return id
end
describe("Charmed native support actors", function()
	it("heals on entering the Healer area, not every tick while staying inside", function()
		local at = me.Character.HumanoidRootPart.Position
		Combat.drainPlayer(me, 4)
		charm("Mender", at + Vector3.new(2, 0, 0))
		world.advance(0.2)
		expect(Combat.getHp(me)).toBe(7)
		Combat.drainPlayer(me, 1)
		world.advance(0.5)
		expect(Combat.getHp(me)).toBe(6)
		me.Character.HumanoidRootPart.Position = at + Vector3.new(40, 0, 0)
		world.advance(0.1)
		me.Character.HumanoidRootPart.Position = at
		world.advance(0.1)
		expect(Combat.getHp(me)).toBe(7)
		world.advance(8.1)
	end)
	it("boosts exactly one unboosted player for five seconds without healing-event duplication", function()
		Combat.healPlayer(me, 100)
		local before = Stats.getStat(me, "attackSpeed")
		local healing = 0
		local connection = Combat.HealingApplied:Connect(function(p)
			if p == me then
				healing += 1
			end
		end)
		charm("Herald", me.Character.HumanoidRootPart.Position)
		world.advance(0.5)
		local hp, maximum = Combat.getHp(me)
		expect(maximum).toBe(12)
		expect(hp).toBe(12)
		expect(Stats.getStat(me, "speed")).toBe(20)
		expect(Stats.getStat(me, "attackSpeed")).toBe(before + 20)
		expect(Stats.getStat(peer, "speed")).toBe(0)
		expect(healing).toBe(0)
		world.advance(4)
		expect(Stats.getStat(me, "maxHp")).toBe(12)
		world.advance(1.5)
		expect(Stats.getStat(me, "maxHp")).toBe(10)
		expect(Stats.getStat(me, "speed")).toBe(0)
		expect(Stats.getStat(me, "attackSpeed")).toBe(before)
		connection:Disconnect()
		world.advance(3)
	end)
	it("boosts a turret's base stats and restores them, without touching equipped source counts", function()
		assert(Stats.addItem(me, "BrassSentry"))
		Run.skipTo(require(Shared.Util.RunSchedule).wave(Run.getWave()).endsAt)
		world.advance(0.1)
		world.fireServerAs(me, "SetShopReady", true)
		world.fireServerAs(peer, "SetShopReady", true)
		world.advance(1)
		require(S.SpawnDirector).setPaused(true)
		Enemy.killAll()
		local turret = assert(Structures.getSnapshot()[1])
		me.Character.HumanoidRootPart.Position = Vector3.new(-90, 0, -60)
		peer.Character.HumanoidRootPart.Position = Vector3.new(90, 0, 60)
		charm("Herald", Vector3.new(turret.x, 0, turret.z))
		local amounts = {}
		local original = Weapons.structureHit
		Weapons.structureHit = function(player, id, amount, ...)
			table.insert(amounts, amount)
			return original(player, id, amount, ...)
		end
		Enemy.spawn("Brute", turret.x + 6, turret.z, 1000, 0, nil, nil, 0)
		world.advance(1.5)
		expect(table.find(amounts, 4) ~= nil).toBe(true) -- 12 boosted base +80% of Crazy's -10 Engineering
		expect(Structures.sourceCount(me)).toBe(1)
		world.advance(4.5)
		table.clear(amounts)
		world.advance(1.5)
		expect(table.find(amounts, 2) ~= nil).toBe(true)
		Weapons.structureHit = original
		expect(#world.errors).toBe(0)
	end)
	it("preserves native raw HP boost and expiry arithmetic for a character with HP gain modifiers", function()
		Run.endRun("Abandoned")
		world.advance(Config.Run.flow.resultsSeconds + 0.1)
		Config.Classes.Golem.available = true
		require(S.PlayerDataService).unlockAll(me)
		assert(Run.selectClass(me, "Golem"))
		assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
		world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
		require(S.SpawnDirector).setPaused(true)
		Enemy.killAll()
		for _, p in { me, peer } do
			for _, weapon in Weapons.getWeapons(p) do
				Weapons.removeWeapon(p, weapon.uid)
			end
			Combat.protect(p, 10000)
		end
		peer.Character.HumanoidRootPart.Position = Vector3.new(90, 0, 60)
		expect(Combat.getHp(me)).toBe(39)
		charm("Herald", me.Character.HumanoidRootPart.Position)
		world.advance(0.5)
		local hp, maximum = Combat.getHp(me)
		expect(maximum).toBe(49) -- floor((30+floor(39*.2))*1.33)
		expect(hp).toBe(46) -- Player.boost grants the raw7 current HP directly, independently of gain modifiers
		world.advance(5.2)
		local after, maxAfter = Combat.getHp(me)
		expect(maxAfter).toBe(35) -- native boost_ended removes49-39=10 raw; the temporary layer retains7-10=-3
		expect(after).toBe(35)
		expect(#world.errors).toBe(0)
	end)
end)
