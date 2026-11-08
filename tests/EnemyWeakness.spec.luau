--!strict
-- Stable percent-damage-taken behavior: shared source stacks, whole-group refresh, expiry and stronger upgrades.
local Weakness = require(game:GetService("ServerScriptService").Server.Services.EnemySim.Weakness)
describe("Native enemy weakness", function()
	it("shares Lute stacks across users, caps them and refreshes their common duration", function()
		local w = Weakness.new()
		for _ = 1, 4 do
			w:apply(1, "Lute", 10, 3, 3)
		end
		expect(w:bonus(1)).toBe(30)
		w:step(2.9)
		w:apply(1, "Lute", 10, 3, 3)
		w:step(0.2)
		expect(w:bonus(1)).toBe(30)
		w:step(2.9)
		expect(w:bonus(1)).toBe(0)
	end)
	it(
		"keeps independent weapon sources additive and replaces all existing source stacks with the stronger value",
		function()
			local w = Weakness.new()
			w:apply(1, "Lute", 10, 3, 3)
			w:apply(1, "Lute", 10, 3, 3)
			w:apply(1, "Blowgun", 20, 3, 1)
			w:apply(1, "Blowgun", 50, 3, 1)
			expect(w:bonus(1)).toBe(70)
			w:apply(1, "Blowgun", 20, 1, 1)
			expect(w:bonus(1)).toBe(70)
			expect(w:bonus(2)).toBe(0)
			w:remove(1)
			expect(w:bonus(1)).toBe(0)
		end
	)
	it("expands an upgraded Lute cap and clears every enemy at reset", function()
		local w = Weakness.new()
		for _ = 1, 3 do
			w:apply(1, "Lute", 10, 3, 3)
		end
		w:apply(1, "Lute", 10, 3, 5)
		expect(w:bonus(1)).toBe(40)
		w:apply(2, "Blowgun", 20, 3, 1)
		w:clear()
		expect(w:bonus(1)).toBe(0)
		expect(w:bonus(2)).toBe(0)
	end)
end)
