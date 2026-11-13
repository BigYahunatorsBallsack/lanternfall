--!strict
-- Neutral Jungle horizontal charges retain original timing, additive speed, source trigger/follow rules and state through transfer.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config)
local Kinds = require(Shared.Util.EnemyKinds)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local function make(name)
	local s = C.Simulation
	local w = World.new({
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
		forbiddenCircles = nil,
		seed = 1,
	})
	local k = table.clone(assert(Kinds.get(name)))
	local id = assert(w:spawn(k, 0, 0, 1000, 1, nil, 1))
	return w, id, k
end
describe("Native straight Jungle charges", function()
	it("scales the charge bonus only by accessibility rather than randomized base speed", function()
		local w, id, k = make("Triceratops")
		local i = w.indexOf[id]
		w.params.nativeChargeAccessibility = function()
			return 0.75
		end
		w.speedFactors[i] = 1.4
		w.nativeCharges[i].remaining = 0
		w:step(0, { 80 }, { 0 }, 1)
		w:step(k.nativeCharge.fireAt, { 80 }, { 0 }, 1)
		expect(w.speedBonuses[i]).toBeNear(75 * 0.75)
		w:step(0.1, { 80 }, { 0 }, 1)
		expect(w:getPosition(id)).toBeNear((k.speed * 1.4 + 75 * 0.75) * 0.1)
	end)
	it("sweeps contact damage through a player without ending its timed rush", function()
		local w, id, k = make("Triceratops")
		local i = w.indexOf[id]
		w.nativeCharges[i].remaining = 0
		w:step(0, { 20 }, { 0 }, 1)
		w:step(k.nativeCharge.fireAt, { 20 }, { 0 }, 1)
		w:step(0.5, { 20 }, { 0 }, 1)
		expect(w.contacts[1]).toBe(1)
		expect(w:getPosition(id) > 30).toBe(true)
		expect(w.modes[i]).toBe(World.MODE_RUSH)
	end)
	it("keeps its charge timer running while a body obstacle blocks motion", function()
		local w, id, k = make("Parasaurolorus")
		local i = w.indexOf[id]
		w.params.obstacles = { { x = 10, z = 0, radius = 2 } }
		w.nativeCharges[i].remaining = 0
		w:step(0, { 80 }, { 0 }, 1)
		w:step(k.nativeCharge.fireAt + 0.2, { 80 }, { 0 }, 1)
		expect(w:getPosition(id) < 10).toBe(true)
		expect(w.modes[i]).toBe(World.MODE_RUSH)
		w:step(0.8, {}, {}, 0)
		expect(w.modes[i]).toBe(World.MODE_RECOVER)
	end)
	it("replaces the actual Charm bonus at shoot and clears it on timed unlock", function()
		local Friends = require(game:GetService("ServerScriptService").Server.Services.EnemySim.CharmedWorld)
		local w, id, k = make("Triceratops")
		local i = w.indexOf[id]
		w.nativeCharges[i].remaining = 0
		w:step(0, { 80 }, { 0 }, 1)
		local friends = Friends.new(w.params, { damage = function() end, expired = function() end })
		assert(friends:convert(w, id, 17, 0, { contact = 1, shot = 0 }))
		local actor = friends.world.indexOf[id]
		expect(friends.world.speedBonuses[actor]).toBeNear(10)
		friends:step(k.nativeCharge.fireAt, k.nativeCharge.fireAt, w)
		expect(friends.world.speedBonuses[actor]).toBeNear(75)
		friends:step(1, 2, w)
		expect(friends.world.speedBonuses[actor]).toBe(0)
		expect(friends.world.modes[actor]).toBe(World.MODE_RECOVER)
		expect(friends:count(17)).toBe(1)
	end)
	it("keeps source animation timing and body growth values for both neutral families", function()
		for _, name in { "Triceratops", "Parasaurolorus" } do
			local w, id, k = make(name)
			expect(k.nativeCharge.fireAt).toBeNear(0.8 / 1.5)
			expect(k.nativeCharge.duration).toBeNear(1)
			expect(k.nativeCharge.speed).toBeNear(75)
			expect(k.nativeCharge.rangeZ).toBeNear(1.5)
			expect(w.nativeCharges[w.indexOf[id]].originalMass).toBe(math.floor(k.mass))
		end
	end)
	it("uses the strict vertical threshold even outside radial range", function()
		local w, id = make("Triceratops")
		local i = w.indexOf[id]
		w.nativeCharges[i].remaining = 0
		w:step(0, { 80 }, { 1.5 }, 1)
		expect(w.modes[i]).toBe(World.MODE_WALK)
		w:step(0, { 80 }, { 1.49 }, 1)
		expect(w.modes[i]).toBe(World.MODE_WINDUP)
	end)
	it("uses half the horizontal target distance for ordinary following", function()
		local w, id, k = make("Triceratops")
		w.nativeCharges[w.indexOf[id]].remaining = 100
		w:step(0.01, { 20 }, { 20 }, 1)
		local x, z = w:getMoveInput(id)
		expect(z / x).toBeNear(2)
	end)
	it("caches direction at start, adds the base speed and resets mass after the timed rush", function()
		local w, id, k = make("Triceratops")
		local i = w.indexOf[id]
		local original = k.mass
		w.nativeCharges[i].remaining = 0
		w:step(0, { -80 }, { 0 }, 1)
		expect(w.kinds[i].mass).toBe(math.floor(original) * 5)
		w:step(k.nativeCharge.fireAt, { 80 }, { 0 }, 1)
		expect(w.modes[i]).toBe(World.MODE_RUSH)
		local before = w:getPosition(id)
		w:step(0.1, { 80 }, { 0 }, 1)
		local expected = (k.speed * w.speedFactors[i] + k.nativeCharge.speed * w.speedFactors[i]) * 0.1
		expect(w:getPosition(id)).toBeNear(before - expected)
		w:step(0.9, {}, {}, 0)
		expect(w.modes[i]).toBe(World.MODE_RECOVER)
		expect(w.kinds[i].mass).toBe(math.floor(original))
		expect(w.speedBonuses[i]).toBe(0)
		w:step(k.nativeCharge.recovery, {}, {}, 0)
		expect(w.modes[i]).toBe(World.MODE_WALK)
	end)
	it("remains rushing at a physical border until its timer expires", function()
		local w, id, k = make("Triceratops")
		local i = w.indexOf[id]
		w.xs[i] = 99
		w.nativeCharges[i].remaining = 0
		w:step(0, { 100 }, { 0 }, 1)
		w:step(k.nativeCharge.fireAt, { 100 }, { 0 }, 1)
		w:step(0.2, { 100 }, { 0 }, 1)
		expect(w:getPosition(id)).toBeNear(100)
		expect(w.modes[i]).toBe(World.MODE_RUSH)
		w:step(0.8, {}, {}, 0)
		expect(w.modes[i]).toBe(World.MODE_RECOVER)
	end)
	it("retains timers and cached direction through a world transfer", function()
		local w, id, k = make("Triceratops")
		local i = w.indexOf[id]
		w.nativeCharges[i].remaining = 0
		w:step(0, { 80 }, { 0 }, 1)
		w:step(k.nativeCharge.fireAt + 0.2, { 80 }, { 0 }, 1)
		local state = w.nativeCharges[i]
		local other = make("Parasaurolorus")
		other:clear()
		expect(w:transferTo(other, id)).toBe(true)
		local j = other.indexOf[id]
		expect(other.nativeCharges[j]).toBe(state)
		other:step(0.8, {}, {}, 0)
		expect(other.modes[j]).toBe(World.MODE_RECOVER)
	end)
end)
