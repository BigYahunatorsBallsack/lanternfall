--!strict
-- World adapter probes use an unregistered test actor: source jump locks movement/body/contact, retains hurt geometry and survives compaction/transfer.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local C = require(Shared.Config.NativeDimetrodon)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local function newWorld()
	return World.new({
		cellSize = 8,
		maxEnemies = 10,
		playerRadius = 1,
		contactMargin = 0,
		separationStiffness = 1,
		separationPasses = 2,
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
local function actor()
	local kind = table.clone(Config.Enemies.types.Shadeling)
	kind.nativeJump = C.jumpRule
	kind.nativeEdgePatrol = C.patrolRule
	kind.nativeMovement = { goalInsetX = 0, goalInsetZ = 0, borderClamp = true, collidePlayers = false, precision = 1 }
	kind.radius, kind.hurtRadius, kind.hitRadius = 2, 2, 2
	kind.nativeHurtOffsetX, kind.nativeHurtOffsetZ = 0, 0
	return kind
end
describe("Native jump World adapter", function()
	it("disables body and touch during windup while leaving the actual hurt queries enabled", function()
		local w = newWorld()
		local id = assert(w:spawn(actor(), 0, 0, 100, 3))
		local contacts = w:step(0, { 0 }, { 0 }, 1)
		expect(w:isBodyEnabled(id)).toBe(false)
		expect(w:isHurtEnabled(id)).toBe(true)
		expect(contacts[1]).toBe(0)
		local found = {}
		expect(w:queryRadius(0, 0, 0.1, found)).toBe(1)
		expect(found[1]).toBe(id)
		local other = table.clone(Config.Enemies.types.Shadeling)
		other.speed = 0
		local neighbour = assert(w:spawn(other, 0, 0, 100, 0))
		w:step(0, { 0 }, { 0 }, 1)
		expect(w:getPosition(id)).toBeNear(0)
		expect(w:getPosition(neighbour)).toBeNear(0)
	end)
	it(
		"applies the captured source-plane position, emits one landing and restores contact without an invented AoE",
		function()
			local w = newWorld()
			local id = assert(w:spawn(actor(), 0, 0, 100, 3))
			w:step(0, { 30 }, { 40 }, 1)
			expect(#w.nativeJumpStarts).toBe(1)
			w:step(0.875, { 99 }, { 99 }, 1)
			local x, z = w:getPosition(id)
			expect(x).toBeNear(7.5)
			expect(z).toBeNear(10 - 25 * math.sin(math.pi / 4))
			expect(w:isHurtEnabled(id)).toBe(true)
			local contacts = w:step(1.125, { 30 }, { 40 }, 1)
			expect(w:isBodyEnabled(id)).toBe(true)
			expect(contacts[1]).toBe(3)
			expect(#w.nativeLandings).toBe(1)
			expect(w.nativeLandings[1]).toBe(id)
			w:step(0.1, { 30 }, { 40 }, 1)
			expect(#w.nativeLandings).toBe(0)
		end
	)
	it("retains jump and patrol state through compaction and a faction World transfer", function()
		local w = newWorld()
		local dummy = assert(w:spawn(Config.Enemies.types.Shadeling, -70, 0, 100, 0))
		local id = assert(w:spawn(actor(), 0, 0, 100, 3))
		w:step(0, { 30 }, { 40 }, 1)
		w:step(0.875, { 30 }, { 40 }, 1)
		w:remove(dummy)
		w:step(0, { 30 }, { 40 }, 1)
		expect(w.indexOf[id]).toBe(1)
		local target = newWorld()
		assert(w:transferTo(target, id))
		expect(target:isBodyEnabled(id)).toBe(false)
		expect(target.nativeJumps[target.indexOf[id]].targetX).toBe(30)
		target:step(1.125, { 30 }, { 40 }, 1)
		expect(target:isBodyEnabled(id)).toBe(true)
		expect(target:getPosition(id)).toBeNear(30)
	end)
	it("patrols edges without a living target and never registers the probe as a new production actor", function()
		local w = newWorld()
		local id = assert(w:spawn(actor(), 50, 50, 100, 3))
		w:step(0.1, {}, {}, 0)
		local x, z = w:getPosition(id)
		expect((x - 50) ^ 2 + (z - 50) ^ 2 > 0).toBe(true)
		expect(w.nativeJumps[w.indexOf[id]].jumping).toBe(false)
		expect(C.actorRegistered).toBe(false)
	end)
	it("excludes an airborne body from source entry healing, then permits a new ground entry", function()
		local w = newWorld()
		local id = assert(w:spawn(actor(), 0, 0, 100, 3))
		w:step(0, { 0 }, { 0 }, 1)
		w:damage(id, 10)
		local Healing = require(game:GetService("ServerScriptService").Server.Services.EnemySim.NativeEntryHealing)
		local rule = { radius = 20, healFlat = 1, healPerWave = 0 }
		local previous, healed = Healing.step(w, 999, 1, 0, 0, rule, nil)
		expect(healed).toBe(false)
		expect(w:getHealth(id)).toBe(90)
		w:step(2, { 0 }, { 0 }, 1)
		local _, groundHeal = Healing.step(w, 999, 1, 0, 0, rule, previous)
		expect(groundHeal).toBe(true)
		expect(w:getHealth(id)).toBe(91)
	end)
	it("keeps disabled jump bodies out of actual buffer candidates while a ground control is boosted", function()
		local w = newWorld()
		local id = assert(w:spawn(actor(), 0, 0, 100, 3))
		local control = assert(w:spawn(Config.Enemies.types.Shadeling, 10, 0, 100, 0, nil, 0))
		assert(w:spawn(Config.Enemies.types.CorruptedBuffer, 5, 0, 1000, 0, nil, 0))
		w:step(0, { 30 }, { 0 }, 1)
		w:step(0.3, { 30 }, { 0 }, 1)
		expect(select(2, w:getHealth(id))).toBe(100)
		expect(select(2, w:getHealth(control))).toBe(250)
	end)
end)
