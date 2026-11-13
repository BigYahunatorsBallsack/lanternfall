--!strict
-- Original native speed randomization scales its integer offset by accessibility before the final full speed multiplier.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Stats = require(f.Shared.Util.EnemyStats)
local Kinds = require(f.Shared.Util.EnemyKinds)
local pixel = f.Config.Stats.range.studsPerPoint
local k = assert(Kinds.get("Triceratops"))
describe("Native accessibility speed", function()
	it("scales signed random offsets before truncation and keeps other multipliers separate", function()
		expect(Stats.spawnSpeedFactor(k, 0.1, 0.75, 0.75) * k.speed / pixel).toBeNear(195)
		expect(Stats.spawnSpeedFactor(k, 0.9, 0.75, 0.75) * k.speed / pixel).toBeNear(218)
		expect(Stats.spawnSpeedFactor(k, 0.1, 1.275, 0.75) * k.speed / pixel).toBeNear(332)
	end)
	it("preserves historical samplers when accessibility is supplied", function()
		local legacy = assert(Kinds.get("Brute"))
		expect(Stats.spawnSpeedFactor(legacy, 0.1, 0.75, 0.75)).toBeNear(0.75 * Stats.speedFactor(legacy, 0.1))
	end)
	it("passes the real run slider into native EnemySim spawn sampling", function()
		assert(f.Run.selectClass(f.me, "WellRounded"))
		assert(f.Weapons.selectStartWeapon(f.me, "WellRounded", "WatchmanPistol"))
		local options = require(f.Shared.Util.DangerRules).defaultOptions()
		options.enemySpeed = 75
		assert(f.Run.launch({ f.me, f.peer }, options))
		f.world.advance(f.Config.Run.flow.allReadyCountdownSeconds + 0.5)
		local Enemy = require(f.S.EnemySim)
		Enemy.killAll()
		local Random = require(f.S.RandomService)
		local old = Random.number
		Random.number = function(stream)
			return if stream == "Spawns" then 0.1 else old(stream)
		end
		local ok, id = pcall(Enemy.spawn, "Triceratops", 0, 0, 1, 1, nil, nil, 0.75, 1)
		Random.number = old
		assert(ok, id)
		local _, _, speed = Enemy.getMultipliers(assert(id))
		expect(speed * k.speed / pixel).toBeNear(195)
		f.Weapons.setPaused(true)
		local Map = require(f.S.MapService)
		Map.setMovementCheck(false)
		local at = Map.getRootPosition(f.me)
		f.peer.Character.HumanoidRootPart.Position = Vector3.new(at.X - 80, 100, at.Z + 80)
		Enemy.killAll()
		Random.number = function(stream)
			return if stream == "Spawns" then 0.1 else old(stream)
		end
		local spawned, charger = pcall(Enemy.spawn, "Triceratops", at.X + 35, at.Z, 1000, 0, nil, nil, 0.75, 1)
		Random.number = old
		assert(spawned, charger)
		for _ = 1, 180 do
			f.world.advance(1 / 60)
			if Enemy.getMode(charger) == 2 then
				break
			end
		end
		expect(Enemy.getMode(charger)).toBe(2)
		local before = assert(Enemy.getPosition(charger))
		f.world.advance(1 / f.Config.Simulation.tickRate)
		local after = assert(Enemy.getPosition(charger))
		expect(before.X - after.X).toBeNear((19.5 + 75 * 0.75) / f.Config.Simulation.tickRate)
	end)
end)
