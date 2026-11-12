--!strict
-- Corrupted Buffer boosts two eligible enemies and, after Charm, two distinct allies using the original source overrides.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Combat = require(f.S.CombatService)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
for _, player in { f.me, f.peer } do
	Combat.protect(player, 1000)
end
local function clear()
	Enemy.killAll()
	f.world.advance(0.1)
	Enemy.killAll()
end
describe("Native Corrupted Buffer", function()
	it("has a two-target source pulse and never boosts itself or other buffers", function()
		local kind = f.Config.Enemies.types.CorruptedBuffer
		expect(kind ~= nil).toBe(true)
		expect(kind.pulse.buffCount).toBe(2)
		expect(kind.pulse.buffDamage).toBe(1.3)
		expect(kind.pulse.buffHp).toBe(1.5)
		expect(kind.pulse.buffSpeed).toBe(1.5)
	end)
	it("permanently boosts precisely two eligible enemies at its first pulse", function()
		clear()
		Enemy.spawn("CorruptedBuffer", 0, 0, 1, 1, nil, nil, 0, 1)
		local ids = {}
		for index = 1, 3 do
			table.insert(ids, assert(Enemy.spawn("Shadeling", index, 0, 1, 1, nil, nil, 0, 1)))
		end
		f.world.advance(0.3)
		local boosted = 0
		for _, id in ids do
			if Enemy.getMaxHealth(id) > 3 then
				boosted += 1
				expect(Enemy.getMaxHealth(id)).toBe(8)
				local _, damage = Enemy.getMultipliers(id)
				expect(damage).toBe(1)
			end
		end
		expect(boosted).toBe(2)
		f.world.advance(4.1)
		for _, id in ids do
			expect(Enemy.getMaxHealth(id)).toBe(8)
		end
	end)
	it("recalculates source integer bases before multipliers and fully heals the selected enemy", function()
		clear()
		Enemy.spawn("CorruptedBuffer", 0, 0, 1, 1, nil, nil, 0, 1)
		local id = assert(Enemy.spawn("Charger", 2, 0, 2, 3, nil, nil, 0, 2))
		Enemy.damage(id, 1, nil)
		f.world.advance(0.3)
		expect(Enemy.getMaxHealth(id)).toBe(30) -- int(4+2.5) *2 *2.5
		expect(Enemy.getHealth(id)).toBe(30)
		local _, damage = Enemy.getMultipliers(id)
		expect(damage).toBe(4) -- round(int(1+.85)*3*1.3)
	end)

	it("boosts both nearby players after Charm and expires their temporary stats", function()
		clear()
		f.me.Character.HumanoidRootPart.Position = Vector3.new(0, 100, 0)
		f.peer.Character.HumanoidRootPart.Position = Vector3.new(2, 100, 0)
		local before = {}
		for _, player in { f.me, f.peer } do
			before[player] = select(2, Combat.getHp(player))
			Combat.protect(player, 100)
		end
		local id = assert(Enemy.spawn("CorruptedBuffer", 0, 0, 100, 0, nil, nil, 0, 1))
		Enemy.damage(id, 1, nil)
		expect(Enemy.tryCharm(f.me, id, { charmChance = 1, charmThreshold = 1 }, function()
			return 0
		end)).toBe(true)
		f.world.advance(0.3)
		for _, player in { f.me, f.peer } do
			expect(f.Stats.getStat(player, "speed")).toBe(20)
			expect(select(2, Combat.getHp(player))).toBe(before[player] + math.floor(before[player] * 0.2))
		end
		f.world.advance(5.1)
		for _, player in { f.me, f.peer } do
			expect(f.Stats.getStat(player, "speed")).toBe(0)
		end
		expect(#f.world.errors).toBe(0)
	end)
	it("selects two distinct targets from a mixed player and structure pool", function()
		clear()
		local Structures = require(f.S.StructureService)
		assert(f.Stats.addItem(f.me, "BrassSentry"))
		f.nextWave()
		f.Weapons.setPaused(true)
		local turret = assert(Structures.getSnapshot()[1])
		f.me.Character.HumanoidRootPart.Position = Vector3.new(turret.x, 100, turret.z)
		f.peer.Character.HumanoidRootPart.Position = Vector3.new(90, 100, 60)
		local id = assert(Enemy.spawn("CorruptedBuffer", turret.x, turret.z, 100, 0, nil, nil, 0, 1))
		Enemy.damage(id, 1, nil)
		assert(Enemy.tryCharm(f.me, id, { charmChance = 1, charmThreshold = 1 }, function()
			return 0
		end))
		local original = Structures.applyBoost
		local applied = 0
		Structures.applyBoost = function(target, damage, range, speed, duration)
			expect(target).toBe(turret.id)
			expect(damage).toBe(20)
			expect(range).toBe(20)
			expect(speed).toBe(20)
			expect(duration).toBe(5)
			applied += 1
			return original(target, damage, range, speed, duration)
		end
		f.world.advance(0.3)
		Structures.applyBoost = original
		expect(applied).toBe(1)
		expect(f.Stats.getStat(f.me, "speed")).toBe(20)
		expect(f.Stats.getStat(f.peer, "speed")).toBe(0)
		expect(Structures.sourceCount(f.me)).toBe(1)
		expect(#f.world.errors).toBe(0)
	end)
end)
