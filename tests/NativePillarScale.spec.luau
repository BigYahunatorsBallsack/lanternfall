--!strict
-- Actual native pillar scale changes its collision and transmitted fallback circle, not its damage.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local Pillars = require(f.S.NativePillarService)
local C = require(f.Shared.Config.JungleWalkers).shootingRules.pillar
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
require(f.S.StructureService).setPaused(true)
require(f.S.MapService).setMovementCheck(false)
for _, player in { f.me, f.peer } do
	require(f.S.CombatService).protect(player, 10000)
end
local function setup(scale)
	Enemy.killAll()
	f.world.advance(1.2)
	local source = assert(Enemy.spawn("Enigmacursor", 80, 60, 1000, 0, nil, nil, 0, 10))
	local victim = assert(Enemy.spawn("Brute", -40, -50, 1000, 0, nil, nil, 0, 10))
	local at, radius = Enemy.getHurtGeometry(victim)
	local pixel = f.Config.Stats.range.studsPerPoint
	local attackX = at.X - radius - C.radiusPoints * pixel * 0.85
	local attackZ = at.Z
	local shown
	local previous = f.world.netWatch
	f.world.netWatch = function(name, player, batch)
		if previous then
			previous(name, player, batch)
		end
		if name == "BossTelegraphs" and player == f.me then
			for _, entry in batch do
				if entry.shape == "Circle" then
					shown = entry.radius
				end
			end
		end
	end
	local hp = Enemy.getHealth(victim)
	Enemy.NativePillar:Fire(
		source,
		attackX - C.offsetPoints[1] * pixel * scale,
		attackZ - C.offsetPoints[2] * pixel * scale,
		1,
		0,
		0,
		7,
		f.me.UserId,
		scale
	)
	f.world.advance(0.6, 1 / 60)
	f.world.netWatch = previous
	return victim, hp, shown
end
describe("Native pillar root scale", function()
	it("lets a target outside a small pillar survive and keeps its smaller telegraph", function()
		local id, hp, radius = setup(0.7)
		expect(Enemy.getHealth(id)).toBe(hp)
		expect(Pillars.getCount()).toBe(1)
		expect(radius).toBeNear(C.radiusPoints * f.Config.Stats.range.studsPerPoint * 0.7)
	end)
	it("hits the same relative target with full scale and unchanged damage", function()
		local id, hp, radius = setup(1)
		expect(Enemy.getHealth(id)).toBe(hp - 7)
		expect(Pillars.getCount()).toBe(0)
		expect(radius).toBeNear(C.radiusPoints * f.Config.Stats.range.studsPerPoint)
		expect(#f.world.errors).toBe(0)
	end)
end)
