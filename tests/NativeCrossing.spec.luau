--!strict
-- Source crossing lifecycle and map-relative trajectory; run before registering either Jungle actor.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local S = game:GetService("ServerScriptService").Server.Services.EnemySim
local bounds = { minX = -100, maxX = 100, minZ = -60, maxZ = 60 }
local function ready(rule)
	local Crossing = require(S.NativeCrossing)
	local state = Crossing.new()
	Crossing.movement(state, rule, bounds, -90, 0, function()
		error("Hidden actor consumed RNG")
	end)
	Crossing.advanceWarning(state, rule, rule.warningSeconds)
	return state
end
describe("Native crossing path", function()
	it("starts warning on first movement and enables every collider at timeout", function()
		local Crossing = require(S.NativeCrossing)
		local rule = require(Shared.Config.NativeCrossingPaths).families.Oviraptor
		local state = Crossing.new()
		expect(Crossing.active(state)).toBe(false)
		Crossing.advanceWarning(state, rule, 10)
		expect(state.phase).toBe("Dormant")
		local x, z, dx, dz = Crossing.movement(state, rule, bounds, -90, 4, function()
			error("Unexpected RNG")
		end)
		expect(x).toBe(-90)
		expect(z).toBe(4)
		expect(dx).toBe(0)
		expect(dz).toBe(0)
		expect(state.phase).toBe("Warning")
		Crossing.advanceWarning(state, rule, 0.34)
		expect(Crossing.active(state)).toBe(false)
		Crossing.advanceWarning(state, rule, 0.01)
		expect(state.phase).toBe("Ready")
		expect(Crossing.active(state)).toBe(true)
	end)
	it("uses Iguanodon's longer warning and independent state", function()
		local Crossing = require(S.NativeCrossing)
		local rule = require(Shared.Config.NativeCrossingPaths).families.Iguanodon
		local state = Crossing.new()
		Crossing.movement(state, rule, bounds, 90, 0, function()
			return 0.5
		end)
		Crossing.advanceWarning(state, rule, 1.49)
		expect(Crossing.active(state)).toBe(false)
		Crossing.advanceWarning(state, rule, 0.01)
		expect(Crossing.active(state)).toBe(true)
		expect(Crossing.new().phase).toBe("Dormant")
	end)
	it("draws jitter then target offset once and preserves its direction after correction", function()
		local Crossing = require(S.NativeCrossing)
		local rule = require(Shared.Config.NativeCrossingPaths).families.Oviraptor
		local state = ready(rule)
		local calls = 0
		local function rng()
			calls += 1
			return 1
		end
		local x, z, dx, dz = Crossing.movement(state, rule, bounds, -90, 4, rng)
		expect(x).toBe(-90)
		expect(z).toBeNear(14)
		expect(state.targetX).toBe(110)
		expect(state.targetZ).toBeNear(34)
		expect(dx).toBe(200)
		expect(dz).toBeNear(20)
		expect(state.rotation).toBeNear(math.atan2(20, 200))
		expect(calls).toBe(2)
		local _, _, afterX, afterZ = Crossing.movement(state, rule, bounds, -20, -40, rng)
		expect(afterX).toBe(dx)
		expect(afterZ).toBe(dz)
		expect(calls).toBe(2)
	end)
	it("uses the map midpoint for the leftward branch and rotates the root by pi", function()
		local Crossing = require(S.NativeCrossing)
		local rule = require(Shared.Config.NativeCrossingPaths).families.Iguanodon
		local state = ready(rule)
		local shifted = { minX = 300, maxX = 500, minZ = 50, maxZ = 170 }
		local _, z, dx, dz = Crossing.movement(state, rule, shifted, 400, 80, function()
			return 0
		end)
		expect(z).toBeNear(70)
		expect(state.targetX).toBe(200)
		expect(state.targetZ).toBeNear(50)
		expect(dx).toBe(-200)
		expect(dz).toBeNear(-20)
		expect(state.rotation).toBeNear(math.atan2(-20, -200) + math.pi)
	end)
	it("despawns strictly beyond target plus overshoot on the next movement call", function()
		local Crossing = require(S.NativeCrossing)
		local rule = require(Shared.Config.NativeCrossingPaths).families.Oviraptor
		for _, startX in { -90, 90 } do
			local state = ready(rule)
			Crossing.movement(state, rule, bounds, startX, 0, function()
				return 0.5
			end)
			local sign = if startX < 0 then 1 else -1
			local edge = state.targetX + sign * 15
			Crossing.movement(state, rule, bounds, edge, 0, function()
				error("Rerolled")
			end)
			expect(state.phase).toBe("Moving")
			local _, _, dx, dz = Crossing.movement(state, rule, bounds, edge + sign * 0.001, 0, function()
				error("Rerolled")
			end)
			expect(state.phase).toBe("Removed")
			expect(dx).toBe(0)
			expect(dz).toBe(0)
			expect(Crossing.active(state)).toBe(false)
			Crossing.advanceWarning(state, rule, 100)
			expect(state.phase).toBe("Removed")
		end
	end)
end)
