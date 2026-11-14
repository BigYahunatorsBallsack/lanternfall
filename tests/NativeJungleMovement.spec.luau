--!strict
-- Native Jungle movement separates texture-inset random goals, forbidden circles, player collision masks and physical origin bounds.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config)
local Kinds = require(Shared.Util.EnemyKinds)
local Zone = require(Shared.Util.NativeZoneSampling)
local World = require(game:GetService("ServerScriptService").Server.Services.EnemySim.World)
local function make(name, forbidden)
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
		forbiddenCircles = forbidden,
		seed = 1,
	})
	local k = table.clone(assert(Kinds.get(name)))
	local id = assert(w:spawn(k, 0, 0, 1000, 1, nil, 0))
	return w, id, k
end
describe("Native Jungle movement", function()
	it("replaces the native zero-vector goal sentinel even when the actor is far from the origin", function()
		local w, id = make("Alamosaurus")
		local i = w.indexOf[id]
		w.xs[i], w.zs[i] = 50, 50
		w.wanderXs[i], w.wanderZs[i], w.wanderLeft[i] = 0, 0, math.huge
		w.randomState = 1
		w:step(0, { 80 }, { 80 }, 1)
		expect(w.wanderXs[i] ~= 0 or w.wanderZs[i] ~= 0).toBe(true)
	end)
	it("truncates native Target and Offset initial random ranges in original pixels", function()
		for _, around in { "Target", "Offset" } do
			local w, _, k = make("Enigmacursor")
			k.wander = { around = around, range = 12.34, rangeJitter = 0, arriveStuds = 1, maxSeconds = math.huge }
			local id = assert(w:spawn(k, 0, 0, 1000, 1, nil, 0))
			expect(w.keeps[w.indexOf[id]]).toBeNear(12.3)
		end
	end)
	it("uses half the original texture dimensions for random goal bounds", function()
		local w, id, k = make("Alamosaurus")
		expect(k.nativeMovement.goalInsetX).toBeNear(9)
		w.randomState = 1
		w:step(0, { 80 }, { 80 }, 1)
		local i = w.indexOf[id]
		expect(w.wanderXs[i] >= -91 and w.wanderXs[i] <= 91).toBe(true)
		expect(w.wanderZs[i] >= -91 and w.wanderZs[i] <= 91).toBe(true)
	end)
	it("uses nine goal draws after eight forbidden checks and preserves the final push-out", function()
		local draws = 0
		local x, z = Zone.goal(function()
			draws += 1
			return 0, 0
		end, { { x = 0, z = 0, radius = 10 } })
		expect(draws).toBe(9)
		expect(x).toBeNear(10.8)
		expect(z).toBeNear(0)
	end)
	it("uses forbidden circles for actual native wander goals rather than body obstacle circles", function()
		local circles = { { x = 0, z = 0, radius = 1000 } }
		local w, id = make("Alamosaurus", circles)
		w:step(0, { 80 }, { 80 }, 1)
		local i = w.indexOf[id]
		expect(Zone.inForbidden(w.wanderXs[i], w.wanderZs[i], circles)).toBe(false)
	end)
	it("clamps native physical origins to the zone rectangle while preserving legacy body margins", function()
		local w, id = make("BabyPterosaur")
		w:push(id, 10000, 0)
		expect(w:getPosition(id)).toBeNear(100)
		local old, legacy, kind = make("Brute")
		old:push(legacy, 10000, 0)
		expect(old:getPosition(legacy)).toBeNear(100 - kind.radius)
	end)
	it("lets source-masked native followers overlap the player instead of stopping at a body circle", function()
		local w, id, k = make("BabyTriceratops")
		k.speed = 10
		k.speedMax = 10
		w.speedFactors[w.indexOf[id]] = 1
		w.xs[w.indexOf[id]] = -5
		w:step(0.5, { 0 }, { 0 }, 1)
		expect(w:getPosition(id)).toBeNear(0)
		expect(w.contacts[1] > 0).toBe(true)
	end)
	it("keeps native StayInRange's floating range and stops inside its original precision", function()
		local w, id, k = make("Enigmacursor")
		w.speedFactors[w.indexOf[id]] = 1
		local keep = w.keeps[w.indexOf[id]]
		expect(math.abs(keep / 0.1 - math.floor(keep / 0.1)) > 1e-6).toBe(true)
		w:step(0.1, { -(keep + 0.5) }, { 0 }, 1)
		expect(w:getPosition(id)).toBeNear(0)
		local x, z = w:getMoveInput(id)
		expect(x).toBeNear(0)
		expect(z).toBeNear(0)
	end)
end)
