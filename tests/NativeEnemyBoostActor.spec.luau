--!strict
-- Source cached boost calculations reach actual hostile/friendly actors using their original integer speed sample.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Random = require(f.S.RandomService)
local Cache = require(f.S.EnemySim.NativeEnemyStatCache)
local Stats = require(f.Shared.Util.EnemyStats)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
local function context()
	return {
		players = {
			{ health = 0, damage = 0, speed = 0, curse = 0, burningSpeed = 0 },
			{ health = 0, damage = 0, speed = 0, curse = 0, burningSpeed = 0 },
		},
		danger = { health = 0, damage = 0, speed = 0 },
		accessibility = { health = 1.125, damage = 1.4, speed = 1.013 },
		endless = 0,
		curseEnabled = true,
	}
end
local boost = { hp = 150, damage = 30, speed = 50 }
local function spawn()
	Enemy.killAll()
	local old = Random.number
	Random.number = function(name, player)
		return if name == "Spawns" then 0.1 else old(name, player)
	end
	local ok, id = pcall(Enemy.spawn, "Triceratops", 20, 0, 1.4625, 1.512, nil, nil, 1.013, 1)
	Random.number = old
	assert(ok, id)
	return assert(id)
end
describe("Native cached boost actor application", function()
	it("retains the source integer speed argument separately from raw and rounded final speeds", function()
		local k = f.Config.Enemies.types.Triceratops
		local factor, raw, original = Stats.spawnSpeedFactor(k, 0.1, 1.013, 1)
		expect(original).toBe(255)
		expect(raw).toBeNear(258.315)
		expect(factor * k.speed / f.Config.Stats.range.studsPerPoint).toBeNear(258)
	end)
	it(
		"captures Nightmare integer random offsets and fixed/stationary source bases without changing legacy samples",
		function()
			local k = f.Config.Enemies.types.HornedFly
			local factor, raw, original = Stats.spawnSpeedFactor(k, 0.137, 0.823, 0.75)
			expect(original).toBe(337) -- 350+int((.137*2-1)*25*.75)
			expect(raw).toBeNear(277.351)
			expect(factor * k.speed / f.Config.Stats.range.studsPerPoint).toBeNear(277)
			local fixed, _, fixedBase = Stats.spawnSpeedFactor(f.Config.Enemies.types.JungleGobbler, 0, 99, 1)
			expect(fixed).toBe(1)
			expect(fixedBase).toBe(350)
			local still, _, stillBase = Stats.spawnSpeedFactor(f.Config.Enemies.types.DinoEgg, 0.5, 99, 1)
			expect(still).toBe(0)
			expect(stillBase).toBe(0)
			local legacy = f.Config.Enemies.types.Brute
			local old, _, oldBase = Stats.spawnSpeedFactor(legacy, 0.137, 0.823, 0.75)
			expect(old).toBeNear(0.823 * Stats.speedFactor(legacy, 0.137))
			expect(oldBase).toBe(nil)
		end
	)
	it("heals and resets the actual actor from cached source factors without double rounding", function()
		local id, cache, ctx = spawn(), Cache.new(), context()
		expect(Enemy.getMaxHealth(id)).toBe(102)
		Enemy.damage(id, 3, nil)
		expect(Enemy.applyNativeBoost(id, cache, ctx, boost)).toBe(true)
		expect(Enemy.getMaxHealth(id)).toBe(256) -- round(70*1.3*1.125*2.5), not round(102*2.5)
		expect(Enemy.getHealth(id)).toBe(256)
		local _, damage, speed = Enemy.getMultipliers(id)
		expect(damage).toBe(2) -- round(1*1.08*1.4*1.3), not round(2*1.3)
		expect(speed * f.Config.Enemies.types.Triceratops.speed / f.Config.Stats.range.studsPerPoint).toBeNear(387)
		ctx.players[1].health = 100
		assert(Enemy.applyNativeBoost(id, cache, ctx, { hp = 0, damage = 0, speed = 0 }))
		expect(Enemy.getHealth(id)).toBe(102) -- cached factor, new modifier; neither fresh team stats nor compounded boost
	end)
	it("applies the same source reset after real Charm conversion without changing owner or position", function()
		local id, cache, ctx = spawn(), Cache.new(), context()
		assert(Enemy.charmSummoned(id, f.me.UserId))
		local before = assert(Enemy.getPosition(id))
		expect(Enemy.applyNativeBoost(id, cache, ctx, boost)).toBe(true)
		expect(Enemy.getHealth(id)).toBe(256)
		expect(Enemy.getMaxHealth(id)).toBe(256)
		expect(Enemy.isCharmed(id)).toBe(true)
		expect(Enemy.getCharmedCount(f.me.UserId)).toBe(1)
		expect(Enemy.getCharmedCount(f.peer.UserId)).toBe(0)
		expect((Enemy.getPosition(id) - before).Magnitude).toBe(0)
	end)
	it("does not touch cache or HP for source boost refusal, dead, absent or unported legacy actors", function()
		Enemy.killAll()
		local cache, ctx = Cache.new(), context()
		local pig = assert(Enemy.spawn("SeaPig", 0, 0, 1, 1, nil, nil, 0, 1))
		expect(Enemy.applyNativeBoost(pig, cache, ctx, boost)).toBe(false)
		expect(Enemy.getHealth(pig)).toBe(30)
		expect(cache.factors.health).toBe(nil)
		expect(Enemy.applyNativeBoost(60000, cache, ctx, boost)).toBe(false)
		local legacy = assert(Enemy.spawn("Shadeling", 0, 0, 1, 1, nil, nil, 0, 1))
		expect(Enemy.applyNativeBoost(legacy, cache, ctx, boost)).toBe(false)
		local id = assert(Enemy.spawn("Triceratops", 0, 0, 1, 1, nil, nil, 0, 1))
		Enemy.damage(id, 1e9, nil)
		expect(Enemy.applyNativeBoost(id, cache, ctx, boost)).toBe(false)
	end)
	it("gives real death descendants updated unboosted global factors instead of the parent's boost", function()
		Enemy.killAll()
		local cache, ctx = Cache.new(), context()
		ctx.accessibility.damage = 2.1
		local parent = assert(Enemy.spawn("BloatedSpawner", 0, 0, 99, 99, nil, nil, 0, 1))
		assert(Enemy.applyNativeBoost(parent, cache, ctx, boost))
		expect(select(2, Enemy.getMultipliers(parent))).toBe(3)
		assert(Enemy.damage(parent, 1e9, f.me))
		local children = {}
		Enemy.collectIds(children)
		expect(#children).toBe(5)
		for _, id in children do
			expect(Enemy.getKind(id)).toBe("DireJunkie")
			expect(Enemy.getHealth(id)).toBe(22) -- round(15*1.3*1.125), no parental hp boost
			expect(select(2, Enemy.getMultipliers(id))).toBe(2) -- round(1*1.08*2.1), not boosted3 or old99
		end
	end)
end)
