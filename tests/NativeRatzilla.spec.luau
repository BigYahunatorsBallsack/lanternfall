--!strict
-- Ratzilla deployments exercise production ownership, movement, target reservations, attacks and wave cleanup.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Structures, Enemy = require(f.S.StructureService), require(f.S.EnemySim)
local Map = require(f.S.MapService)
local function rats()
	local result = {}
	for _, row in Structures.getSnapshot() do
		if row.kind == "Ratzilla" then
			table.insert(result, row)
		end
	end
	return result
end
describe("Native Ratzilla", function()
	it("counts equipped pets independently of structures and deployed actors", function()
		f.start("WatchmanPistol")
		f.Weapons.setPaused(true)
		assert(f.Stats.addItem(f.me, "Ratzilla"))
		assert(f.Stats.addItem(f.me, "Ratzilla"))
		expect(Structures.sourceCount(f.me)).toBe(0)
		expect(Structures.petSourceCount(f.me)).toBe(2)
		expect(Structures.petSourceCount(f.peer)).toBe(0)
		f.nextWave()
		expect(#rats()).toBe(2)
		expect(Structures.petSourceCount(f.me)).toBe(2)
	end)
	it("moves towards ordinary enemies, reserves separate targets and lands native melee damage", function()
		local root = Map.getRootPosition(f.me)
		local first = Enemy.spawn("Brute", root.X + 65, root.Z, 100, 0, nil, nil, 0)
		local second = Enemy.spawn("Brute", root.X - 65, root.Z, 100, 0, nil, nil, 0)
		local firstHp, secondHp = Enemy.getHealth(first), Enemy.getHealth(second)
		Structures.setPaused(false)
		f.world.advance(4)
		expect(Enemy.getHealth(first) < firstHp).toBe(true)
		expect(Enemy.getHealth(second) < secondHp).toBe(true)
		expect(#rats()).toBe(2)
		expect(#f.world.errors).toBe(0)
	end)
	it("does not target a boss and clears actors at the end of the wave", function()
		Enemy.killAll()
		local row = rats()[1]
		local bossKind = next(f.Config.Enemies.champions)
		local boss = Enemy.spawn(bossKind, row.x + 30, row.z, 100, 0, nil, nil, 0)
		f.world.advance(0.2)
		local before = rats()
		local hp = Enemy.getHealth(boss)
		f.world.advance(1)
		for index, rat in rats() do
			expect(rat.x).toBeNear(before[index].x)
			expect(rat.z).toBeNear(before[index].z)
		end
		expect(Enemy.getHealth(boss)).toBe(hp)
		f.Run.endRun("Abandoned")
		expect(#rats()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
