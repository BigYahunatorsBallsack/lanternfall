--!strict
-- Actual Silesaurus scene births, boss summons, two original child attacks and second-child speed reset.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Kinds = require(f.Shared.Util.EnemyKinds)
local source = "res://entities/units/enemies/jungle/elites/silesaurus/silesaurus.tscn"
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
	return assert(Enemy.spawn("Silesaurus", 20, 0, 1, 1, nil, nil, 1, 11))
end
describe("Native Silesaurus server", function()
	it("registers the canonical scene and original stats with a native controller", function()
		local kind = assert(Kinds.byNativeScene(source))
		expect(kind.id).toBe("Silesaurus")
		expect(kind.typeId).toBe(73)
		expect(kind.hpPerWave).toBe(750)
		expect(kind.speed).toBe(20)
		expect(kind.boss).toBe(nil)
		expect(kind.elite).toBe(nil)
		assert(kind.nativeBoss and not kind.nativeCanBeBoosted)
	end)
	it("summons two source Enigmacursors through the trusted queue at the real animation method", function()
		clear()
		spawn()
		local children = {}
		local c = Enemy.NativeSummon:Connect(function(name, x, z, owner)
			table.insert(children, { name = name, x = x, z = z, owner = owner })
		end)
		f.world.advance(1.65)
		expect(#children).toBe(0)
		f.world.advance(0.3)
		c:Disconnect()
		expect(#children).toBe(2)
		for _, child in children do
			expect(child.name).toBe("Enigmacursor")
			expect(child.owner).toBe(nil)
			assert(child.x == child.x and child.z == child.z)
		end
	end)
	it("scales boss summon counts with the live team enemy-count stat without a co-op count share", function()
		clear()
		spawn()
		assert(f.Stats.addStats(f.me, { enemyCount = 50 }))
		local count = 0
		local c = Enemy.NativeSummon:Connect(function()
			count += 1
		end)
		f.world.advance(1.95)
		c:Disconnect()
		assert(f.Stats.addStats(f.me, { enemyCount = -50 }))
		expect(count).toBe(3)
	end)
	it("retains at least one summon at the original negative enemy-count boundary", function()
		clear()
		spawn()
		assert(f.Stats.addStats(f.me, { enemyCount = -100 }))
		local count = 0
		local c = Enemy.NativeSummon:Connect(function()
			count += 1
		end)
		f.world.advance(1.95)
		c:Disconnect()
		assert(f.Stats.addStats(f.me, { enemyCount = 100 }))
		expect(count).toBe(1)
	end)
	it("enters the three-bullet phase below85percentHP without the second-child speed boost", function()
		clear()
		local id = spawn()
		Enemy.damage(id, Enemy.getMaxHealth(id) * 0.2, f.me)
		local calls, speed = 0, nil
		local old = Enemy.fireShot
		Enemy.fireShot = function(...)
			local args = { ... }
			calls += 1
			speed = args[5]
			expect(args[8]).toBe(9)
			return old(...)
		end
		local ok, why = pcall(f.world.advance, 2)
		Enemy.fireShot = old
		assert(ok, why)
		assert(calls >= 3 and calls % 3 == 0)
		expect(speed).toBe(85)
		local _, _, factor = Enemy.getMultipliers(id)
		expect(factor).toBe(1)
	end)
	it("enters the four-bullet phase at50percentHP and resets original source speed by75percent", function()
		clear()
		local id = spawn()
		Enemy.damage(id, Enemy.getMaxHealth(id) * 0.51, f.me)
		local calls, speed = 0, nil
		local old = Enemy.fireShot
		Enemy.fireShot = function(...)
			local args = { ... }
			calls += 1
			speed = args[5]
			return old(...)
		end
		local ok, why = pcall(f.world.advance, 3)
		Enemy.fireShot = old
		assert(ok, why)
		assert(calls >= 4 and calls % 4 == 0)
		expect(speed).toBe(65)
		local _, _, factor = Enemy.getMultipliers(id)
		expect(factor).toBe(1.75)
	end)
	it(
		"rounds the phase speed from the original source argument, rather than multiplying an already rounded speed",
		function()
			clear()
			local id = assert(Enemy.spawn("Silesaurus", 20, 0, 1, 1, nil, nil, 0.5027, 11))
			local _, _, initial = Enemy.getMultipliers(id)
			expect(initial * 200).toBeNear(101)
			Enemy.damage(id, Enemy.getMaxHealth(id) * 0.51, f.me)
			f.world.advance(1.1)
			local _, _, boosted = Enemy.getMultipliers(id)
			expect(boosted * 200).toBeNear(176) -- round(200*.5027*1.75), not round(101*1.75)=177
		end
	)
	it("creates real ordinary child bodies from the summon queue with their own native run factors", function()
		clear()
		spawn()
		local Director = require(f.S.SpawnDirector)
		Director.setPaused(false)
		local ok, why = pcall(f.world.advance, 3.4)
		Director.setPaused(true)
		assert(ok, why)
		local ids = {}
		Enemy.queryRadius(Vector3.zero, 10000, ids)
		local found = 0
		for _, id in ids do
			local name = Enemy.getKind(id)
			if name == "Enigmacursor" then
				found += 1
				local kind = assert(Kinds.get(name))
				expect(Enemy.getMaxHealth(id)).toBe(math.round(kind.hp * 1.3))
			end
		end
		expect(found).toBe(2)
	end)
end)
