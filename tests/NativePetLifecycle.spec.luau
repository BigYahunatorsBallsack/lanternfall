--!strict
-- A credited kill may synchronously end the run; active pet frames, projectile volleys and mines must survive cleanup.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Structures, Enemy = require(f.S.StructureService), require(f.S.EnemySim)
local Sim = require(f.S.StructureService.Projectiles)
local Pets = require(f.Shared.Config.Pets)
local ending = false
Enemy.EnemyKilled:Connect(function(info)
	if not ending and info.killer == f.me then
		ending = true
		f.Run.endRun("Victory")
	end
end)
local function start(items)
	Structures.setPaused(true)
	f.start("WatchmanPistol")
	f.Weapons.setPaused(true)
	for _, id in items do
		assert(f.Stats.addItem(f.me, id))
	end
	f.nextWave()
	ending = false
end
local function find(kind)
	for _, row in Structures.getSnapshot() do
		if row.kind == kind then
			return row
		end
	end
	error("Missing " .. kind)
end
describe("Native pet terminal cleanup", function()
	it("releases Lootworm material claims when its tree hit synchronously ends the run", function()
		start({ "Lootworm" })
		f.Weapons.setPaused(true)
		local pet = find("Lootworm")
		assert(Enemy.spawn("Tree", pet.x + 2, pet.z, 0.001, 0, nil, nil, 0))
		Structures.setPaused(false)
		f.world.advance(1, 1 / 60)
		expect(ending).toBe(true)
		expect(#Structures.getSnapshot()).toBe(0)
		assert(#f.world.errors == 0, table.concat(f.world.errors, "\n"))
	end)
	it("clears Catling Gun bodies when a live pet bullet ends the run", function()
		start({ "CatlingGun" })
		f.Weapons.setPaused(true)
		local pet = find("CatlingGun")
		local y = f.Config.Map.arena.center.Y
		f.peer.Character.HumanoidRootPart.Position = Vector3.new(pet.x, y, pet.z)
		assert(Enemy.spawn("Brute", pet.x + 20, pet.z, 0.001, 0, nil, nil, 0))
		Structures.setPaused(false)
		f.world.advance(1.5, 1 / 60)
		expect(ending).toBe(true)
		expect(#Structures.getSnapshot()).toBe(0)
		assert(#f.world.errors == 0, table.concat(f.world.errors, "\n"))
	end)
	it("ends the run from Blazemander's delayed hitbox without resuming cleared pet frames", function()
		start({ "Blazemander" })
		local pet = find("Blazemander")
		assert(Enemy.spawn("Brute", pet.x, pet.z - 2, 0.001, 0, nil, nil, 0))
		Structures.setPaused(false)
		f.world.advance(1, 1 / 60)
		expect(ending).toBe(true)
		expect(#Structures.getSnapshot()).toBe(0)
		assert(#f.world.errors == 0, table.concat(f.world.errors, "\n"))
	end)
	it("ends the run from a melee pet hit without stepping a cleared body world", function()
		start({ "Ratzilla" })
		local pet = find("Ratzilla")
		assert(Enemy.spawn("Brute", pet.x + 2, pet.z, 0.001, 0, nil, nil, 0))
		Structures.setPaused(false)
		f.world.advance(1, 1 / 60)
		expect(ending).toBe(true)
		expect(#Structures.getSnapshot()).toBe(0)
		assert(#f.world.errors == 0, table.concat(f.world.errors, "\n"))
	end)
	it("clears multiple pending pet volleys during the hit that ends the run", function()
		start({})
		assert(Enemy.spawn("Brute", 20, 0, 0.001, 0, nil, nil, 0))
		for _ = 1, 2 do
			Sim.launchPet(
				f.me,
				Vector3.new(0, f.Config.Map.arena.center.Y, 0),
				Pets.kinds.BotOMine.weapon,
				{},
				{ Vector3.new(1, 0, 0) },
				false
			)
		end
		Sim.step(0.1)
		expect(ending).toBe(true)
		assert(#f.world.errors == 0, table.concat(f.world.errors, "\n"))
	end)
	it("does not remove cleared objects again after a terminal mine explosion", function()
		start({ "MoonGarden", "RuneMine" })
		local mine = find("RuneMine")
		local offset = f.Config.Structures.kinds.RuneMine.triggerOffsetZ
		local id = assert(Enemy.spawn("Brute", mine.x, mine.z + offset, 0.001, 0, nil, nil, 0))
		Structures.setPaused(false)
		f.world.advance(0.1, 1 / 60)
		Enemy.teleport(id, Vector3.new(mine.x + 10, f.Config.Map.arena.center.Y, mine.z + offset))
		f.world.advance(0.1, 1 / 60)
		expect(ending).toBe(true)
		expect(#Structures.getSnapshot()).toBe(0)
		assert(#f.world.errors == 0, table.concat(f.world.errors, "\n"))
	end)
end)
