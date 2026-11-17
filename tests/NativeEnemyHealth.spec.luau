--!strict
-- Source enemy HP truncates the wave base before global factors, rounds only the final value and retains raw reset health.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
local Enemy = require(f.S.EnemySim)
local Combat = require(f.S.CombatService)
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
for _, player in { f.me, f.peer } do
	Combat.protect(player, 1000)
end
local function clear()
	Enemy.killAll()
	f.world.advance(0.1)
	Enemy.killAll()
end
describe("Native enemy source HP creation", function()
	it("opts in the audited Jungle, Nightmare and global Sea Pig actors explicitly", function()
		local count = 0
		for _, kind in f.Config.Enemies.types do
			if kind.nativeHealthRounding then
				count += 1
			end
		end
		expect(count).toBe(38)
		expect(f.Config.Enemies.types.Gallimimus.nativeHealthRounding).toBe(true)
		expect(f.Config.Enemies.types.CorruptedBuffer.nativeHealthRounding).toBe(true)
		expect(f.Config.Enemies.types.SeaPig.nativeHealthRounding).toBe(true)
		expect(f.Config.Enemies.types.Shadeling.nativeHealthRounding).toBe(nil)
	end)
	it("truncates a fractional wave base before the factor and then rounds the final HP", function()
		clear()
		for _, row in { { 2, 1.125, 7 }, { 4, 1.4, 15 }, { 20, 1.125, 57 } } do
			local id = assert(Enemy.spawn("Gallimimus", 0, 0, row[2], 0, nil, nil, 0, row[1]))
			expect(Enemy.getMaxHealth(id)).toBe(row[3])
			expect(Enemy.getHealth(id)).toBe(row[3])
		end
	end)
	it("retains the pre-rounding reset base when the actual Buffer later heals and boosts it", function()
		clear()
		local id = assert(Enemy.spawn("Gallimimus", 2, 0, 1.125, 0, nil, nil, 0, 2))
		expect(Enemy.getMaxHealth(id)).toBe(7) -- round(int(6.5)*1.125)
		Enemy.damage(id, 1, nil)
		Enemy.spawn("CorruptedBuffer", 0, 0, 100, 0, nil, nil, 0, 1)
		f.world.advance(0.3)
		expect(Enemy.getMaxHealth(id)).toBe(17) -- round(6.75*2.5), not a factor inferred from rounded7
		expect(Enemy.getHealth(id)).toBe(17)
	end)
	it("keeps fractional global-factor precision on an integer base for the global DLC actor", function()
		clear()
		local id = assert(Enemy.spawn("SeaPig", 0, 0, 1.125, 0, nil, nil, 0, 2))
		expect(Enemy.getMaxHealth(id)).toBe(51) -- round(45*1.125)=round(50.625)
	end)
	it("preserves the existing legacy spawn contract outside the source-bound opt-in", function()
		clear()
		local id = assert(Enemy.spawn("Shadeling", 0, 0, 1.125, 0, nil, nil, 0, 2))
		expect(Enemy.getMaxHealth(id)).toBeNear(5.625)
	end)
end)
