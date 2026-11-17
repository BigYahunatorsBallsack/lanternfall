--!strict
-- Source normal wrapper consumes its first physics callback and registers damage after Boss.init/reset side effects.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Actor = require(game:GetService("ServerScriptService").Server.Services.EnemySim.NativeBossActor)
local C = require(Shared.Config.NativeBaryonyx).controller
local function fixed()
	return 0.5
end
describe("Native Baryonyx source wrapper", function()
	it("selects/registers on the first callback without consuming the normal attack's cooldown", function()
		local state = Actor.new(C, fixed)
		Actor.step(state, 1 / 60, function()
			return 1
		end, 10, fixed, function() end)
		expect(state.wrapperFrames).toBe(0)
		expect(state.shooting.clocks[1].remaining).toBe(10)
		Actor.step(state, 1 / 60, function()
			return 1
		end, 10, fixed, function() end)
		expect(state.shooting.clocks[1].remaining).toBe(9)
	end)
	it("does not retain a modifier applied before the root shooting behavior was registered", function()
		local state = Actor.new(C, fixed)
		state.damages = { 20, 20 }
		state.lateRootDamage = 12
		Actor.step(state, 1 / 60, function()
			return 1
		end, 10, fixed, function() end)
		expect(state.damages[1]).toBe(12)
		expect(state.damages[2]).toBe(20)
	end)
	it("switches to the independently instanced laser at30seconds or inclusive halfHP", function()
		for _, health in { 1, 0.5 } do
			local state = Actor.new(C, fixed)
			Actor.step(state, if health == 1 then 30 else 1, function()
				return health
			end, 10, fixed, function() end)
			expect(state.shooting.current).toBe(2)
		end
	end)
end)
