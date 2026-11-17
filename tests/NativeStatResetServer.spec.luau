--!strict
-- Actual EnemySim spawning must retain its sampled unrounded native speed until the real Buffer reset.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Combat = require(f.S.CombatService)
local Random = require(f.S.RandomService)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
for _, player in { f.me, f.peer } do
	Combat.protect(player, 1000)
end
describe("Native stat reset production spawn", function()
	it("rounds the original speed once at boost time through the real spawn and pulse adapters", function()
		Enemy.killAll()
		f.world.advance(0.1)
		Enemy.killAll()
		local old = Random.number
		Random.number = function(stream)
			return if stream == "Spawns" then 0.1 else old(stream)
		end
		local ok, id = pcall(Enemy.spawn, "Triceratops", 2, 0, 1, 1, nil, nil, 1.014, 1)
		Random.number = old
		assert(ok, id)
		id = assert(id)
		local kind = f.Config.Enemies.types.Triceratops
		local pixel = f.Config.Stats.range.studsPerPoint
		expect(select(3, Enemy.getMultipliers(id)) * kind.speed / pixel).toBeNear(259)
		Enemy.spawn("CorruptedBuffer", 0, 0, 100, 0, nil, nil, 0, 1)
		f.world.advance(0.3)
		expect(select(3, Enemy.getMultipliers(id)) * kind.speed / pixel).toBeNear(388) -- round(258.57*1.5), not round(259*1.5)=389
	end)
end)
