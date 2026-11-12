--!strict
-- Native character starts, personal source mechanics and exact persistent unlock boundary.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Jack")
describe("Native Jack package", function()
	it("runs all32 original starts", function()
		f.starts(32)
	end)
	it("uses original combat/material modifiers and replaces hordes for the entire frozen party", function()
		f.start("RitualDirk")
		expect(f.Stats.getStat(f.me, "eliteDamage")).toBe(125)
		expect(f.Stats.getStat(f.me, "enemyCount")).toBe(-70)
		expect(f.Stats.getStat(f.me, "enemyHp")).toBe(175)
		expect(f.Stats.getStat(f.me, "enemyDamage")).toBe(35)
		expect(require(f.Shared.Util.CharacterRules).nativeAmount("Jack", "gold_drops")).toBe(200)
		local Rules = require(f.Shared.Util.DangerRules)
		local random = function()
			return 1
		end
		local roll = function()
			return 0
		end
		local ordinary = Rules.planBlock(5, 0, random, roll, {})
		local jack = Rules.planBlock(5, 0, random, roll, {}, 0)
		local hordes = 0
		for _, entry in ordinary do
			if entry.kind == "Horde" then
				hordes += 1
			end
		end
		expect(hordes).toBe(2)
		for _, entry in jack do
			expect(entry.kind).toBe("Elite")
		end
	end)
	it("applies the Jack rule in the actual party plan without changing ordinary seeded plans", function()
		local Random = require(f.S.RandomService)
		local old = Random.stream
		Random.stream = function(channel, player)
			if channel == "Spawns" then
				return {
					NextNumber = function()
						return 0
					end,
					NextInteger = function(_, lo)
						return lo
					end,
				}
			end
			return old(channel, player)
		end
		local function plan(id)
			if f.Run.isOngoing() then
				f.Run.endRun("Abandoned")
			end
			f.world.advance(f.Config.Run.flow.resultsSeconds + 0.1)
			assert(f.Run.selectClass(f.me, id))
			local options = require(f.Shared.Util.DangerRules).defaultOptions()
			options.danger = 5
			assert(f.Run.launch({ f.me, f.peer }, options))
			f.world.advance(f.Config.Run.flow.allReadyCountdownSeconds + 0.5)
			f.Weapons.setPaused(true)
			require(f.S.SpawnDirector).setPaused(true)
			require(f.S.EnemySim).killAll()
			return require(f.S.DangerService).getPlan()
		end
		local ordinary = plan("NightWatch")
		local ordinaryHordes = 0
		for _, entry in ordinary do
			if entry.kind == "Horde" then
				ordinaryHordes += 1
			end
		end
		expect(ordinaryHordes).toBe(2)
		local jack = plan("Jack")
		local count = 0
		for _, entry in jack do
			count += 1
			expect(entry.kind).toBe("Elite")
		end
		expect(count).toBe(3)
		Random.stream = old
	end)

	it("unlocks only after a credited original elite or boss killed within the inclusive15second boundary", function()
		local A = require(f.Shared.Util.CharacterAccess)
		local Enemy = require(f.S.EnemySim)
		local boss = next(f.Config.Enemies.champions)
		local slow = assert(Enemy.spawn(boss, 40, 40, 1, 0, nil, nil, 0))
		f.world.advance(15.1)
		Enemy.damage(slow, 1e9, f.peer)
		expect(A.characterUnlocked(f.Data.get(f.peer), "Jack")).toBe(false)
		local normal = assert(Enemy.spawn("Shadeling", 40, 40, 1, 0, nil, nil, 0))
		Enemy.damage(normal, 1e9, f.peer)
		expect(A.characterUnlocked(f.Data.get(f.peer), "Jack")).toBe(false)
		local fast = assert(Enemy.spawn(boss, 40, 40, 1, 0, nil, nil, 0))
		f.world.advance(15, 1)
		Enemy.damage(fast, 1e9, f.peer)
		expect(A.characterUnlocked(f.Data.get(f.peer), "Jack")).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
