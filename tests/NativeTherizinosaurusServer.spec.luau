--!strict
-- Actual source elite births follow, emit normal slashes, switch to independent circle bullets and retain canonical boss kill/loot policy.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Kinds = require(f.Shared.Util.EnemyKinds)
local Slash = require(f.S.NativeSlashService)
local source = "res://entities/units/enemies/jungle/elites/therizinosaurus/therizinosaurus.tscn"
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
	return assert(Enemy.spawn("Therizinosaurus", 20, 0, 1, 1, nil, nil, 1, 11))
end
describe("Native Therizinosaurus server", function()
	it("registers the exact source scene as a separate native champion controller", function()
		local kind = assert(Kinds.byNativeScene(source))
		expect(kind.id).toBe("Therizinosaurus")
		expect(kind.typeId).toBe(72)
		expect(kind.hp).toBe(1)
		expect(kind.hpPerWave).toBe(550)
		expect(kind.speed).toBe(25)
		expect(kind.damagePerWave).toBe(1.5)
		expect(kind.shotDamagePerWave).toBe(1.15)
		expect(kind.nativeCanBeBoosted).toBe(false)
		expect(kind.elite).toBe(nil) -- this flag is the generated Gloom variant, not the source champion role
		assert(kind.nativeBoss)
	end)
	it("applies original early boss health after global rounding, independently of shot damage", function()
		clear()
		local id = spawn()
		expect(Enemy.getMaxHealth(id)).toBe(4126) -- round((1+550*10)*.75)
		local _, elite = Enemy.getKind(id)
		expect(elite).toBe(true)
		local native = assert(Enemy.spawnNativeScene(source, 40, 0))
		expect(Enemy.getMaxHealth(native)).toBe(1) -- round(round(1*1.3)*.5)
		local fractional = assert(Enemy.spawn("Therizinosaurus", 40, 0, 620.6 / 551, 1, nil, nil, 1, 2))
		expect(Enemy.getMaxHealth(fractional)).toBe(311) -- round(round(620.6)*.5), not310
	end)
	it("moves the actual actor towards a living player and fires the root normal-slash path", function()
		clear()
		local id = spawn()
		local before = Enemy.getPosition(id)
		local calls, direct
		calls = 0
		local c = Enemy.NativeSlash:Connect(function(who, _, _, damage, _, details)
			if who == id then
				calls += 1
				direct = details
				expect(damage).toBe(9)
			end
		end)
		f.world.advance(0.75)
		c:Disconnect()
		assert(Enemy.getPosition(id) ~= before)
		assert(calls > 0 and direct and direct.profile == "Normal")
		assert(Slash.getCount() > 0)
	end)
	it("switches the real actor to ordinary twelve-bullet volleys after crossing45percentHP", function()
		clear()
		local id = spawn()
		Enemy.damage(id, Enemy.getMaxHealth(id) * 0.6, f.me)
		local slashes, shots = 0, 0
		local c = Enemy.NativeSlash:Connect(function(who)
			if who == id then
				slashes += 1
			end
		end)
		local old = Enemy.fireShot
		Enemy.fireShot = function(...)
			shots += 1
			local args = { ... }
			expect(args[8]).toBe(9)
			return old(...)
		end
		local ok, why = pcall(f.world.advance, 3)
		Enemy.fireShot = old
		c:Disconnect()
		assert(ok, why)
		assert(shots >= 12 and shots % 12 == 0)
		assert(slashes < shots)
	end)
	it("keeps normal source slashes alive after their owner dies", function()
		clear()
		local id = spawn()
		Enemy.NativeSlash:Fire(id, 80, 80, 9, nil, { dx = 1, dz = 0, speed = 50, profile = "Normal" })
		local count = Slash.getCount()
		assert(count > 0)
		Enemy.damage(id, math.huge, f.me)
		f.world.advance(0.1)
		expect(Slash.getCount()).toBe(count)
	end)
	it("carries the normal source slash through the actual hostile collision and player damage signal", function()
		clear()
		local Shared = f.Shared
		local C = require(Shared.Config.NightmareEnemies).slash
		f.world.advance(C.stopAt + 0.1)
		expect(Slash.getCount()).toBe(0)
		local id = spawn()
		local at = assert(Enemy.getPlayerHurtGeometry(f.me))
		local geometry = require(Shared.Util.NativeSlashGeometry)
		local x, z = geometry.rectangle(
			{ x = 0, z = 0, dx = 1, dz = 0, speed = 50 },
			C.hitFrom + 0.01,
			f.Config.Stats.range.studsPerPoint
		)
		local hits = 0
		local c = Enemy.ShotHit:Connect(function(player, damage)
			if player == f.me then
				hits += 1
				expect(damage).toBe(9)
			end
		end)
		Enemy.NativeSlash:Fire(id, at.X - x, at.Z - z, 9, nil, { dx = 1, dz = 0, speed = 50, profile = "Normal" })
		f.world.advance(C.hitFrom + 0.06)
		c:Disconnect()
		assert(hits > 0)
	end)
	it("reports canonical champion death metadata and clears timed attacks after cleanup", function()
		clear()
		local id, info = spawn(), nil
		local c = Enemy.EnemyKilled:Connect(function(kill)
			if kill.id == id then
				info = kill
			end
		end)
		Enemy.damage(id, math.huge, f.me)
		c:Disconnect()
		assert(info and info.boss)
		expect(info.elite).toBe(false) -- canonical champion, never a generated Gloom actor
		expect(info.typeId).toBe(72)
		expect(info.xp).toBe(10)
		local shots, old = 0, Enemy.fireShot
		Enemy.fireShot = function(...)
			shots += 1
			return old(...)
		end
		local ok, why = pcall(f.world.advance, 3)
		Enemy.fireShot = old
		assert(ok, why)
		expect(shots).toBe(0)
	end)
	it("applies the real accessibility projectile-speed slider without adding team enemy-speed effects", function()
		f.Run.endRun("Abandoned")
		f.world.advance(f.Config.Run.flow.resultsSeconds + 0.1)
		f.Data.unlockAll(f.peer)
		assert(f.Run.selectClass(f.me, "NightWatch"))
		assert(f.Weapons.selectStartWeapon(f.me, "NightWatch", "WatchmanPistol"))
		local options = require(f.Shared.Util.DangerRules).defaultOptions()
		options.enemySpeed = 75
		assert(f.Run.launch({ f.me, f.peer }, options))
		f.world.advance(f.Config.Run.flow.allReadyCountdownSeconds + 0.5)
		require(f.S.SpawnDirector).setPaused(true)
		f.Weapons.setPaused(true)
		require(f.S.CombatService).protect(f.me, 10000)
		require(f.S.CombatService).protect(f.peer, 10000)
		assert(f.Stats.addStats(f.me, { enemySpeed = -20 }))
		local provider = require(f.S.EnemySim.NativeEnemyStats)
		provider.clear() -- source factors must capture the new team effect, not an earlier unrelated birth
		local cache, context = provider.get(f.Run.getWave())
		expect(cache:rawSpeed(1, false, context)).toBeNear(0.6)
		clear()
		local id, speeds = assert(Enemy.spawnNativeScene(source, 20, 0)), {}
		local c = Enemy.NativeSlash:Connect(function(who, _, _, _, _, direct)
			if who == id then
				table.insert(speeds, direct.speed)
			end
		end)
		f.world.advance(0.75)
		c:Disconnect()
		assert(#speeds > 0)
		for _, speed in speeds do
			expect(speed).toBeNear(37.5)
		end
	end)
end)
