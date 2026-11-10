--!strict
-- Native full starting choices, personal core mechanics and exact unlock boundary through production services.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Explorer")
describe("Native Explorer package", function()
	it("runs all28choices plus one Lumberjack Shirt", function()
		f.starts(28, { LumberjackShirt = 1 })
	end)
	it("uses native42x31map tiles,12Trees and original personal stat modifiers", function()
		f.start("FoundryKey")
		local b = require(f.S.MapService).getArenaBounds()
		expect(b.halfX * 2).toBeNear(268.8)
		expect(b.halfZ * 2).toBeNear(198.4)
		expect(f.Stats.getStat(f.me, "trees")).toBe(12)
		expect(f.Stats.getStat(f.me, "speed")).toBe(10)
		expect(f.Stats.getStat(f.me, "pickupRange")).toBe(50)
		expect(f.Stats.getStat(f.me, "damage")).toBe(-40)
	end)
	it("spawns opening trees through the production queues with the native33percent unit chance", function()
		f.nextWave()
		local Random = require(f.S.RandomService)
		local original = Random.number
		Random.number = function(channel, ...)
			if channel == "Spawns" then
				return 0
			end
			return original(channel, ...)
		end
		local Spawn = require(f.S.SpawnDirector)
		Spawn.setPaused(false)
		f.world.advance(2.8)
		Spawn.setPaused(true)
		Random.number = original
		local E, ids, trees = require(f.S.EnemySim), {}, 0
		E.collectIds(ids)
		for _, id in ids do
			if E.getKind(id) == "Tree" then
				trees += 1
			end
		end
		-- (1 + 12 Trees) * 0.33 = 4.29; a zero rest roll adds the fifth tree.
		expect(trees).toBe(5)
	end)
	it("persists only personally killed trees and unlocks after50", function()
		local A = require(f.Shared.Util.CharacterAccess)
		local E = require(f.S.EnemySim)
		f.Data.get(f.peer).nativeCounts.treesKilled = 49
		local before = f.Data.get(f.peer).nativeCounts.enemiesKilled
		local tree = assert(E.spawn("Tree", 40, 40, 1, 0, nil, nil, 0))
		E.damage(tree, 10000, f.peer)
		expect(f.Data.get(f.peer).nativeCounts.treesKilled).toBe(50)
		expect(f.Data.get(f.peer).nativeCounts.enemiesKilled).toBe(before)
		expect(A.characterUnlocked(f.Data.get(f.peer), "Explorer")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
