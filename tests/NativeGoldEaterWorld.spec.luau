--!strict
-- Real registered gold eater World state preserves damaged health, actor-local resistance, random material movement and compaction/faction transfer.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Kinds = require(Shared.Util.EnemyKinds)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local kind = assert(Kinds.get("JungleGobbler"))
local function newWorld()
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
		nativeGoldPositions = function()
			return { 80 }, { 0 }
		end,
	})
end
describe("Native gold eater World", function()
	it("multiplies current and maximum HP without healing and mutates only that actor's resistance", function()
		local w = newWorld()
		local id = assert(w:spawn(kind, 0, 0, 100, 1))
		local other = assert(w:spawn(kind, -50, 0, 100, 1))
		w:damage(id, 10)
		w:feedGold(id, 10)
		local hp, maxHp = w:getHealth(id)
		expect(hp).toBe(90)
		expect(maxHp).toBe(100)
		expect(w.kinds[w.indexOf[id]].knockbackResistance).toBe(0)
		expect(w.speedBonuses[w.indexOf[id]]).toBe(-12.5)
		w:feedGold(id, 10)
		local hp2, maxHp2 = w:getHealth(id)
		expect(hp2).toBe(180)
		expect(maxHp2).toBe(200)
		expect(w:goldValue(id)).toBe(60)
		expect(w.speedBonuses[w.indexOf[id]]).toBe(-25)
		expect(w.kinds[w.indexOf[id]].knockbackResistance).toBe(1)
		expect(w.kinds[w.indexOf[other]].knockbackResistance).toBeNear(0.5)
		expect(kind.knockbackResistance).toBeNear(0.5)
	end)
	it("moves towards a material even with no living player and does not chase a nearby opposing player", function()
		local w = newWorld()
		local id = assert(w:spawn(kind, 40, 0, 100, 1))
		w:step(0.1, {}, {}, 0)
		expect(w:getPosition(id)).toBeNear(43.5)
		w:step(0.1, { 0 }, { 0 }, 1)
		expect(w:getPosition(id)).toBeNear(47)
	end)
	it("preserves pickup state and selected point through compaction and World transfer", function()
		local w = newWorld()
		local dummy = assert(w:spawn(kind, -60, 0, 100, 1))
		local id = assert(w:spawn(kind, 40, 0, 100, 1))
		w:feedGold(id, 25)
		w:step(0, {}, {}, 0)
		w:remove(dummy)
		w:step(0, {}, {}, 0)
		expect(w.indexOf[id]).toBe(1)
		expect(w.nativeEaters[1].targetX).toBe(80)
		local target = newWorld()
		assert(w:transferTo(target, id))
		expect(target:goldValue(id)).toBe(50)
		expect(target.nativeEaters[target.indexOf[id]].targetX).toBe(80)
		target:feedGold(id, 1)
		expect(target:goldValue(id)).toBe(78)
	end)
end)
