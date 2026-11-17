--!strict
-- Native Silesaurus phases call synchronous side effects in source order while distinct attack clocks remain cold.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Actor = require(game:GetService("ServerScriptService").Server.Services.EnemySim.NativeBossActor)
local C = require(Shared.Config.NativeSilesaurus).controller
local function fixed()
	return 0.5
end
describe("Native Silesaurus actor", function()
	it("switches at the original ten/35second timer boundaries at full health", function()
		local state = Actor.new(C, fixed)
		local changes = {}
		local function step(dt)
			Actor.step(
				state,
				dt,
				function()
					return 1
				end,
				10,
				fixed,
				function() end,
				function(profile)
					table.insert(changes, profile)
				end
			)
		end
		step(9.9)
		expect(#changes).toBe(0)
		step(0.1)
		expect(changes[1]).toBe(2)
		step(24.9)
		expect(#changes).toBe(1)
		step(0.1)
		expect(changes[2]).toBe(3)
		expect(state.shooting.clocks[3].initial).toBeNear(59)
	end)
	it("calls each qualifying child side effect synchronously before evaluating the next", function()
		local state = Actor.new(C, fixed)
		local health, changes = 0.4, {}
		Actor.step(
			state,
			1,
			function()
				return health
			end,
			10,
			fixed,
			function() end,
			function(profile)
				table.insert(changes, profile)
				if profile == 2 then
					health = 0.9
				end
			end
		)
		expect(#changes).toBe(1)
		expect(changes[1]).toBe(2)
		expect(state.shooting.current).toBe(2)
	end)
	it("keeps the original ten-shot and two-shot long cooldowns in separate child clocks", function()
		local S = require(Shared.Util.NativeBossShooting)
		local state = S.new(C.shooting, fixed)
		for _, row in { { 2, 10, 120 }, { 3, 2, 60 } } do
			local index, count, long = row[1], row[2], row[3]
			S.select(state, index)
			state.clocks[index].initial = 0
			for _ = 1, count do
				assert(S.physics(state, 1, 10))
				S.advanceAnimation(state, 1, fixed)
			end
			expect(state.clocks[index].remaining).toBe(long)
			expect(state.clocks[index].shots).toBe(0)
		end
	end)
end)
