--!strict
-- Source edge patrol preserves corner precedence, reversed bottom range, retained goals and its overwritten distance limit.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Config.NativeDimetrodon)
local Patrol = require(game:GetService("ServerScriptService").Server.Services.EnemySim.NativeEdgePatrol)
local rule = C.patrolRule
local bounds = { minX = 0, maxX = 100, minZ = 0, maxZ = 100 }
local function rolls(values)
	local at = 0
	return function()
		at += 1
		return assert(values[at], "Unexpected patrol random draw")
	end
end
describe("Native edge patrol component", function()
	it("samples the source integer edge band once and retains a nonzero goal", function()
		local s = Patrol.new(rule, function()
			return 0.123
		end)
		expect(s.edge).toBeNear(22.4)
		local x, z = Patrol.goal(rule, s, 0, 50, 1, bounds, rolls({ 0.5, 0.5 }))
		expect(x).toBeNear(12.8)
		expect(z).toBeNear(50)
		local a, b = Patrol.goal(rule, s, 0, 50, 1, bounds, function()
			error("Retained goal must not redraw")
		end)
		expect(a).toBe(x)
		expect(b).toBe(z)
	end)
	it("uses source corner coin precedence and equality remains on the side", function()
		local s = Patrol.new(rule, function()
			return 0.5
		end)
		local x, z = Patrol.goal(rule, s, 0, 0, 1, bounds, rolls({ 0.5, 0.5, 0.5 }))
		expect(x).toBeNear(16.6)
		expect(z).toBeNear(50)
		local t = Patrol.new(rule, function()
			return 0.5
		end)
		local tx, tz = Patrol.goal(rule, t, 0, 0, 1, bounds, rolls({ 0.51, 0.5, 0.5 }))
		expect(tx).toBeNear(50)
		expect(tz).toBeNear(16.6)
	end)
	it("uses the exact NONE order with the original reversed bottom sampling endpoints", function()
		local s = Patrol.new(rule, function()
			return 0.5
		end)
		local x, z = Patrol.goal(rule, s, 50, 50, 1, bounds, rolls({ 0, 0.25, 0 }))
		expect(x).toBeNear(26.6)
		expect(z).toBeNear(96.8)
	end)
	it("does not apply max_target_distance after both vector coordinates were overwritten", function()
		local s = Patrol.new(rule, function()
			return 0.5
		end)
		local x, z = Patrol.goal(rule, s, 0, 50, 1, bounds, rolls({ 1, 1 }))
		expect(x).toBe(30)
		expect(z).toBeNear(96.8)
		expect(math.sqrt(x * x + (z - 50) ^ 2) > 30).toBe(true)
	end)
	it("selects a new edge point at the inclusive arrival boundary", function()
		local s = Patrol.new(rule, function()
			return 0.5
		end)
		local x, z = Patrol.goal(rule, s, 0, 50, 1, bounds, rolls({ 0.5, 0.5 }))
		local tx, tz = Patrol.goal(rule, s, x - 1, z, 1, bounds, rolls({ 0, 0 }))
		expect(tx).toBeNear(3.2)
		expect(tz).toBeNear(3.2)
	end)
end)
