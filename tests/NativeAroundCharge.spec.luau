--!strict
-- Saved Ankylosaurus normal charge targeting is exercised through the real charge clock and World using a probe body, not a new ready actor family.
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config)
local Source = require(Shared.Config.JungleChargeTargets)
local Server = game:GetService("ServerScriptService").Server
local Charge = require(Server.Services.EnemySim.NativeStraightCharge)
local World = require(Server.Services.EnemySim.World)
local Kinds = require(Shared.Util.EnemyKinds)
local function state(rule)
	local result = Charge.new(rule, 3.9, function()
		return 0.5
	end)
	result.remaining = 0
	return result
end
local function sequence(values)
	local count = 0
	return function()
		count += 1
		assert(values[count], "Unexpected charge random draw")
		return values[count]
	end, function()
		return count
	end
end
local function world()
	local s = C.Simulation
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
		seed = 1,
	})
end
describe("Native around-player charge targeting", function()
	it("retains original normal rules without marking the full family activated", function()
		expect(Source.source.familyActivated).toBe(false)
		expect(Source.rule.duration).toBeNear(0.75)
		expect(Source.rule.fireAt).toBeNear(0.8 / 1.5)
		expect(Source.rule.speed).toBeNear(45)
		expect(Source.rule.maxRange).toBeNear(60)
		expect(Source.rule.target.radius).toBeNear(12)
	end)
	it("samples latest position and movement at SHOOT, consuming the discarded square before the cone", function()
		local rule = Source.rule
		local s = state(rule)
		local random, draws = sequence({ 0, 1, 0.5, 0, 0.75 })
		Charge.step(s, rule, 0, -30, 0, true, random, 1, 0, -10)
		expect(s.stage).toBe("Windup")
		expect(draws()).toBe(0)
		Charge.step(s, rule, rule.fireAt, 30, 0, true, random, 1, 0, 10)
		local length = math.sqrt(42 ^ 2 + 3 ^ 2)
		expect(s.direction).toBeNear(42 / length)
		expect(s.directionZ).toBeNear(3 / length)
		expect(draws()).toBe(5)
		expect(s.remaining).toBeNear(rule.cooldown - rule.jitter + 0.75 * 2 * rule.jitter + rule.duration)
	end)
	it("uses the random square without a cone for a stationary target", function()
		local rule = Source.rule
		local s = state(rule)
		local random, draws = sequence({ 0, 1, 0.5 })
		Charge.step(s, rule, 0, 30, 0, true, random, 1, 0, 0)
		Charge.step(s, rule, rule.fireAt, 30, 0, true, random, 1, 0, 0)
		local length = math.sqrt(30 ^ 2 + 12 ^ 2)
		expect(s.direction).toBeNear(30 / length)
		expect(s.directionZ).toBeNear(12 / length)
		expect(draws()).toBe(3)
	end)
	it("rotates the movement cone with the original signed angle and quarter-radius minimum", function()
		local rule = Source.rule
		local s = state(rule)
		local random = sequence({ 0.5, 0.5, 0, 0, 0.5 })
		Charge.step(s, rule, 0, 30, 0, true, random, 1, 10, 0)
		Charge.step(s, rule, rule.fireAt, 30, 0, true, random, 1, 10, 0)
		local length = math.sqrt(42 ^ 2 + 3 ^ 2)
		expect(s.direction).toBeNear(42 / length)
		expect(s.directionZ).toBeNear(-3 / length)
	end)
	it("retains a zero normalized direction when the chosen point coincides with the actor", function()
		local rule = Source.rule
		local s = state(rule)
		local random = sequence({ 0.5, 0.5, 0.5 })
		Charge.step(s, rule, 0, 0, 0, true, random, 1, 0, 0)
		Charge.step(s, rule, rule.fireAt, 0, 0, true, random, 1, 0, 0)
		expect(s.stage).toBe("Rush")
		expect(s.direction).toBe(0)
		expect(s.directionZ).toBe(0)
	end)
	it("checks inclusive radial limits and strict axis overrides with X taking precedence", function()
		local rule = table.clone(Source.rule)
		local s = state(rule)
		Charge.step(s, rule, 0, 60.11, 0, true, function()
			return 0.5
		end, 1)
		expect(s.stage).toBe("Walk")
		Charge.step(s, rule, 0, 0, 60.01, true, function()
			return 0.5
		end, 1)
		expect(s.stage).toBe("Windup")
		rule.minRange = 5
		s = state(rule)
		Charge.step(s, rule, 0, 4.99, 0, true, function()
			return 0.5
		end, 1)
		expect(s.stage).toBe("Walk")
		Charge.step(s, rule, 0, 5, 0, true, function()
			return 0.5
		end, 1)
		expect(s.stage).toBe("Windup")
		rule.maxRange = 5.3 -- original53px must survive point-to-stud round-trip
		s = state(rule)
		Charge.step(s, rule, 0, 5.301, 0, true, function()
			return 0.5
		end, 1)
		expect(s.stage).toBe("Windup")
		rule.rangeX, rule.rangeZ = 1, 1
		s = state(rule)
		Charge.step(s, rule, 0, 1, 0, true, function()
			return 0.5
		end, 1)
		expect(s.stage).toBe("Walk")
		Charge.step(s, rule, 0, 0.99, 100, true, function()
			return 0.5
		end, 1)
		expect(s.stage).toBe("Windup")
	end)
	it(
		"passes the nearest target's movement into an actual diagonal World rush and preserves it through transfer",
		function()
			local w = world()
			local k = table.clone(assert(Kinds.get("Triceratops"))) -- probe body only
			k.nativeCharge = Source.rule
			k.speed, k.speedMax = 0, 0
			local id = assert(w:spawn(k, 0, 0, 1000, 0, nil, 1))
			local i = w.indexOf[id]
			w.nativeCharges[i].remaining = 0
			local function step(dt)
				w:step(dt, { 30, -80 }, { 0, 0 }, 2, nil, nil, nil, { 0, 0 }, { 10, -10 })
			end
			step(0)
			step(k.nativeCharge.fireAt)
			expect(w.modes[i]).toBe(World.MODE_RUSH)
			step(0.1)
			local x, z = w:getPosition(id)
			expect(z > 0).toBe(true)
			expect(math.sqrt(x * x + z * z)).toBeNear(4.5)
			local dx, dz = w.rushXs[i], w.rushZs[i]
			expect(x).toBeNear(dx * 4.5)
			expect(z).toBeNear(dz * 4.5)
			local other = world()
			expect(w:transferTo(other, id)).toBe(true)
			other:step(0.1, { -80 }, { -80 }, 1, nil, nil, nil, { -10 }, { -10 })
			local ax, az = other:getPosition(id)
			expect(ax).toBeNear(x + dx * 4.5)
			expect(az).toBeNear(z + dz * 4.5)
		end
	)
	it("keeps raw target direction separate from the zero-speed input used by anticipation", function()
		local function probe(speed, raw)
			local w = world()
			local k = table.clone(assert(Kinds.get("Triceratops")))
			k.nativeCharge = Source.rule
			k.speed, k.speedMax = 0, 0
			local id = assert(w:spawn(k, 0, 0, 1000, 0, nil, 1))
			w.nativeCharges[w.indexOf[id]].remaining = 0
			for _, dt in { 0, k.nativeCharge.fireAt, 0.1 } do
				w:step(
					dt,
					{ 30 },
					{ 0 },
					1,
					nil,
					nil,
					nil,
					{ 0 },
					{ speed },
					if raw then { 0 } else nil,
					if raw then { raw } else nil
				)
			end
			return w:getPosition(id)
		end
		local rx, rz = probe(10, nil)
		local x, z = probe(0, 1)
		expect(x).toBeNear(rx)
		expect(z).toBeNear(rz)
	end)
end)
