--!strict
-- Actual Carnotaurus cold jump, landing ring, landed-only timer phase and source-linked child projectile death policy.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Kinds = require(f.Shared.Util.EnemyKinds)
local source = "res://entities/units/enemies/jungle/elites/carnotaurus/carnotaurus_neutral.tscn"
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
	return assert(Enemy.spawn("Carnotaurus", 50, 0, 1, 1, nil, nil, 1, 11))
end
describe("Native Carnotaurus server", function()
	it("registers the concrete source scene with custom timer and original jump units", function()
		local kind = assert(Kinds.byNativeScene(source))
		expect(kind.typeId).toBe(76)
		expect(kind.hpPerWave).toBe(750)
		expect(kind.nativeJump.height).toBe(15)
		expect(kind.nativeBoss.init.timerSeconds).toBe(20)
		expect(kind.nativeBoss.phases.usesBasePhaseTimer).toBe(false)
	end)
	it("starts a real cold jump while retaining its hurtbox and disabling airborne contact", function()
		clear()
		local id = spawn()
		local jumps, contacts = 0, 0
		local c = Enemy.NativeJumpStarted:Connect(function(who)
			if who == id then
				jumps += 1
			end
		end)
		local d = Enemy.Contact:Connect(function(_, _, who)
			if who == id then
				contacts += 1
			end
		end)
		f.world.advance(0.9)
		c:Disconnect()
		d:Disconnect()
		expect(jumps).toBe(1)
		expect(contacts).toBe(0)
		expect(Enemy.isHurtEnabled(id)).toBe(true)
		assert(Enemy.getPosition(id).Z < 0)
	end)
	it("fires fourteen ordinary landing bullets without using the unused50damage/radius exports", function()
		clear()
		spawn()
		local calls = 0
		local old = Enemy.fireShot
		Enemy.fireShot = function(...)
			local args = { ... }
			calls += 1
			expect(args[5]).toBe(40)
			expect(args[8]).toBe(9)
			expect(args[10]).toBe(nil)
			return old(...)
		end
		local ok, why = pcall(f.world.advance, 2.3)
		Enemy.fireShot = old
		assert(ok, why)
		expect(calls).toBe(14)
	end)
	it("ignores low HP until the custom timer and continues its original jumping behavior", function()
		clear()
		local id = spawn()
		Enemy.damage(id, Enemy.getMaxHealth(id) * 0.8, f.me)
		local jumps, linked = 0, 0
		local old = Enemy.fireShot
		local c = Enemy.NativeJumpStarted:Connect(function(who)
			if who == id then
				jumps += 1
			end
		end)
		Enemy.fireShot = function(...)
			local args = { ... }
			if args[10] == id then
				linked += 1
			end
			return old(...)
		end
		local ok, why = pcall(f.world.advance, 5.3)
		Enemy.fireShot = old
		c:Disconnect()
		assert(ok, why)
		assert(jumps >= 2)
		expect(linked).toBe(0)
	end)
	it(
		"waits for a landing after the timer, emits twelve child bullets, and deletes only their source links on death",
		function()
			clear()
			local id = spawn()
			local linked = 0
			local old = Enemy.fireShot
			Enemy.fireShot = function(...)
				local args = { ... }
				if args[10] == id then
					linked += 1
					expect(args[5]).toBe(60)
					expect(args[8]).toBe(9)
				end
				return old(...)
			end
			local ok, why = pcall(function()
				f.world.advance(20)
				expect(linked).toBe(0)
				for _ = 1, 1200 do
					if linked > 0 then
						break
					end
					f.world.advance(1 / 120, 1 / 120)
				end
			end)
			Enemy.fireShot = old
			assert(ok, why)
			expect(linked).toBe(12)
			local count = Enemy.getShotCount()
			local info
			local c = Enemy.EnemyKilled:Connect(function(kill)
				if kill.id == id then
					info = kill
				end
			end)
			local observed, observe = nil, f.Data.observeNativeFastBossKill
			f.Data.observeNativeFastBossKill = function(player, seconds)
				if player == f.me then
					observed = seconds
				end
				return observe(player, seconds)
			end
			Enemy.damage(id, math.huge, f.me)
			f.Data.observeNativeFastBossKill = observe
			c:Disconnect()
			expect(Enemy.getShotCount()).toBe(count - 12)
			assert(info and info.aliveSeconds > 20)
			expect(info.bossElapsedSeconds).toBe(0)
			expect(observed).toBe(0)
		end
	)
end)
