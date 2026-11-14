--!strict
-- Original cooldown-driven deflection clock and World transfer; full Pachycephalosaurus/projectile routing remain pending.
local Shared = game:GetService("ReplicatedStorage").Shared
local Services = game:GetService("ServerScriptService").Server.Services
local C = require(Shared.Config)
local Source = require(Shared.Config.JungleDeflectCharges)
local Charge = require(Services.EnemySim.NativeStraightCharge)
local World = require(Services.EnemySim.World)
local rule = Source.rule
local function shoot(roll)
	local state = Charge.new(rule, 1, function()
		return roll
	end)
	state.remaining = 0
	Charge.step(state, rule, 0, 20, 0, true, function()
		return roll
	end, 1)
	Charge.step(state, rule, rule.fireAt, 20, 0, true, function()
		return roll
	end, 1)
	return state
end
local function step(state, dt, targets)
	Charge.step(state, rule, dt, 20, 0, targets ~= false, function()
		return 0.5
	end, 1)
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
describe("Native deflect-charge clock", function()
	it("keeps the original normal values separate from unimplemented evolution variants", function()
		expect(Source.source.version).toBe("1.2.0.3")
		expect(Source.source.actorRegistered).toBe(false)
		expect(Source.source.projectileDefenseConnected).toBe(false)
		expect(rule.cooldown).toBeNear(70 / 60)
		expect(rule.jitter).toBeNear(20 / 60)
		expect(rule.duration).toBeNear(1)
		expect(rule.recovery).toBeNear(2)
		expect(rule.speed).toBeNear(40)
		expect(rule.target.radius).toBeNear(10)
		expect(rule.deflectStopBeforeCooldown).toBeNear(80 / 60)
	end)
	it("starts inactive, stays inactive during windup and activates only at SHOOT", function()
		local state = Charge.new(rule, 1, function()
			return 0
		end)
		expect(state.deflecting).toBe(false)
		state.remaining = 0
		step(state, 0)
		expect(state.stage).toBe("Windup")
		expect(state.deflecting).toBe(false)
		step(state, rule.fireAt)
		expect(state.stage).toBe("Rush")
		expect(state.deflecting).toBe(true)
	end)
	it("can lose defense before a low-cooldown rush finishes", function()
		local state = shoot(0)
		expect(state.remaining).toBeNear(50 / 60 + 1)
		step(state, 0.49)
		expect(state.deflecting).toBe(true)
		step(state, 0.02)
		expect(state.stage).toBe("Rush")
		expect(state.deflecting).toBe(false)
	end)
	it("can retain defense into recovery at a high cooldown and ticks without targets", function()
		local state = shoot(1)
		step(state, 1.05, false)
		expect(state.stage).toBe("Recover")
		expect(state.deflecting).toBe(true)
		step(state, 0.12, false)
		expect(state.stage).toBe("Recover")
		expect(state.deflecting).toBe(false)
	end)
	it("uses an inclusive cooldown boundary and reactivates on a subsequent shot", function()
		local state = shoot(1)
		state.remaining = rule.deflectStopBeforeCooldown + 0.1
		step(state, 0.1)
		expect(state.remaining).toBeNear(rule.deflectStopBeforeCooldown)
		expect(state.deflecting).toBe(false)
		step(state, 3)
		expect(state.stage).toBe("Windup")
		expect(state.deflecting).toBe(false)
		step(state, rule.fireAt)
		expect(state.deflecting).toBe(true)
		expect(Charge.new(rule, 1, function()
			return 0
		end).deflecting).toBe(false)
	end)
	it("does not give an ordinary Ankylosaurus any projectile defense", function()
		local ordinary = require(Shared.Config.JungleChargeTargets).rule
		local state = Charge.new(ordinary, 1, function()
			return 0
		end)
		state.remaining = 0
		Charge.step(state, ordinary, ordinary.fireAt, 20, 0, true, function()
			return 0
		end, 1)
		expect(state.stage).toBe("Rush")
		expect(state.deflecting).toBe(false)
	end)
	it("preserves the same live defense clock through actual World transfer and removes dead state", function()
		local a, b = world(), world()
		local kind = table.clone(assert(require(Shared.Util.EnemyKinds).get("Ankylosaurus")))
		kind.nativeCharge = rule -- probe body only; no Pachycephalosaurus family registration
		local id = assert(a:spawn(kind, 0, 0, 1000, 0, nil, 1))
		a.nativeCharges[a.indexOf[id]].remaining = 0
		a:step(rule.fireAt, { 20 }, { 0 }, 1)
		expect(a:isProjectileDeflecting(id)).toBe(true)
		local state = a.nativeCharges[a.indexOf[id]]
		expect(a:transferTo(b, id)).toBe(true)
		expect(a:isProjectileDeflecting(id)).toBe(false)
		expect(b.nativeCharges[b.indexOf[id]]).toBe(state)
		expect(b:isProjectileDeflecting(id)).toBe(true)
		b:step(2, {}, {}, 0)
		expect(b:isProjectileDeflecting(id)).toBe(false)
		b:clear()
		expect(b:isProjectileDeflecting(id)).toBe(false)
	end)
	it("never exposes an active defense for a body killed before its column is compacted", function()
		local w = world()
		local kind = table.clone(assert(require(Shared.Util.EnemyKinds).get("Ankylosaurus")))
		kind.nativeCharge = rule
		local id = assert(w:spawn(kind, 0, 0, 10, 0, nil, 1))
		w.nativeCharges[w.indexOf[id]].remaining = 0
		w:step(rule.fireAt, { 20 }, { 0 }, 1)
		expect(w:isProjectileDeflecting(id)).toBe(true)
		w:damage(id, 10)
		expect(w.indexOf[id] ~= nil).toBe(true)
		expect(w:isProjectileDeflecting(id)).toBe(false)
	end)
end)
