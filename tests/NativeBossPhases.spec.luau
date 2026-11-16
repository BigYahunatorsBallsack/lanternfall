--!strict
-- Source Boss timer callbacks dispatch every eligible phase in child order; explicit custom timer overrides require their own controllers.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local S = game:GetService("ServerScriptService").Server.Services
local function modules()
	return require(S.EnemySim.NativeBossPhases), require(Shared.Config.NativeBossPhases)
end
describe("Source Boss phase callbacks", function()
	it("starts before the first child phase and never changes before a timer callback", function()
		local P, C = modules()
		local state = P.new(C.actors.Therizinosaurus)
		expect(state.current).toBe(-1)
		expect(state.elapsed).toBe(0)
		expect(#C.actors.Therizinosaurus.states).toBe(1)
		expect(C.actors.Therizinosaurus.states[1].hpStart).toBe(0.45)
		expect(C.actors.Therizinosaurus.states[1].timerStart).toBe(30)
	end)
	it("takes the inclusive original health threshold on the next actual timer callback", function()
		local P, C = modules()
		local state = P.new(C.actors.Therizinosaurus)
		expect(#P.onTimeout(state, 0.45001)).toBe(0)
		local changes = P.onTimeout(state, 0.45)
		expect(#changes).toBe(1)
		expect(changes[1]).toBe(0)
		expect(state.elapsed).toBe(2)
	end)
	it("uses the actual Therizinosaurus thirty-second threshold independently of health", function()
		local P, C = modules()
		local state = P.new(C.actors.Therizinosaurus)
		for _ = 1, 29 do
			expect(#P.onTimeout(state, 1)).toBe(0)
		end
		expect(P.onTimeout(state, 1)[1]).toBe(0)
		expect(state.elapsed).toBe(30)
	end)
	it("dispatches both Silesaurus phases synchronously in source order when health falls past both", function()
		local P, C = modules()
		local state = P.new(C.actors.Silesaurus)
		local order = {}
		local changes = P.onTimeout(state, 0.4, function(index, binding)
			expect(state.current).toBe(index)
			expect(state.elapsed).toBe(1)
			expect(binding).toBe(C.actors.Silesaurus.states[index + 1])
			table.insert(order, index)
		end)
		expect(#order).toBe(2)
		expect(order[1]).toBe(0)
		expect(order[2]).toBe(1)
		expect(changes[1]).toBe(0)
		expect(changes[2]).toBe(1)
		expect(state.current).toBe(1)
	end)
	it("does not go backwards or repeat callbacks after healing", function()
		local P, C = modules()
		local state = P.new(C.actors.Silesaurus)
		expect(P.onTimeout(state, 0.85)[1]).toBe(0)
		expect(#P.onTimeout(state, 1)).toBe(0)
		expect(P.onTimeout(state, 0.5)[1]).toBe(1)
		expect(#P.onTimeout(state, 0)).toBe(0)
	end)
	it("preserves each original Silesaurus timer threshold", function()
		local P, C = modules()
		local state = P.new(C.actors.Silesaurus)
		for _ = 1, 9 do
			expect(#P.onTimeout(state, 1)).toBe(0)
		end
		expect(P.onTimeout(state, 1)[1]).toBe(0)
		for _ = 11, 34 do
			expect(#P.onTimeout(state, 1)).toBe(0)
		end
		expect(P.onTimeout(state, 1)[1]).toBe(1)
	end)
	it("retains skipped earlier children instead of inventing transitions to every intervening index", function()
		local P = modules()
		local state = P.new({
			usesBasePhaseTimer = true,
			states = {
				{ hpStart = 0.3, timerStart = 99 },
				{ hpStart = 0.6, timerStart = 99 },
			},
		})
		local changes = P.onTimeout(state, 0.5)
		expect(#changes).toBe(1)
		expect(changes[1]).toBe(1)
	end)
	it("rereads health after an earlier phase callback before considering the next child", function()
		local P, C = modules()
		local state = P.new(C.actors.Silesaurus)
		local health = 0.4
		local changes = P.onTimeout(state, function()
			return health
		end, function()
			health = 1
		end)
		expect(#changes).toBe(1)
		expect(changes[1]).toBe(0)
		expect(state.current).toBe(0)
	end)
	it("rejects Carnotaurus and Brachiosaurus custom timers instead of running the base Boss loop", function()
		local P, C = modules()
		for _, name in { "Carnotaurus", "Brachiosaurus" } do
			expect(C.actors[name].usesBasePhaseTimer).toBe(false)
			local ok = pcall(P.new, C.actors[name])
			expect(ok).toBe(false)
		end
		expect(C.actors.Tyranosaurus.states[1].hpStart).toBe(0.7)
		expect(C.actors.Tyranosaurus.states[1].timerStart).toBe(15)
		expect(C.productionAdapterImplemented).toBe(false)
	end)
end)
