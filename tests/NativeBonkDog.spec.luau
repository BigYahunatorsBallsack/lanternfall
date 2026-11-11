--!strict
-- Bonk Dog's real production melee, highest-health jump and landing explosion, with player weapons disabled.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Structures, Enemy = require(f.S.StructureService), require(f.S.EnemySim)
local function dog()
	for _, row in Structures.getSnapshot() do
		if row.kind == "BonkDog" then
			return row
		end
	end
	error("Bonk Dog was not deployed")
end
describe("Native Bonk Dog", function()
	it("deploys a permanent pet without adding a structure source", function()
		f.start("WatchmanPistol")
		f.Weapons.setPaused(true)
		assert(f.Stats.addItem(f.me, "BonkDog"))
		expect(Structures.sourceCount(f.me)).toBe(0)
		expect(Structures.petSourceCount(f.me)).toBe(1)
		f.nextWave()
		expect(dog().ownerId).toBe(f.me.UserId)
	end)
	it("jumps to the highest-Max-HP eligible enemy and explodes at the captured destination", function()
		local at = dog()
		local low = Enemy.spawn("Brute", at.x + 20, at.z, 10, 0, nil, nil, 0)
		local high = Enemy.spawn("Brute", at.x - 90, at.z, 100, 0, nil, nil, 0)
		local highPosition = Enemy.getPosition(high)
		local initial = Enemy.getHealth(high)
		Structures.setPaused(false)
		-- The initial jump cooldown is uniformly between 75 and300 frames; the jump lasts30 frames.
		f.world.advance(5.7)
		expect(Enemy.getHealth(high) < initial).toBe(true)
		local row = dog()
		expect((Vector3.new(row.x, highPosition.Y, row.z) - highPosition).Magnitude < 15).toBe(true)
		expect(Enemy.getHealth(low) < Enemy.getMaxHealth(low)).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
	it("lands at the captured position when the target moves away during the jump", function()
		f.start("WatchmanPistol")
		f.Weapons.setPaused(true)
		assert(f.Stats.addItem(f.me, "BonkDog"))
		Structures.setPaused(true)
		f.nextWave()
		local at = dog()
		local highX = if at.x >= 0 then -60 else 60
		local lowX = at.x + (if highX < at.x then 15 else -15)
		Enemy.spawn("Brute", lowX, at.z, 10, 0, nil, nil, 0)
		local high = Enemy.spawn("Brute", highX, at.z, 100, 0, nil, nil, 0)
		local captured = Enemy.getPosition(high)
		local hp = Enemy.getHealth(high)
		Structures.setPaused(false)
		local jumping = false
		local maxWalk = 40 * math.max(1, 1 + f.Stats.getStat(f.me, "speed") / 100) / 15
		for _ = 1, 85 do
			local before = dog()
			f.world.advance(1 / 15)
			local after = dog()
			if
				(after.x - before.x) * (highX - before.x) > 0
				and (Vector3.new(after.x, 0, after.z) - Vector3.new(before.x, 0, before.z)).Magnitude
					> maxWalk + 0.01
			then
				jumping = true
				break
			end
		end
		assert(jumping, "Bonk Dog never started its native jump")
		Enemy.teleport(high, Vector3.new(-highX, captured.Y, captured.Z))
		-- Outside melee reach but inside the original landing explosion.
		local landingVictim = Enemy.spawn("Brute", captured.X, captured.Z + 20, 100, 0, nil, nil, 0)
		local landingHp = Enemy.getHealth(landingVictim)
		f.world.advance(0.4)
		local after = dog()
		expect((Vector3.new(after.x, captured.Y, after.z) - captured).Magnitude < 12).toBe(true)
		expect(Enemy.getHealth(high)).toBe(hp)
		expect(Enemy.getHealth(landingVictim) < landingHp).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
