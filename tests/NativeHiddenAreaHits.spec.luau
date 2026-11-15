--!strict
-- Actual owned pillar/slash areas must ignore disabled crossing hurtboxes without consuming the attack.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local Pillars = require(f.S.NativePillarService)
local Slashes = require(f.S.NativeSlashService)
local Random = require(f.S.RandomService)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.StructureService).setPaused(true)
require(f.S.MapService).setMovementCheck(false)
for _, player in { f.me, f.peer } do
	require(f.S.CombatService).protect(player, 10000)
end
local function clear()
	Enemy.killAll()
	f.world.advance(0.1)
end
local function victim()
	local id = assert(Enemy.spawn("Iguanodon", 60, 0, 1000, 0, nil, nil, 0, 10))
	f.world.advance(0.1)
	return id, assert(Enemy.getHurtGeometry(id))
end
local function pillar(source, at)
	local c = require(f.Shared.Config.JungleWalkers).shootingRules.pillar
	local pixel = f.Config.Stats.range.studsPerPoint
	Enemy.NativePillar:Fire(
		source,
		at.X - c.offsetPoints[1] * pixel,
		at.Z - c.offsetPoints[2] * pixel,
		1,
		0,
		0,
		7,
		f.me.UserId
	)
end
local function slash(source, at)
	local original = Random.number
	Random.number = function(name, player)
		if name == "Combat" then
			return 0.5
		end
		return original(name, player)
	end
	Enemy.NativeSlash:Fire(source, at.X, at.Z, 7, f.me.UserId)
	Random.number = original
end
describe("Hidden native hurt areas", function()
	it("does not damage or consume a friendly pillar at a hidden Iguanodon", function()
		clear()
		local source = assert(Enemy.spawn("Enigmacursor", -70, 0, 1000, 0, nil, nil, 0, 10))
		assert(Enemy.charmSummoned(source, f.me.UserId))
		local id, at = victim()
		local hp = Enemy.getHealth(id)
		pillar(source, at)
		f.world.advance(0.6, 1 / 60)
		expect(Enemy.getHealth(id)).toBe(hp)
		expect(Pillars.getCount()).toBe(1)
	end)
	it("still damages a revealed Iguanodon through the same pillar path", function()
		clear()
		local source = assert(Enemy.spawn("Enigmacursor", -70, 0, 1000, 0, nil, nil, 0, 10))
		assert(Enemy.charmSummoned(source, f.me.UserId))
		local id = victim()
		f.world.advance(1.6, 1 / 60)
		local at = assert(Enemy.getHurtGeometry(id))
		local hp = Enemy.getHealth(id)
		pillar(source, at)
		f.world.advance(0.6, 1 / 60)
		expect(Enemy.getHealth(id)).toBe(hp - 7)
	end)
	it("does not damage or consume friendly slashes at a hidden Iguanodon", function()
		clear()
		local source = assert(Enemy.spawn("MadSlasher", -70, 0, 1000, 0, nil, nil, 0, 10))
		assert(Enemy.charmSummoned(source, f.me.UserId))
		local id, at = victim()
		local hp = Enemy.getHealth(id)
		slash(source, at)
		f.world.advance(0.6, 1 / 60)
		expect(Enemy.getHealth(id)).toBe(hp)
		expect(Slashes.getCount()).toBe(2)
	end)
	it("still damages a revealed Iguanodon through the same slash path", function()
		clear()
		local source = assert(Enemy.spawn("MadSlasher", -70, 0, 1000, 0, nil, nil, 0, 10))
		assert(Enemy.charmSummoned(source, f.me.UserId))
		local id = victim()
		f.world.advance(1.6, 1 / 60)
		local at = assert(Enemy.getHurtGeometry(id))
		local hp = Enemy.getHealth(id)
		slash(source, at)
		f.world.advance(0.6, 1 / 60)
		expect(Enemy.getHealth(id)).toBe(hp - 14)
		expect(#f.world.errors).toBe(0)
	end)
end)
