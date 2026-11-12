--!strict
-- Bot-O-Mine follows its owner, fires live projectiles and lays native pet mines through production services.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Structures, Enemy = require(f.S.StructureService), require(f.S.EnemySim)
local Map, Combat = require(f.S.MapService), require(f.S.CombatService)
local function objects(kind)
	local out = {}
	for _, row in Structures.getSnapshot() do
		if row.kind == kind then
			table.insert(out, row)
		end
	end
	return out
end
local function start()
	Structures.setPaused(true)
	f.start("WatchmanPistol")
	f.Weapons.setPaused(true)
	assert(f.Stats.addItem(f.me, "BotOMine"))
	f.nextWave()
	Map.setMovementCheck(false)
end
describe("Native Bot-O-Mine", function()
	it("counts the permanent item as both one pet and one structure", function()
		start()
		expect(#objects("BotOMine")).toBe(1)
		expect(Structures.petSourceCount(f.me)).toBe(1)
		expect(Structures.sourceCount(f.me)).toBe(1)
		expect(Structures.turretSourceCount(f.me)).toBe(0)
		expect(f.Config.Items.byId.BotOMine.available).toBe(false)
	end)
	it("follows the owner even when another player stands closer", function()
		local row = objects("BotOMine")[1]
		local y = f.Config.Map.arena.center.Y
		local owner = Vector3.new(70, y, 0)
		f.me.Character.HumanoidRootPart.Position = owner
		f.peer.Character.HumanoidRootPart.Position = Vector3.new(row.x, y, row.z)
		local before = (Vector3.new(row.x, y, row.z) - owner).Magnitude
		Structures.setPaused(false)
		f.world.advance(1, 1 / 60)
		row = objects("BotOMine")[1]
		expect((Vector3.new(row.x, y, row.z) - owner).Magnitude < before - 10).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
	it("fires after its native initial cooldown and lays mines at five-second intervals", function()
		start()
		local row = objects("BotOMine")[1]
		local id = assert(Enemy.spawn("Brute", row.x, row.z - 20, 100, 0, nil, nil, 0))
		local hp = Enemy.getHealth(id)
		Structures.setPaused(false)
		f.world.advance(0.3, 1 / 60)
		expect(Enemy.getHealth(id)).toBe(hp)
		f.world.advance(0.5, 1 / 60)
		expect(Enemy.getHealth(id) < hp).toBe(true)
		Enemy.killAll()
		f.world.advance(4.1, 1 / 60)
		expect(#objects("RuneMine")).toBe(0)
		f.world.advance(0.2, 1 / 60)
		expect(#objects("RuneMine")).toBe(1)
		f.world.advance(5.1, 1 / 60)
		expect(#objects("RuneMine")).toBe(2)
		expect(Structures.petSourceCount(f.me)).toBe(1)
		expect(Structures.sourceCount(f.me)).toBe(1)
	end)
	it("continues following, shooting and triggering pet mines while the owner is down", function()
		start()
		local y = f.Config.Map.arena.center.Y
		f.me.Character.HumanoidRootPart.Position = Vector3.new(70, y, 0)
		f.peer.Character.HumanoidRootPart.Position = Vector3.new(-70, y, 0)
		Structures.setPaused(false)
		f.world.advance(0.2, 1 / 60)
		Combat.drainPlayer(f.me, 100000)
		expect(f.Run.getParticipantState(f.me)).toBe("Down")
		local before = objects("BotOMine")[1]
		local id = assert(Enemy.spawn("Brute", before.x, before.z - 20, 100, 0, nil, nil, 0))
		local hp = Enemy.getHealth(id)
		f.world.advance(1, 1 / 60)
		local after = objects("BotOMine")[1]
		expect(after.x < before.x - 10).toBe(true)
		expect(Enemy.getHealth(id) < hp).toBe(true)
		Enemy.killAll()
		f.world.advance(4.1, 1 / 60)
		local mine = objects("RuneMine")[1]
		assert(mine, "Down owner's Bot-O-Mine did not lay its mine")
		local offset = f.Config.Structures.kinds.RuneMine.triggerOffsetZ
		local trigger = assert(Enemy.spawn("Brute", mine.x, mine.z + offset, 100, 0, nil, nil, 0))
		f.world.advance(0.1, 1 / 60)
		Enemy.teleport(trigger, Vector3.new(mine.x + 10, y, mine.z + offset))
		f.world.advance(0.1, 1 / 60)
		expect(#objects("RuneMine")).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
	it("uses pet-structure scaling for mines, including Beast Master's missing stat entries", function()
		local def = table.clone(f.Config.Structures.kinds.RuneMine)
		def.petMine, def.petBeastMaster = true, true
		local damage = require(f.S.StructureService.Rules).damage(def, {
			engineering = 40,
			meleeDamage = 10,
			rangedDamage = 20,
			elementalDamage = 30,
			damage = 50,
			structureDamage = 50,
			explosionDamage = 50,
		})
		expect(damage).toBe(275)
		f.Run.endRun("Abandoned")
		expect(#objects("BotOMine")).toBe(0)
		expect(#objects("RuneMine")).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
