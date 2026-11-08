--!strict
-- Native One Armed/Vagabond set contributions use stable RunData.update_sets, without inventing unheld sets.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Sets = require(Shared.Util.WeaponClasses)
describe("Native character weapon sets", function()
	it("counts the One Armed weapon as four weapons for each of its actual sets", function()
		local counts = Sets.counts({ "SpiritFlint" }, "SoleConductor")
		expect(counts.Spectral).toBe(4)
		expect(counts.Keen).toBe(nil)
		expect(Sets.bonuses({ "SpiritFlint" }, "SoleConductor").dodge).toBe(18)
		expect(Sets.bonuses({ "SpiritFlint" }, "SoleConductor").armor).toBe(-3)
	end)
	it("lets every Vagabond weapon contribute to sets that are actually held", function()
		local ids = { "SpiritFlint", "WatchmanPistol", "RitualDirk" }
		local counts = Sets.counts(ids, "Vagabond")
		expect(counts.Spectral).toBe(3)
		expect(counts.Longshot).toBe(3)
		expect(counts.Keen).toBe(3)
		expect(counts.Primal).toBe(nil)
		local carried = Sets.carried(ids, "Vagabond")
		for _, entry in carried do
			expect(entry.count).toBe(3)
		end
	end)
	it("preserves ordinary copy counts, empty inventories and the original six-count cap", function()
		expect(Sets.counts({ "SpiritFlint", "SpiritFlint", "WatchmanPistol" }).Spectral).toBe(2)
		expect(next(Sets.counts({}, "SoleConductor"))).toBe(nil)
		expect(next(Sets.counts({}, "Vagabond"))).toBe(nil)
		expect(Sets.bonus("Spectral", 9).dodge).toBe(30)
	end)
end)
