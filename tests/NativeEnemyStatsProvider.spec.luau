--!strict
-- Live source context captures real run/player stats once per wave and drives native births, Buffer resets and descendants.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Spawn = require(f.S.SpawnDirector)
local Combat = require(f.S.CombatService)
local function provider()
	return require(f.S.EnemySim.NativeEnemyStats)
end
local function start(options)
	if options then
		if f.Run.isOngoing() then
			f.Run.endRun("Abandoned")
		end
		if f.Run.getPhase() == "Ended" then
			f.world.advance(f.Config.Run.flow.resultsSeconds + 0.1)
		end
		assert(f.Data.unlockAll(f.peer))
		assert(f.Run.selectClass(f.me, "NightWatch"))
		assert(f.Weapons.selectStartWeapon(f.me, "NightWatch", "WatchmanPistol"))
		assert(f.Run.launch({ f.me, f.peer }, options))
		f.world.advance(f.Config.Run.flow.allReadyCountdownSeconds + 0.5)
		Spawn.setPaused(true)
	else
		f.start("WatchmanPistol")
	end
	f.Weapons.setPaused(true)
	require(f.S.MapService).setMovementCheck(false)
	for _, player in { f.me, f.peer } do
		Combat.protect(player, 10000)
	end
	Enemy.killAll()
end
local function modifiers()
	assert(f.Stats.addStats(f.me, { enemyHp = 50, enemyDamage = 20, enemySpeed = 10, curse = 100 }))
	assert(f.Stats.addStats(f.peer, { enemySpeed = -20 }))
end
describe("Native live enemy stat provider", function()
	it("reads actual danger and distinct accessibility sliders through a real run launch", function()
		local options = require(f.Shared.Util.DangerRules).defaultOptions()
		options.danger, options.enemyHp, options.enemyDamage, options.enemySpeed = 3, 75, 125, 75
		start(options)
		local cache, ctx = provider().get(f.Run.getWave())
		expect(cache:rawHealth(1, ctx)).toBeNear(1.092)
		expect(cache:rawDamage(1, ctx)).toBeNear(1.512)
		expect(cache:rawSpeed(1, false, ctx)).toBeNear(0.75)
		local random = require(f.S.RandomService)
		local original = random.number
		random.number = function(name, player)
			return if name == "Spawns" then 0.1 else original(name, player)
		end
		local ok, id = pcall(Spawn.spawnAt, "Triceratops", 20, 0)
		random.number = original
		assert(ok, id)
		expect(Enemy.getMaxHealth(id)).toBe(76)
		expect(select(2, Enemy.getMultipliers(id))).toBe(2)
		expect(
			select(3, Enemy.getMultipliers(id))
				* f.Config.Enemies.types.Triceratops.speed
				/ f.Config.Stats.range.studsPerPoint
		).toBeNear(195)
	end)
	it("captures actual player/run values and retains all three first-use factors until clear", function()
		start()
		modifiers()
		local p = provider()
		p.clear()
		local cache, ctx = p.get(f.Run.getWave())
		expect(#ctx.players).toBe(2)
		expect(cache:rawHealth(1, ctx)).toBeNear(1.95)
		expect(cache:rawDamage(1, ctx)).toBeNear(1.296)
		expect(cache:rawSpeed(1, false, ctx)).toBeNear(0.88)
		assert(f.Stats.addStats(f.me, { enemyHp = 100 }))
		local same, snapshot = p.get(f.Run.getWave())
		expect(same).toBe(cache)
		expect(snapshot).toBe(ctx)
		expect(same:rawHealth(1, snapshot)).toBeNear(1.95)
		p.clear()
		local fresh, newctx = p.get(f.Run.getWave())
		expect(fresh:rawHealth(1, newctx)).toBeNear(3.25)
	end)
	it(
		"uses source per-player speed products and .01 minima for actual births while preserving explicit debug multipliers",
		function()
			start()
			modifiers()
			provider().clear()
			local random = require(f.S.RandomService)
			local original = random.number
			random.number = function(name, player)
				return if name == "Spawns" then 0.5 else original(name, player)
			end
			local ok, id = pcall(Enemy.spawnNative, "Gallimimus", 20, 0)
			random.number = original
			assert(ok, id)
			id = assert(id)
			expect(Enemy.getMaxHealth(id)).toBe(8)
			expect(
				select(3, Enemy.getMultipliers(id))
					* f.Config.Enemies.types.Gallimimus.speed
					/ f.Config.Stats.range.studsPerPoint
			).toBeNear(220)
			assert(f.Stats.addStats(f.me, { enemyHp = -145 })) -- total-95; source .05, not legacy minimum.1
			provider().clear()
			local tiny = assert(Enemy.spawnNative("Triceratops", 30, 0))
			expect(Enemy.getMaxHealth(tiny)).toBe(5)
			local debug = assert(Enemy.spawn("Gallimimus", 40, 0, 99, 99, nil, nil, 0, 1))
			expect(Enemy.getMaxHealth(debug)).toBe(396)
		end
	)
	it("routes the existing SpawnDirector producer through source native factors", function()
		start()
		modifiers()
		provider().clear()
		local original, calls = Enemy.spawnNative, 0
		Enemy.spawnNative = function(...)
			calls += 1
			return original(...)
		end
		local ok, id = pcall(Spawn.spawnAt, "Gallimimus", 20, 0)
		Enemy.spawnNative = original
		assert(ok, id)
		expect(calls).toBe(1)
		expect(Enemy.getMaxHealth(assert(id))).toBe(8)
	end)
	it("uses the shared cached actor command for a real Corrupted Buffer pulse", function()
		start()
		modifiers()
		provider().clear()
		local id = assert(Enemy.spawnNative("Gallimimus", 2, 0))
		assert(f.Stats.addStats(f.me, { enemyHp = 100 }))
		assert(Enemy.spawnNative("CorruptedBuffer", 0, 0))
		local original, calls = Enemy.applyNativeBoost, 0
		Enemy.applyNativeBoost = function(...)
			calls += 1
			return original(...)
		end
		f.world.advance(0.3, 1 / 60)
		Enemy.applyNativeBoost = original
		expect(calls).toBe(1)
		expect(Enemy.getMaxHealth(id)).toBe(20) -- cached1.95, not changed3.25
		expect(Enemy.getHealth(id)).toBe(20)
		expect(select(2, Enemy.getMultipliers(id))).toBe(2)
	end)
	it("resets through actual wave and run transitions including the same wave number in a new run", function()
		start()
		assert(f.Stats.addStats(f.me, { enemyHp = 50 }))
		provider().clear()
		local first = assert(Enemy.spawnNative("Gallimimus", 20, 0))
		expect(Enemy.getMaxHealth(first)).toBe(8)
		assert(f.Stats.addStats(f.me, { enemyHp = 50 }))
		f.nextWave()
		local nextid = assert(Enemy.spawnNative("Gallimimus", 20, 0))
		expect(f.Run.getWave()).toBe(2)
		expect(Enemy.getMaxHealth(nextid)).toBe(16) -- int(6.5)*1.3*2
		start()
		expect(f.Run.getWave()).toBe(1)
		local restart = assert(Enemy.spawnNative("Gallimimus", 20, 0))
		expect(Enemy.getMaxHealth(restart)).toBe(5) -- fresh run, no old+100% enemyHp
	end)
	it("propagates source birth policy to real death children without parental boost leakage", function()
		start()
		provider().clear()
		local parent = assert(Enemy.spawnNative("BloatedSpawner", 0, 0))
		local cache, ctx = provider().get(f.Run.getWave())
		assert(Enemy.applyNativeBoost(parent, cache, ctx, { hp = 150, damage = 30, speed = 50 }))
		local original, calls = Enemy.spawnNative, 0
		Enemy.spawnNative = function(...)
			calls += 1
			return original(...)
		end
		Enemy.damage(parent, 1e9, f.me)
		Enemy.spawnNative = original
		expect(calls).toBe(5)
		local ids = {}
		Enemy.collectIds(ids)
		expect(#ids).toBe(5)
		for _, id in ids do
			expect(Enemy.getHealth(id)).toBe(20)
		end
	end)
	it("invalidates the cache on the repeated-wave phase signal even with the same wave number", function()
		start()
		modifiers()
		provider().clear()
		local first = assert(Enemy.spawnNative("Gallimimus", 20, 0))
		expect(Enemy.getMaxHealth(first)).toBe(8)
		assert(f.Stats.addStats(f.me, { enemyHp = 50 }))
		local wave = f.Run.getWave()
		f.Run.PhaseChanged:Fire("Running") -- service contract used when restarting the same wave
		expect(f.Run.getWave()).toBe(wave)
		local second = assert(Enemy.spawnNative("Gallimimus", 30, 0))
		expect(Enemy.getMaxHealth(second)).toBe(10)
	end)
end)
