--!strict
-- Concrete normal Diplodocus spawns real Alamosaurus children, then emits eight source normal slashes with independent timing.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Kinds = require(f.Shared.Util.EnemyKinds)
local source = "res://entities/units/enemies/jungle/elites/diplodocus/diplodocus.tscn"
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.CombatService).protect(f.me, 10000)
require(f.S.CombatService).protect(f.peer, 10000)
local function clear()
	Enemy.killAll()
	f.world.advance(0.1)
	Enemy.killAll()
end
local function spawn()
	return assert(Enemy.spawn("Diplodocus", 20, 0, 1, 1, nil, nil, 1, 11))
end
describe("Native Diplodocus server", function()
	it("registers its exact scene as a separate champion with original units and a finite spawn profile", function()
		local kind = assert(Kinds.byNativeScene(source))
		expect(kind.id).toBe("Diplodocus")
		expect(kind.typeId).toBe(74)
		expect(kind.hpPerWave).toBe(750)
		expect(kind.speed).toBe(25)
		expect(kind.nativeBoss.shooting.profiles[1].spawnLimit).toBe(999)
		expect(kind.elite).toBe(nil)
	end)
	it("moves towards a player and requests Alamosaurus after the source cooldown and method windup", function()
		clear()
		local id = spawn()
		local before = Enemy.getPosition(id)
		local children = {}
		local c = Enemy.NativeSummon:Connect(function(name)
			table.insert(children, name)
		end)
		f.world.advance(3.2)
		expect(#children).toBe(0)
		f.world.advance(0.6)
		c:Disconnect()
		expect(children[1]).toBe("Alamosaurus")
		expect(#children).toBe(1)
		assert(Enemy.getPosition(id) ~= before)
	end)
	it("switches at halfHP and emits the actual eight normal slashes at80studs/s", function()
		clear()
		local id = spawn()
		Enemy.damage(id, Enemy.getMaxHealth(id) * 0.51, f.me)
		local slashes = 0
		local c = Enemy.NativeSlash:Connect(function(who, _, _, damage, _, direct)
			if who == id then
				slashes += 1
				expect(damage).toBe(9)
				expect(direct.profile).toBe("Normal")
				expect(direct.speed).toBe(80)
			end
		end)
		f.world.advance(3)
		c:Disconnect()
		assert(slashes >= 8 and slashes % 8 == 0)
	end)
	it("creates real ordinary Alamosaurus children from the existing source birth queue", function()
		clear()
		spawn()
		local Director = require(f.S.SpawnDirector)
		Director.setPaused(false)
		-- The parent reaches the player before spawning; an overlapping child marker restarts at a new arena point.
		local ok, why = pcall(f.world.advance, 6.4)
		Director.setPaused(true)
		assert(ok, why)
		local ids = {}
		Enemy.queryRadius(Vector3.zero, 10000, ids)
		local found = 0
		for _, id in ids do
			if Enemy.getKind(id) == "Alamosaurus" then
				found += 1
				expect(Enemy.getMaxHealth(id)).toBe(math.round(Kinds.get("Alamosaurus").hp * 1.3))
			end
		end
		expect(found).toBe(1)
	end)
	it("counts all requested children past999 even when the paused director creates no bodies", function()
		clear()
		spawn()
		assert(f.Stats.addStats(f.me, { enemyCount = 99900 }))
		local count = 0
		local c = Enemy.NativeSummon:Connect(function(name)
			if name == "Alamosaurus" then
				count += 1
			end
		end)
		local ok, why = pcall(f.world.advance, 8)
		c:Disconnect()
		assert(f.Stats.addStats(f.me, { enemyCount = -99900 }))
		assert(ok, why)
		expect(count).toBe(1000) -- whole first batch is allowed; second batch is blocked by the child counter
	end)
	it("reports original boss HP and canonical death identity while removing the private attack timer", function()
		clear()
		local id = spawn()
		expect(Enemy.getMaxHealth(id)).toBe(5626)
		local info
		local c = Enemy.EnemyKilled:Connect(function(kill)
			if kill.id == id then
				info = kill
			end
		end)
		Enemy.damage(id, math.huge, f.me)
		c:Disconnect()
		assert(info and info.boss and not info.elite)
		expect(info.typeId).toBe(74)
		expect(info.xp).toBe(10)
		local count = 0
		c = Enemy.NativeSummon:Connect(function()
			count += 1
		end)
		f.world.advance(4)
		c:Disconnect()
		expect(count).toBe(0)
	end)
end)
