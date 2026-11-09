--!strict
-- Source-based traps, live projectiles and equipped-source counts through the production service graph.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Stats, Weapons = require(S.RunDirector), require(S.StatService), require(S.WeaponService)
local Structures, Enemy, Spawn = require(S.StructureService), require(S.EnemySim), require(S.SpawnDirector)
local me = world.addPlayer("Owner", 1, true)
world.advance(0.5)
Spawn.setPaused(true)
Run.setHoldWaves(true)
Config.Weapons.Awl.available = true
Config.Classes.NightWatch.weaponKind = nil -- fixture permits the melee trap source
world.fireServerAs(me, "SetReady", true)
world.advance(3.5)
Weapons.setPaused(true)
require(S.CombatService).protect(me, 10000)
local function nextWave()
	Run.skipTo(require(Shared.Util.RunSchedule).wave(Run.getWave()).endsAt)
	world.advance(0.1)
	world.fireServerAs(me, "SetShopReady", true)
	world.advance(1)
	Spawn.setPaused(true)
	Enemy.killAll()
end
local function traps()
	local found = {}
	for _, row in Structures.getSnapshot() do
		if row.kind == "DartTrap" then
			table.insert(found, row)
		end
	end
	return found
end
describe("Native structure extensions", function()
	it("counts equipped effects and duplicate items while excluding deployed mines", function()
		assert(Stats.addItem(me, "BrassSentry"))
		assert(Stats.addItem(me, "BrassSentry"))
		assert(Weapons.addWeapon(me, "Awl", 4))
		expect(Structures.sourceCount(me)).toBe(3)
		nextWave()
		Weapons.NativeMineRequested:Fire(me, Vector3.new(4, 0, 5))
		expect(Structures.sourceCount(me)).toBe(3)
		local found = false
		for _, row in Structures.getSnapshot() do
			if row.kind == "RuneMine" and row.x == 4 and row.z == 5 then
				found = true
			end
		end
		expect(found).toBe(true)
	end)
	it("spawns one initial Awl trap and its tier-IV recurrence at three seconds", function()
		expect(#traps()).toBe(1)
		world.advance(3.1)
		expect(#traps()).toBe(2)
	end)
	it("releases six live darts on the first enemy exit even when another enemy remains inside", function()
		local trap = traps()[1]
		local offset = Config.Structures.kinds.DartTrap.triggerOffsetZ
		local first = Enemy.spawn("Brute", trap.x, trap.z + offset, 100, 0, nil, nil, 0)
		assert(Enemy.spawn("Brute", trap.x, trap.z + offset, 100, 0, nil, nil, 0))
		local victim = Enemy.spawn("Brute", trap.x + 7, trap.z, 100, 0, nil, nil, 0)
		local before = Enemy.getHealth(victim)
		world.advance(0.1)
		Enemy.damage(first, 1000000, me)
		world.advance(0.1)
		for _, row in traps() do
			assert(row.id ~= trap.id, "trap did not consume itself on exit")
		end
		world.advance(0.2)
		expect(Enemy.getHealth(victim) < before).toBe(true)
		expect(#world.errors).toBe(0)
	end)
	it("resets pending structure projectiles and deployments between waves", function()
		Run.endRun("Defeat")
		world.advance(0.1)
		expect(#Structures.getSnapshot()).toBe(0)
		expect(#world.errors).toBe(0)
	end)
end)
