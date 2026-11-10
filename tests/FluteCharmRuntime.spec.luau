--!strict
-- Flute converts a wounded target before damage, exposes friendly snapshots, fights without player kill credit and expires.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Weapons, Enemy = require(S.RunDirector), require(S.WeaponService), require(S.EnemySim)
local me = world.addPlayer("Owner", 1, true)
world.advance(0.5)
Config.Weapons.Flute.available = true
Run.setHoldWaves(true)
Run.setReady(me, true)
world.advance(3.5)
require(S.SpawnDirector).setPaused(true)
require(S.ExperienceService).setPaused(true)
require(S.CombatService).protect(me, 10000)
for _, weapon in Weapons.getWeapons(me) do
	Weapons.removeWeapon(me, weapon.uid)
end
Enemy.killAll()
local random = require(S.RandomService)
local original = random.number
random.number = function(channel, player)
	return if channel == "Combat" then 0 else original(channel, player)
end
local statuses = {}
local Snapshot = require(Shared.Net.Snapshot)
world.getRemote("EnemySnapshot").OnClientEvent:Connect(function(packet)
	local cols = Snapshot.newColumns()
	local count = Snapshot.decodeInto(packet, cols, 1)
	for index = 1, count do
		statuses[cols.ids[index]] = cols.statuses[index]
	end
end)
local target, hp
describe("Flute Charm through production services", function()
	it("absorbs the triggering hit and keeps the converted actor out of hostile hit queries", function()
		local at = me.Character.HumanoidRootPart.Position
		target = assert(Enemy.spawn("Shadeling", at.X + 6, at.Z, 100, 1, nil, nil, 0))
		Enemy.damage(target, Enemy.getHealth(target) * 0.8, nil)
		hp = Enemy.getHealth(target)
		assert(Weapons.addWeapon(me, "Flute", 4))
		world.advance(0.5)
		expect(Enemy.isCharmed(target)).toBe(true)
		expect(Enemy.getHealth(target)).toBe(hp)
		expect(Enemy.getCharmedCount(me.UserId)).toBe(1)
		expect(Enemy.isAlive(target)).toBe(false)
		local ids = {}
		Enemy.queryRadius(Enemy.getPosition(target), 100, ids)
		expect(table.find(ids, target)).toBe(nil)
		expect(bit32.band(statuses[target] or 0, Snapshot.STATUS_CHARMED) ~= 0).toBe(true)
		Enemy.damage(target, 100000, me)
		expect(Enemy.getHealth(target)).toBe(hp)
		for _, weapon in Weapons.getWeapons(me) do
			Weapons.removeWeapon(me, weapon.uid)
		end
	end)
	it("damages enemies as an ally with the original unassigned kill attribution", function()
		local at = Enemy.getPosition(target)
		local victim = assert(Enemy.spawn("Brute", at.X + 2, at.Z, 100, 1, nil, nil, 0))
		Enemy.damage(victim, Enemy.getHealth(victim) - 2, nil)
		local killed
		Enemy.EnemyKilled:Connect(function(info)
			if info.id == victim then
				killed = info
			end
		end)
		local before = require(S.PlayerDataService).get(me).nativeCounts.enemiesKilled
		world.advance(0.3)
		expect(Enemy.isAlive(victim)).toBe(false)
		assert(killed)
		expect(killed.killer).toBe(nil)
		expect(require(S.PlayerDataService).get(me).nativeCounts.enemiesKilled).toBe(before)
	end)
	it("dies after eight seconds without reverting and leaves no runtime errors", function()
		world.advance(8.1)
		expect(Enemy.isCharmed(target)).toBe(false)
		expect(Enemy.getCharmedCount(me.UserId)).toBe(0)
		expect(Enemy.isAlive(target)).toBe(false)
		random.number = original
		expect(#world.errors).toBe(0)
	end)
	it("keeps hatched offspring friendly with a fresh lifetime", function()
		local egg = assert(Enemy.spawn("BroodEgg", 20, 20, 100, 1, nil, nil, 0, 1))
		Enemy.damage(egg, Enemy.getHealth(egg) * 0.9, nil)
		assert(Enemy.tryCharm(me, egg, { charmChance = 1, charmThreshold = 1 }, function()
			return 0
		end))
		world.advance(5.2)
		expect(Enemy.isCharmed(egg)).toBe(false)
		local ids = {}
		local count = Enemy.collectAllIds(ids)
		local child
		for index = 1, count do
			if Enemy.isCharmed(ids[index]) and Enemy.getKind(ids[index]) == "Reaper" then
				child = ids[index]
			end
		end
		assert(child, "hatched offspring did not inherit Charm")
		expect(Enemy.getCharmedCount(me.UserId)).toBe(1)
		world.advance(3)
		expect(Enemy.isCharmed(child)).toBe(true)
		world.advance(5.1)
		expect(Enemy.isCharmed(child)).toBe(false)
		expect(#world.errors).toBe(0)
	end)
	it("shares the configured actor budget between hostile and charmed actors", function()
		Enemy.killAll()
		local ally = assert(Enemy.spawn("Shadeling", 20, 20, 100, 1, nil, nil, 0))
		Enemy.damage(ally, Enemy.getHealth(ally) * 0.9, nil)
		assert(Enemy.tryCharm(me, ally, { charmChance = 1, charmThreshold = 1 }, function()
			return 0
		end))
		for _ = 2, Config.Run.spawn.cap.max do
			assert(Enemy.spawn("Shadeling", 20, 20, 1, 1, nil, nil, 0))
		end
		expect(Enemy.spawn("Shadeling", 20, 20, 1, 1)).toBe(nil)
		expect(Enemy.getCount()).toBe(Config.Run.spawn.cap.max)
		Enemy.killAll()
	end)
end)
