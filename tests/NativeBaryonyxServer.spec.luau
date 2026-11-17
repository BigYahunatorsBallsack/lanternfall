--!strict
-- Concrete normal Baryonyx uses independent source bullet/laser damage and freezes during shoot/recovery; laser instances retain source translation and death policy.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Kinds = require(f.Shared.Util.EnemyKinds)
local Laser = require(f.S.NativeLaserService)
local source = "res://entities/units/enemies/jungle/elites/baryonyx/baryonyx_neutral.tscn"
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.CombatService).protect(f.me, 10000)
require(f.S.CombatService).protect(f.peer, 10000)
local function clear()
	Enemy.killAll()
	f.world.advance(1.3)
	Enemy.killAll()
end
local function spawn()
	return assert(Enemy.spawn("Baryonyx", 50, 0, 1, 1, nil, nil, 1, 11))
end
describe("Native Baryonyx server", function()
	it("registers the normal source scene with original stats and explicit boost eligibility", function()
		local kind = assert(Kinds.byNativeScene(source))
		expect(kind.typeId).toBe(75)
		expect(kind.hpPerWave).toBe(500)
		expect(kind.nativeCanBeBoosted).toBe(true)
		expect(kind.nativeBoss.initialWrapperFrames).toBe(1)
	end)
	it("emits thirteen normal bullets with damage from late root registration", function()
		clear()
		spawn()
		local calls = 0
		local old = Enemy.fireShot
		Enemy.fireShot = function(...)
			local args = { ... }
			calls += 1
			expect(args[5]).toBe(35)
			expect(args[8]).toBe(12)
			return old(...)
		end
		local ok, why = pcall(f.world.advance, 0.7)
		Enemy.fireShot = old
		assert(ok, why)
		expect(calls).toBe(13)
	end)
	it("holds its actual world position during the shooting recovery without replacing its speed", function()
		clear()
		local id = spawn()
		f.world.advance(0.5)
		local at = Enemy.getPosition(id)
		local _, _, speed = Enemy.getMultipliers(id)
		f.world.advance(0.2)
		expect(Enemy.getPosition(id)).toBe(at)
		local _, _, after = Enemy.getMultipliers(id)
		expect(after).toBe(speed)
	end)
	it("switches at halfHP to parallel centered lasers with their own early-reduced damage", function()
		clear()
		local id = spawn()
		Enemy.damage(id, Enemy.getMaxHealth(id) * 0.51, f.me)
		local positions = {}
		local c = Enemy.NativeLaser:Connect(function(who, x, z, _, _, damage)
			if who == id then
				expect(damage).toBe(10)
				table.insert(positions, Vector3.new(x, 0, z))
			end
		end)
		f.world.advance(4.5)
		c:Disconnect()
		expect(#positions).toBe(2)
		expect((positions[1] - positions[2]).Magnitude).toBeNear(15)
	end)
	it("delays actual hostile damage, follows source translation and survives source death", function()
		clear()
		local id = spawn()
		Enemy.setSpeedFactor(id, 0)
		local at = assert(Enemy.getPlayerHurtGeometry(f.me))
		Enemy.NativeLaser:Fire(id, at.X, at.Z + 20, 1, 0, 77)
		Enemy.teleport(id, Vector3.new(60, 0, -20))
		Enemy.damage(id, math.huge, f.me)
		local hits = 0
		local c = Enemy.ShotHit:Connect(function(player, damage)
			if player == f.me and damage == 77 then
				hits += 1
			end
		end)
		f.world.advance(0.6)
		expect(hits).toBe(0)
		f.world.advance(0.3)
		c:Disconnect()
		expect(hits).toBe(1)
		expect(Laser.getCount()).toBe(0)
	end)
	it("never credits a newly emitted beam with time from before its birth in the server batch", function()
		clear()
		local id = spawn()
		Enemy.damage(id, Enemy.getMaxHealth(id) * 0.51, f.me)
		local born, hit
		local c = Enemy.NativeLaser:Connect(function(who, _, _, _, _, damage)
			if who == id and damage == 10 and not born then
				born = workspace:GetServerTimeNow()
				local at = Enemy.getPlayerHurtGeometry(f.me)
				Enemy.NativeLaser:Fire(id, at.X, at.Z, 1, 0, 99)
			end
		end)
		local d = Enemy.ShotHit:Connect(function(player, damage)
			if player == f.me and damage == 99 then
				hit = workspace:GetServerTimeNow()
			end
		end)
		f.world.advance(5.5, 1 / 120)
		c:Disconnect()
		d:Disconnect()
		assert(born and hit)
		assert(hit - born >= 0.75 - 1e-9, `Laser hit after only {hit - born} seconds`)
	end)
	it(
		"recomputes both registered attacks through the real boost provider rather than scaling rounded old damage",
		function()
			clear()
			local id = spawn()
			f.world.advance(0.1) -- normal behavior is registered before this later reset
			local cache, context = require(f.S.EnemySim.NativeEnemyStats).get(f.Run.getWave())
			assert(Enemy.applyNativeBoost(id, cache, context, { hp = 100, damage = 50, speed = 0 }))
			local values = {}
			local old = Enemy.fireShot
			Enemy.fireShot = function(...)
				local args = { ... }
				table.insert(values, args[8])
				return old(...)
			end
			local ok, why = pcall(f.world.advance, 0.6)
			Enemy.fireShot = old
			assert(ok, why)
			expect(#values).toBe(13)
			for _, value in values do
				expect(value).toBe(cache:damage(2, 50, context))
			end
			Enemy.damage(id, Enemy.getMaxHealth(id) * 0.51, f.me)
			local lasers = {}
			local c = Enemy.NativeLaser:Connect(function(who, _, _, _, _, damage)
				if who == id then
					table.insert(lasers, damage)
				end
			end)
			f.world.advance(4.5)
			c:Disconnect()
			expect(#lasers).toBe(2)
			for _, value in lasers do
				expect(value).toBe(cache:damage(3, 50, context))
			end
		end
	)
	it("follows a living source's translation while keeping the beam direction fixed", function()
		clear()
		local id = spawn()
		Enemy.setSpeedFactor(id, 0)
		local at = Enemy.getPlayerHurtGeometry(f.me)
		Enemy.NativeLaser:Fire(id, at.X, at.Z + 20, 1, 0, 88)
		Enemy.teleport(id, Vector3.new(60, 0, -20))
		local hits = 0
		local c = Enemy.ShotHit:Connect(function(player, damage)
			if player == f.me and damage == 88 then
				hits += 1
			end
		end)
		f.world.advance(0.9)
		c:Disconnect()
		expect(hits).toBe(1)
	end)
	it(
		"registers the first normal behavior after a pre-physics boost without retaining that earlier modifier",
		function()
			clear()
			local id = assert(Enemy.spawnNativeScene(source, 50, 0))
			local cache, context = require(f.S.EnemySim.NativeEnemyStats).get(f.Run.getWave())
			assert(Enemy.applyNativeBoost(id, cache, context, { hp = 100, damage = 50, speed = 0 }))
			local values = {}
			local old = Enemy.fireShot
			Enemy.fireShot = function(...)
				local args = { ... }
				table.insert(values, args[8])
				return old(...)
			end
			local ok, why = pcall(f.world.advance, 0.6)
			Enemy.fireShot = old
			assert(ok, why)
			expect(#values).toBe(13)
			for _, value in values do
				expect(value).toBe(cache:damage(2, 0, context))
			end
		end
	)
end)
