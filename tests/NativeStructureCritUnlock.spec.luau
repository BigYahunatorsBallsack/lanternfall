--!strict
-- A real Pile of Books purchase affects pet and ordinary structure projectile crits, isolated from players' weapons.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Sim = require(f.S.StructureService.Projectiles)
local Enemy = require(f.S.EnemySim)
local Structures = require(f.S.StructureService)
local Rules = require(f.S.StructureService.Rules)
local Pets = require(f.Shared.Config.Pets)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
assert(f.Stats.addStats(f.me, { critChance = 100 }))
local at = Vector3.new(0, f.Config.Map.arena.center.Y, 0)
local function target()
	Enemy.killAll()
	Sim.clear()
	local id = assert(Enemy.spawn("Brute", 20, 0, 100, 0, nil, nil, 0))
	return id, Enemy.getHealth(id)
end
describe("Native structure crit unlock", function()
	it("preserves a valid critical multiplier on legacy structures without explicit crit fields", function()
		local chance, multiplier = Rules.critical({}, {})
		expect(chance).toBe(0)
		expect(multiplier).toBe(f.Config.Player.critMultiplier)
	end)
	it("keeps Bot-O-Mine's shot noncritical before owning Books", function()
		local id, hp = target()
		Sim.launchPet(
			f.me,
			at,
			Pets.kinds.BotOMine.weapon,
			f.Weapons.getStructureStats(f.me),
			{ Vector3.new(1, 0, 0) },
			false
		)
		Sim.step(0.1)
		expect(Enemy.getHealth(id)).toBe(hp - 10)
	end)
	it("unlocks actual Bot shots with their original 1.5 critical multiplier", function()
		assert(f.Stats.addItem(f.me, "PileOfBooks"))
		f.world.advance(0.1)
		local id, hp = target()
		Sim.launchPet(
			f.me,
			at,
			Pets.kinds.BotOMine.weapon,
			f.Weapons.getStructureStats(f.me),
			{ Vector3.new(1, 0, 0) },
			false
		)
		Sim.step(0.1)
		expect(Enemy.getHealth(id)).toBe(hp - 20) -- floor(10 + 3 Engineering) * 1.5, rounded
	end)
	it("uses the same unlock on ordinary structures and native mine stats without adding weapon scaling", function()
		local id, hp = target()
		local sheet = f.Weapons.getStructureStats(f.me)
		local turret = f.Config.Structures.kinds.BrassSentry
		Sim.launch(f.me, at, turret, sheet, { Vector3.new(1, 0, 0) })
		Sim.step(0.1)
		expect(Enemy.getHealth(id)).toBe(hp - 24) -- floor(10 + .8 * 3) * 2
		local mine = f.Config.Structures.kinds.RuneMine
		local chance, multiplier = Rules.critical(mine, sheet)
		expect(chance).toBe(1)
		expect(multiplier).toBe(2)
		local base = Rules.damage(mine, sheet)
		expect(Rules.damage(mine, { engineering = 3, weaponScalingEngineering = 20 })).toBe(base)
		expect(Structures.petSourceCount(f.me)).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
	it("applies Books to a real native mine explosion, with the critical rolled on its victim", function()
		Enemy.killAll()
		assert(f.Stats.addItem(f.me, "RuneMine"))
		f.nextWave()
		f.Weapons.setPaused(true)
		local mine
		for _, row in Structures.getSnapshot() do
			if row.kind == "RuneMine" then
				mine = row
				break
			end
		end
		assert(mine, "Missing wave-start mine")
		local offset = f.Config.Structures.kinds.RuneMine.triggerOffsetZ
		local trigger = assert(Enemy.spawn("Brute", mine.x, mine.z + offset, 100, 0, nil, nil, 0))
		local victim = assert(Enemy.spawn("Brute", mine.x + 5, mine.z, 100, 0, nil, nil, 0))
		local hp = Enemy.getHealth(victim)
		Structures.setPaused(false)
		f.world.advance(0.1, 1 / 60)
		Enemy.teleport(trigger, Vector3.new(mine.x + 10, at.Y, mine.z + offset))
		f.world.advance(0.1, 1 / 60)
		expect(Enemy.getHealth(victim)).toBe(hp - 26)
		expect(#f.world.errors).toBe(0)
	end)
	it("keeps the same native crit unlock on mines actually deployed by Bot-O-Mine", function()
		f.start("WatchmanPistol")
		f.Weapons.setPaused(true)
		assert(f.Stats.addItem(f.me, "BotOMine"))
		assert(f.Stats.addItem(f.me, "PileOfBooks"))
		assert(f.Stats.addStats(f.me, { critChance = 100 }))
		f.nextWave()
		f.Weapons.setPaused(true)
		Structures.setPaused(false)
		f.world.advance(5.1, 1 / 60)
		local mine
		for _, row in Structures.getSnapshot() do
			if row.kind == "RuneMine" then
				mine = row
				break
			end
		end
		assert(mine, "Bot did not deploy a mine")
		-- Isolate the mine's hit from the separate Bot body and gun; the inventory and deployed mine remain intact.
		require(f.S.StructureService.PetActors).clear()
		Enemy.killAll()
		local offset = f.Config.Structures.kinds.RuneMine.triggerOffsetZ
		local trigger = assert(Enemy.spawn("Brute", mine.x, mine.z + offset, 100, 0, nil, nil, 0))
		local victim = assert(Enemy.spawn("Brute", mine.x + 5, mine.z, 100, 0, nil, nil, 0))
		local hp = Enemy.getHealth(victim)
		f.world.advance(0.1, 1 / 60)
		Enemy.teleport(trigger, Vector3.new(mine.x + 10, at.Y, mine.z + offset))
		f.world.advance(0.1, 1 / 60)
		expect(Enemy.getHealth(victim)).toBe(hp - 26)
		expect(#f.world.errors).toBe(0)
	end)
end)
