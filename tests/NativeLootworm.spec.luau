--!strict
-- Lootworm production adapters retain native tree priority, one-hit attack windows and item-owned deployment.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy, XP = require(f.S.EnemySim), require(f.S.ExperienceService)
local Worm, Actors = require(f.S.StructureService.PetLoot), require(f.S.StructureService.PetActors)
local Structures, Combat = require(f.S.StructureService), require(f.S.CombatService)
local Pets = require(f.Shared.Config.Pets)
local y = f.Config.Map.arena.center.Y
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
local function actor(sheet)
	local o =
		{ id = 10000, owner = f.me, position = Vector3.new(0, y, 0), pet = Pets.kinds.Lootworm, beastMaster = true }
	Worm.init(o, sheet or {})
	return o
end
describe("Native Lootworm", function()
	it("always prefers trees and invalidates targets when a new neutral or material appears", function()
		XP.setPaused(false)
		XP.dropMaterials(Vector3.new(1, y, 0), 1, 0)
		local o = actor()
		local far = assert(Enemy.spawn("Tree", 40, 0, 1, 0, nil, nil, 0))
		Worm.goal(o)
		expect(o.lootTarget.id).toBe(far)
		local close = assert(Enemy.spawn("Tree", 10, 0, 1, 0, nil, nil, 0))
		Worm.goal(o)
		expect(o.lootTarget.id).toBe(close)
		Enemy.remove(close)
		Worm.goal(o)
		expect(o.lootTarget.id).toBe(far)
		Enemy.remove(far)
		Worm.goal(o)
		expect(o.lootTarget.tree).toBe(false)
		expect(XP.getMaterialPosition(o.lootTarget.id) ~= nil).toBe(true)
		XP.setPaused(true)
	end)
	it("hits only one object per attack and retains the largest encountered tree damage without life steal", function()
		Enemy.killAll()
		local o = actor({ lifeSteal = 100 })
		Combat.drainPlayer(f.me, 2)
		local ownerHp = Combat.getHp(f.me)
		local first = assert(Enemy.spawn("Tree", 0, -1.2, 1, 0, nil, nil, 0))
		local second = assert(Enemy.spawn("Tree", 1, -1.2, 1, 0, nil, nil, 0))
		local a, b = Enemy.getHealth(first), Enemy.getHealth(second)
		local expected = math.floor(Enemy.getMaxHealth(first) / 5)
		for _ = 1, 5 do
			Worm.step(o, {}, 1 / 60)
		end
		expect((a - Enemy.getHealth(first)) + (b - Enemy.getHealth(second))).toBe(expected)
		expect(o.lootDamage).toBe(expected)
		expect(Combat.getHp(f.me)).toBe(ownerHp)
		Enemy.killAll()
		assert(Enemy.spawn("Tree", 0, -1.2, 0.1, 0, nil, nil, 0))
		Worm.step(o, {}, 1 / 60)
		expect(o.lootDamage).toBe(expected)
	end)
	it("kills a divisible-health tree in five native attacks and never attacks without a nearby tree", function()
		Enemy.killAll()
		local o = actor()
		local enemy = assert(Enemy.spawn("Brute", 0, -1.2, 100, 0, nil, nil, 0))
		local hp = Enemy.getHealth(enemy)
		for _ = 1, 30 do
			Worm.step(o, {}, 1 / 60)
		end
		expect(Enemy.getHealth(enemy)).toBe(hp)
		Enemy.remove(enemy)
		local tree = assert(Enemy.spawn("Tree", 0, -1.2, 1, 0, nil, nil, 0))
		for _ = 1, 30 do
			Worm.step(o, {}, 1 / 60)
		end
		expect(Enemy.isAlive(tree)).toBe(false)
	end)
	it("deploys a unique gated pet and moves towards a real tree through the production actor world", function()
		Actors.clear()
		Structures.setPaused(true)
		f.start("WatchmanPistol")
		assert(f.Stats.addItem(f.me, "Lootworm"))
		f.nextWave()
		f.Weapons.setPaused(true)
		XP.setPaused(true)
		local row
		for _, value in Structures.getSnapshot() do
			if value.kind == "Lootworm" then
				row = value
			end
		end
		assert(row)
		expect(Structures.petSourceCount(f.me)).toBe(1)
		expect(Structures.sourceCount(f.me)).toBe(0)
		expect(f.Config.Items.byId.Lootworm.limit).toBe(1)
		expect(f.Config.Items.byId.Lootworm.available).toBe(false)
		local tree = assert(Enemy.spawn("Tree", row.x + 20, row.z, 100, 0, nil, nil, 0))
		local hp = Enemy.getHealth(tree)
		Structures.setPaused(false)
		f.world.advance(1.5, 1 / 60)
		expect(Enemy.getHealth(tree) < hp).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
	it("collects physical materials while its owner is down and clears actors and gold on run end", function()
		Structures.setPaused(true)
		f.start("WatchmanPistol")
		assert(f.Stats.addItem(f.me, "Lootworm"))
		f.nextWave()
		f.Weapons.setPaused(true)
		XP.setPaused(false)
		require(f.S.MapService).setMovementCheck(false)
		f.me.Character.HumanoidRootPart.Position = Vector3.new(70, y, 70)
		f.peer.Character.HumanoidRootPart.Position = Vector3.new(-70, y, -70)
		Combat.drainPlayer(f.me, 100000)
		local row
		for _, value in Structures.getSnapshot() do
			if value.kind == "Lootworm" then
				row = value
			end
		end
		assert(row)
		local before = f.Data.get(f.me).nativeCounts.materialsCollected
		XP.dropMaterials(Vector3.new(row.x + 8, y, row.z), 1, 0)
		expect(XP.getOrbCount() > 0).toBe(true)
		Structures.setPaused(false)
		f.world.advance(1, 1 / 60)
		expect(XP.getOrbCount()).toBe(0)
		expect(f.Data.get(f.me).nativeCounts.materialsCollected > before).toBe(true)
		expect(f.Run.getParticipantState(f.me)).toBe("Down")
		f.Run.endRun("Abandoned")
		expect(#Structures.getSnapshot()).toBe(0)
		expect(XP.getOrbCount()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
