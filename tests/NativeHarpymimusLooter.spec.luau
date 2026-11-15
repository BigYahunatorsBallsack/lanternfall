--!strict
-- Native Jungle loot encounter uses the actual Looter script, arena wandering and guaranteed real crate/material drops.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local Kinds = require(f.Shared.Util.EnemyKinds)
local EnemyStats = require(f.Shared.Util.EnemyStats)
local Rules = require(f.Shared.Util.LootRules)
local XP = require(f.S.ExperienceService)
local Loot = require(f.S.LootService)
local Random = require(f.S.RandomService)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.MapService).setMovementCheck(false)
local function crates()
	local n = 0
	for _, p in Loot.getPickups() do
		if p.kind == "Crate" then
			n += 1
		end
	end
	return n
end
describe("Native Harpymimus Looter", function()
	it("uses original Loot Alien stats and special Jungle encounter policy rather than legacy fleeing", function()
		local k = assert(Kinds.get("HarpymimusLooter"))
		expect(k.typeId).toBe(58)
		expect(k.hp).toBe(5)
		expect(k.hpPerWave).toBe(30)
		expect(k.damagePerWave).toBeNear(0.85)
		expect(k.nativeSpeedPoints.base).toBe(350)
		expect(k.nativeSpeedPoints.randomization).toBe(50)
		expect(k.xp).toBe(8)
		expect(k.loot.crate).toBe(true)
		expect(k.loot.alwaysOrbs).toBe(true)
		expect(k.wander.around).toBe("Arena")
		expect(k.flee).toBe(nil)
		expect(k.specialSpawn).toBe(true)
		expect(k.nativeZoneId).toBe(2)
		expect(EnemyStats.canSpawn(k, 1, 0, 0)).toBe(false)
		expect(EnemyStats.canSpawn(k, 1, 0, 2)).toBe(false)
	end)
	it("guarantees base materials even at late wave/horde chances and a crate despite negative luck", function()
		local k = assert(Kinds.get("HarpymimusLooter"))
		expect(Rules.dropsOrb(k, 200, 0.999, 0)).toBe(true)
		expect(Rules.consumable(k, -100, 9, 0.999, 0.999, 0, 0)).toBe("Crate")
		expect(Rules.dugCrate(k, 1, 0, 0)).toBe(false)
	end)
	it("emits a real eight-base-material kill, native two-player value11 and an actual crate at wave20", function()
		Enemy.killAll()
		local id = assert(Enemy.spawn("HarpymimusLooter", 70, 0, 100, 0, nil, nil, 0))
		local materials, beforeCrates = XP.getMaterialsOnFloor(), crates()
		local getWave, number = f.Run.getWave, Random.number
		f.Run.getWave = function()
			return 20
		end
		Random.number = function(channel, player)
			return if channel == "Loot" then 0.999 else number(channel, player)
		end
		local raw = nil
		local connection = Enemy.EnemyKilled:Connect(function(info)
			if info.id == id then
				raw = info.xp
			end
		end)
		Enemy.damage(id, Enemy.getHealth(id) + 1, f.me)
		connection:Disconnect()
		f.Run.getWave, Random.number = getWave, number
		expect(raw).toBe(8)
		expect(XP.getMaterialsOnFloor() - materials).toBe(11)
		expect(crates() - beforeCrates).toBe(1)
		expect(#f.world.errors).toBe(0)
	end)
	it("preserves independent health/contact growth in the real service", function()
		Enemy.killAll()
		local id = assert(Enemy.spawn("HarpymimusLooter", 40, 0, 2, 3, nil, nil, 0, 10))
		expect(Enemy.getMaxHealth(id)).toBeNear((5 + 30 * 9) * 2)
		local _, damage = Enemy.getMultipliers(id)
		expect(damage).toBeNear((1 + 0.85 * 9) * 3)
		expect(f.Run.getNativeZoneId()).toBe(0)
	end)
	it("moves the real actor using its arena wandering branch without exposing a Jungle run", function()
		Enemy.killAll()
		local id = assert(Enemy.spawn("HarpymimusLooter", 60, 0, 1000, 0, nil, nil, 1))
		local before = assert(Enemy.getPosition(id))
		f.world.step(0.3)
		local after = assert(Enemy.getPosition(id))
		expect((after - before).Magnitude > 0).toBe(true)
		expect(f.Run.getNativeZoneId()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
