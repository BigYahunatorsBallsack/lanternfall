--!strict
-- Cryptid must receive real native tree groups and be able to retain ten actual SpawnDirector trees.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Enemy, Spawn = require(S.RunDirector), require(S.EnemySim), require(S.SpawnDirector)
local me = world.addPlayer("Owner", 1, true)
world.advance(0.5)
Config.Classes.Cryptid.available = true
require(S.PlayerDataService).unlockAll(me)
Spawn.setPaused(true)
Run.setHoldWaves(true)
assert(Run.selectClass(me, "Cryptid"))
assert(Run.launch({ me }, require(Shared.Util.DangerRules).defaultOptions()))
world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
require(S.WeaponService).setPaused(true)
Enemy.killAll()
local function trees()
	local ids, total = {}, 0
	Enemy.collectIds(ids)
	for _, id in ids do
		if Enemy.getKind(id) == "Tree" then
			total += 1
		end
	end
	return total
end
describe("Cryptid native tree production", function()
	it("spawns the first modifier-scaled group at ten seconds without distributing trees beforehand", function()
		local random = require(S.RandomService)
		local original = random.number
		local ok, err = pcall(function()
			random.number = function(channel, player)
				return if channel == "Spawns" then 0 else original(channel, player)
			end
			Spawn.setPaused(false)
			Run.skipTo(9)
			world.advance(0.1)
			expect(trees()).toBe(0)
			Run.skipTo(10)
			world.advance(0.1)
			expect(trees()).toBe(0) -- the consolidated spawner queues the native one-second birth marker
			world.advance(Config.Run.spawn.markerSeconds + 0.5)
			expect(trees()).toBe(3)
		end)
		random.number = original
		Spawn.setPaused(true)
		assert(ok, err)
	end)
	it("retains ten trees from the real spawner instead of enforcing the old six-tree cap", function()
		Enemy.killAll()
		for _ = 1, 10 do
			expect(Spawn.spawnTree(Vector3.zero)).toBe(true)
		end
		expect(trees()).toBe(10)
		expect(#world.errors).toBe(0)
	end)
end)
