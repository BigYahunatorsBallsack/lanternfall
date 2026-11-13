--!strict
-- Stintaosaurus heals enemies on body entry, including bosses; Charm retains its enemy-only mask and never heals players.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("WellRounded")
local Enemy = require(f.S.EnemySim)
local World = require(f.S.EnemySim.World)
local Kinds = require(f.Shared.Util.EnemyKinds)
local function make()
	local s = f.Config.Simulation
	return World.new({
		cellSize = s.spatialHashCellSize,
		maxEnemies = 140,
		playerRadius = s.playerRadius,
		contactMargin = s.contactMargin,
		separationStiffness = s.separationStiffness,
		separationPasses = s.separationPasses,
		obstacleSteerMargin = s.obstacleSteerMargin,
		keepDistanceTolerance = s.keepDistanceTolerance,
		minX = -100,
		maxX = 100,
		minZ = -100,
		maxZ = 100,
		obstacles = {},
	})
end
describe("Native Jungle healer", function()
	it("heals once per entry with source wave scaling and allows a second heal after reentry", function()
		local w = make()
		local healer = assert(w:spawn(assert(Kinds.get("Stintaosaurus")), 0, 0, 100, 0, nil, 0, 3))
		local target = assert(w:spawn(assert(Kinds.get("Brute")), 10, 0, 1000, 0, nil, 0, 3))
		w:damage(target, 500)
		w:step(0, {}, {}, 0)
		expect(w:getHealth(target)).toBe(620)
		w:damage(target, 100)
		w:step(0, {}, {}, 0)
		expect(w:getHealth(target)).toBe(520)
		local i = w.indexOf[target]
		w.xs[i] = 80
		w:step(0, {}, {}, 0)
		w:step(0, {}, {}, 0)
		w.xs[i] = 10
		w:step(0, {}, {}, 0)
		w:step(0, {}, {}, 0)
		expect(w:getHealth(target)).toBe(640)
		expect(w:isAlive(healer)).toBe(true)
	end)
	it("includes damaged enemy bosses and excludes neutral trees from its native enemy mask", function()
		local w = make()
		assert(w:spawn(assert(Kinds.get("Stintaosaurus")), 0, 0, 100, 0, nil, 0, 1))
		local enemy = table.clone(assert(Kinds.get("Brute")))
		enemy.boss = { states = {} }
		local boss = assert(w:spawn(enemy, 10, 0, 1000, 0, nil, 0, 1))
		local tree = assert(w:spawn(assert(Kinds.get("Tree")), -10, 0, 1000, 0, nil, 0, 1))
		w:damage(boss, 500)
		w:damage(tree, 500)
		w:step(0, {}, {}, 0)
		expect(w:getHealth(boss)).toBe(600)
		expect(w:getHealth(tree)).toBe(500)
	end)
	it("retains enemy healing after real Charm conversion while leaving injured players unhealed", function()
		f.start("WatchmanPistol")
		f.Weapons.setPaused(true)
		require(f.S.MapService).setMovementCheck(false)
		local combat = require(f.S.CombatService)
		for _, player in { f.me, f.peer } do
			combat.protect(player, 10000)
		end
		local at = f.me.Character.HumanoidRootPart.Position
		local healer = assert(Enemy.spawn("Stintaosaurus", at.X + 5, at.Z, 100, 0, nil, nil, 0, 1))
		Enemy.damage(healer, 1, nil)
		assert(Enemy.tryCharm(f.me, healer, { charmChance = 1, charmThreshold = 1 }, function()
			return 0
		end))
		local target = assert(Enemy.spawn("Brute", at.X + 10, at.Z, 100, 0, nil, nil, 0, 1))
		Enemy.damage(target, 200, nil)
		local before = Enemy.getHealth(target)
		combat.setHpFraction(f.me, 0.5)
		local hp = combat.getHp(f.me)
		f.world.advance(0.15, 1 / 60)
		expect(Enemy.getHealth(target) > before).toBe(true)
		expect(combat.getHp(f.me)).toBe(hp)
		expect(Enemy.isCharmed(healer)).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
end)
