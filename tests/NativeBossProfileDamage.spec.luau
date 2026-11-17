--!strict
-- Baryonyx normal shooting registers after Boss.init; its child receives early damage reduction until a later explicit stat reset.
loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local D = require(Shared.Util.NativeBossProfileDamage)
local attacks = require(Shared.Config.NativeBaryonyx).controller.attacks
describe("Native boss profile damage", function()
	it("preserves late root registration while applying early reduction to the independent child", function()
		local values = D.compute(attacks, 11, function(base)
			return base
		end, 0.75)
		expect(values[1]).toBe(12)
		expect(values[2]).toBe(10)
	end)
	it("applies a later damage reset to all registered attacks before final rounding", function()
		local values = D.compute(attacks, 11, function(base)
			return base * 1.013
		end, 0.75, 25)
		expect(values[1]).toBe(15)
		expect(values[2]).toBe(16)
	end)
end)
