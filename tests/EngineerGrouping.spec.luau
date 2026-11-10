--!strict
-- Native square-area placement and real Engineer deployment share one base per player and wave-second.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("Engineer")
local Placement = require(f.S.StructureService.GroupedPlacement)
local Structures = require(f.S.StructureService)
local bounds = { center = Vector3.new(0, 0, 0), halfX = 100, halfZ = 80 }
describe("Native Engineer grouping", function()
	it("uses side lengths rather than radial distance and native edge clamping", function()
		expect(Placement.area(3)).toBe(43)
		expect(Placement.area(50)).toBe(60)
		local values = { 0, 1 }
		local i = 0
		local p = Placement.inArea(Vector3.new(99, 0, 79), 40, bounds, {}, function()
			i += 1
			return values[i]
		end)
		expect(p.X).toBeNear(53.6)
		expect(p.Z).toBeNear(73.6)
	end)
	it("pushes the center outside a forbidden circle after the five native attempts", function()
		local calls = 0
		local p = Placement.inArea(Vector3.new(0, 0, 0), 10, bounds, { { x = 0, z = 0, radius = 10 } }, function()
			calls += 1
			return 0.5
		end)
		expect(calls).toBe(10)
		expect(p.X).toBeNear(10.8)
		expect(p.Z).toBe(0)
	end)
	it("groups Wrench and eligible item sources in one native square, excluding mines and traps", function()
		f.start("FoundryKey")
		for _ = 1, 4 do
			assert(f.Stats.addItem(f.me, "BrassSentry"))
		end
		assert(f.Stats.addItem(f.me, "MoonGarden"))
		f.nextWave()
		local rows = Structures.getSnapshot()
		expect(#rows).toBe(7) --two Wrenches, four item turrets and a Garden
		for _, a in rows do
			for _, b in rows do
				expect(math.abs(a.x - b.x) <= 47.001).toBe(true)
				expect(math.abs(a.z - b.z) <= 47.001).toBe(true)
			end
		end
		expect(f.Config.Structures.kinds.DartTrap.canBeGrouped).toBe(false)
		expect(f.Config.Structures.kinds.RuneMine.canBeGrouped).toBe(false)
		expect(#f.world.errors).toBe(0)
	end)
end)
