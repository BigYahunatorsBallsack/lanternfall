--!strict
-- Actual SpawnDirector acquisition and recurring bait encounters, including a later wave without buying another Bait.
local spawned = 0
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Fisherman", function(Server)
	local Enemy = require(Server.Services.EnemySim)
	local original = Enemy.spawn
	Enemy.spawn = function(id, ...)
		local result = original(id, ...)
		if id == "Hookfang" and result then
			spawned += 1
		end
		return result
	end
end)
local Spawn = require(f.S.SpawnDirector)
local Random = require(f.S.RandomService)
local number = Random.number
Random.number = function(channel, ...)
	if channel == "Spawns" then
		return 0
	end
	return number(channel, ...)
end
local function advance(seconds)
	f.world.advance(seconds)
end
describe("Fisherman recurring production groups", function()
	it("spawns acquisition Baits, the fifteen-second group and its repeats on successive waves", function()
		f.start("RitualDirk")
		assert(f.Stats.addItem(f.me, "BloodLure"))
		f.nextWave()
		require(f.S.CombatService).protect(f.me, 10000)
		require(f.S.CombatService).protect(f.peer, 10000)
		Spawn.setPaused(false)
		local before = spawned
		advance(5)
		expect(spawned > before).toBe(true)
		local acquired = spawned
		advance(9)
		expect(spawned).toBe(acquired)
		advance(4)
		expect(spawned > acquired).toBe(true)
		local first = spawned
		advance(6)
		expect(spawned > first).toBe(true)
		Spawn.setPaused(true)
		f.nextWave()
		Spawn.setPaused(false)
		local previous = spawned
		advance(5)
		expect(spawned).toBe(previous)
		advance(13)
		expect(spawned > previous).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
