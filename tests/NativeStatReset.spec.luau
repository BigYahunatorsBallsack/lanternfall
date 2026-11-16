--!strict
-- Native stat resets replace current stats, heal fully and preserve unrounded spawn inputs through World transfers.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config)
local Stats = require(Shared.Util.EnemyStats)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local function world()
	return World.new({
		cellSize = 8,
		maxEnemies = 10,
		playerRadius = 1,
		contactMargin = 0,
		separationStiffness = 0,
		separationPasses = 0,
		obstacleSteerMargin = 0,
		keepDistanceTolerance = 0,
		minX = -100,
		maxX = 100,
		minZ = -100,
		maxZ = 100,
		obstacles = {},
		collideTargets = false,
	})
end
local bases = { health = 13.2, contact = 21.2, shot = 21.2, speedPoints = 283.64 }
local boost = { hp = 2.5, damage = 1.3, speed = 1.5 }
describe("Native World stat reset", function()
	it("applies fresh unrounded inputs and fully heals instead of multiplying current stats", function()
		local w = world()
		local id = assert(w:spawn(C.Enemies.types.Triceratops, 0, 0, 100, 1))
		w:damage(id, 90)
		expect(w:resetNativeStats(id, bases, boost)).toBe(true)
		local hp, maximum = w:getHealth(id)
		expect(hp).toBe(33)
		expect(maximum).toBe(33)
		expect(w.contactDamage[w.indexOf[id]]).toBe(28)
		expect(w:getShotDamage(id)).toBe(28)
		expect(w.speedFactors[w.indexOf[id]] * C.Enemies.types.Triceratops.speed / C.Stats.range.studsPerPoint).toBeNear(
			425
		)
		w:damage(id, 10)
		expect(w:resetNativeStats(id, { health = 20, contact = 7.4, shot = 9.4, speedPoints = 101.2 }, boost)).toBe(
			true
		)
		expect(w:getHealth(id)).toBe(50)
		expect(w.contactDamage[w.indexOf[id]]).toBe(10)
		expect(w:getShotDamage(id)).toBe(12)
		expect(w.speedFactors[w.indexOf[id]] * C.Enemies.types.Triceratops.speed / C.Stats.range.studsPerPoint).toBeNear(
			152
		)
	end)
	it("does not change dead or absent actors", function()
		local w = world()
		local id = assert(w:spawn(C.Enemies.types.Triceratops, 0, 0, 10, 1))
		w:damage(id, 10)
		expect(w:resetNativeStats(id, bases, boost)).toBe(false)
		expect(w:getHealth(id)).toBe(0)
		expect(w:resetNativeStats(60000, bases, boost)).toBe(false)
	end)
	it("preserves source boost refusal without healing or marking the body boosted", function()
		local w = world()
		local id = assert(w:spawn(C.Enemies.types.SeaPig, 0, 0, 100, 3))
		w:damage(id, 10)
		expect(w:resetNativeStats(id, bases, boost)).toBe(false)
		expect(w:getHealth(id)).toBe(90)
		expect(w.buffed[w.indexOf[id]]).toBe(false)
		expect(w.contactDamage[w.indexOf[id]]).toBe(3)
	end)
	it("keeps source HP truncation before the global multiplier in the saved reset base", function()
		local w = world()
		local kind = C.Enemies.types.Charger
		local id = assert(w:spawn(kind, 0, 0, 13, 5.55, 7.4, 1, 2, 283.64))
		local b = assert(w:getSpawnStatBases(id))
		expect(b.health).toBe(12) -- int(4+2.5)*2
		expect(b.contact).toBe(5.55)
		expect(b.shot).toBe(7.4)
		expect(b.speedPoints).toBe(283.64)
	end)
	it("keeps independent raw speed and health bases through compaction and faction transfer", function()
		local w, other = world(), world()
		local first = assert(w:spawn(C.Enemies.types.Charger, 0, 0, 3, 1, nil, 1, 1, 5))
		local id = assert(w:spawn(C.Enemies.types.Charger, 0, 0, 13, 5.55, 7.4, 1, 2, 283.64))
		w:remove(first)
		w:step(0, {}, {}, 0)
		assert(w:transferTo(other, id))
		local b = assert(other:getSpawnStatBases(id))
		expect(b.health).toBe(12)
		expect(b.speedPoints).toBe(283.64)
		assert(other:resetNativeStats(id, b, boost))
		expect(other:getHealth(id)).toBe(30)
	end)
	it("uses the once-sampled raw native speed in the actual Buffer pulse", function()
		local w = world()
		local kind = C.Enemies.types.Triceratops
		local factor, raw = Stats.spawnSpeedFactor(kind, 0.1, 1.014, 1)
		expect(raw).toBeNear(258.57) -- (275-20)*1.014; round first would give259 rather than258.57
		local id = assert(w:spawn(kind, 0, 0, 100, 1, nil, factor, 1, raw))
		assert(w:spawn(C.Enemies.types.CorruptedBuffer, 5, 0, 1000, 0, nil, 0, 1))
		w:step(0, { 30 }, { 0 }, 1)
		w:step(0.3, { 30 }, { 0 }, 1)
		expect(w.speedFactors[w.indexOf[id]] * kind.speed / C.Stats.range.studsPerPoint).toBeNear(388)
	end)
	it("retains the supplied pre-rounding HP base after a compacted faction transfer", function()
		local w, other = world(), world()
		local first = assert(w:spawn(C.Enemies.types.Gallimimus, 0, 0, 1, 0))
		local id = assert(w:spawn(C.Enemies.types.Gallimimus, 0, 0, 7, 0, nil, 0, 2, 0, 6.75))
		w:remove(first)
		w:step(0, {}, {}, 0)
		assert(w:transferTo(other, id))
		local b = assert(other:getSpawnStatBases(id))
		expect(b.health).toBe(6.75)
		assert(other:resetNativeStats(id, b, boost))
		expect(other:getHealth(id)).toBe(17)
	end)
end)
