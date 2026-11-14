--!strict
-- Native inclusive, one-shot target detection and independent capped Pursuer timer phase.
loadHelper("tests/helpers/RobloxMock.luau")
local S = game:GetService("ServerScriptService").Server.Services.EnemySim
local Kinds = require(game:GetService("ReplicatedStorage").Shared.Util.EnemyKinds)
local Pursuer = require(S.NativePursuer)
describe("Native target detection", function()
	it("detects at the inclusive source radius exactly once and retains its state", function()
		local Detection = require(S.NativeTargetDetection)
		local state = Detection.new()
		local rule = { radius = 65, speedBonus = 9 }
		expect(Detection.step(state, rule, 65.001 ^ 2, 0.5)).toBe(0)
		expect(state.detected).toBe(false)
		expect(Detection.step(state, rule, 65 ^ 2, 0.5)).toBeNear(4.5)
		expect(state.detected).toBe(true)
		expect(Detection.step(state, rule, 0, 1)).toBe(0)
	end)
	it("keeps the repeating timer phase while capped so contact resets do not restart the timer", function()
		local k = assert(Kinds.get("BabyTrex"))
		local rule = table.clone(k.pursuer)
		rule.everySeconds = 1
		rule.maxSteps = 2
		local state = Pursuer.new(1)
		Pursuer.step(rule, state, k, 2.25)
		expect(state.stage).toBe(2)
		Pursuer.step(rule, state, k, 0.5)
		expect(state.clock).toBeNear(0.75)
		state.stage = 0
		Pursuer.step(rule, state, k, 0.25)
		expect(state.stage).toBe(1)
	end)
	it("does not impose Baby T-Rex's player speed cap on an ordinary Pursuer", function()
		local rule = table.clone(assert(Kinds.get("BabyTrex")).pursuer)
		rule.playerSpeedShare = nil
		local state = Pursuer.new(1)
		state.referenceSpeed = 0
		expect(Pursuer.cap(rule, state, 30)).toBe(30)
	end)
end)
