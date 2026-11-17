--!strict
-- Source Buffer resets float contact/projectile bases before final rounding; compaction and faction transfer must retain raw spawn values.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config)
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
local function actor(w)
	return assert(w:spawn(C.Enemies.types.CarnivorousPlant, 0, 0, 100, 21.2, 21.2, 0, 9))
end
local function boost(w, id)
	assert(w:spawn(C.Enemies.types.CorruptedBuffer, 5, 0, 1000, 0, nil, 0, 9))
	w:step(0, { 30 }, { 0 }, 1)
	w:step(0.3, { 30 }, { 0 }, 1)
	expect(select(2, w:getHealth(id))).toBe(250)
	expect(w.contactDamage[w.indexOf[id]]).toBe(28) -- round(21.2*1.3)
	expect(w:getShotDamage(id)).toBe(28)
end
describe("Source Buffer floating-point reset", function()
	it("does not truncate a fractional contact base or multiply a rounded projectile", function()
		local w = world()
		local id = actor(w)
		expect(w.contactDamage[w.indexOf[id]]).toBe(21)
		expect(w:getShotDamage(id)).toBe(21)
		boost(w, id)
	end)
	it("retains raw source inputs through compaction and world transfer", function()
		local w, target = world(), world()
		local first = assert(w:spawn(C.Enemies.types.CarnivorousPlant, 0, 0, 100, 3, 5, 0, 9))
		local id = actor(w)
		w:remove(first)
		w:step(0, {}, {}, 0)
		assert(w:transferTo(target, id))
		boost(target, id)
	end)
end)
