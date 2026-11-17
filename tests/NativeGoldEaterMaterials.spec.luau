--!strict
-- Real source eater sensor offsets share existing gold claims and rectangles without Lootworm doubling or duplicate pickups.
loadHelper("tests/helpers/RobloxMock.luau")
local S = game:GetService("ServerScriptService").Server.Services.ExperienceService
local Shared = game:GetService("ReplicatedStorage").Shared
local Field = require(S.OrbField)
local Materials = require(S.PetMaterials)
local rule = assert(require(Shared.Util.EnemyKinds).get("JungleGobbler")).nativeEater.material
describe("Native gold eater material contacts", function()
	it("attracts at the source offset, respects prior ownership and accelerates the actual existing object", function()
		local field = Field.new(50)
		local now = 0
		local materials = Materials.new(field, function()
			return now
		end)
		local id = field:spawn(0, -13, 1)
		materials:spawned(id, false, false)
		local moves = 0
		local function pickup()
			error("Gold not within pickup circle")
		end
		local function moved()
			moves += 1
		end
		materials:step(1, Vector3.new(0, 0, 0), 1 / 60, function()
			error("No double-chance RNG for eater")
		end, pickup, moved, rule)
		expect(materials:isClaimed(id)).toBe(true) -- 13 is outside radius10 without the original -1.5 offset and gold half-size.
		expect(field:count()).toBe(1)
		now = 1
		materials:step(2, Vector3.new(0, 0, -20), 1 / 60, function()
			return 1
		end, pickup, moved, rule)
		local _, before = field:get(id)
		expect(before).toBe(-13)
		materials:step(1, Vector3.new(0, 0, 0), 1 / 60, function()
			return 1
		end, pickup, moved, rule)
		local _, after = field:get(id)
		expect(after).toBeNear(-13 + 50 / 60)
		expect(moves).toBe(1)
	end)
	it("uses offset pickup geometry and reports one whole gold object exactly once without doubling", function()
		local field = Field.new(50)
		local materials = Materials.new(field, function()
			return 0
		end)
		local id = field:spawn(0, -5.5, 25)
		materials:spawned(id, false, false)
		local count, value = 0, 0
		local function pickup(_, v, factor)
			count += 1
			value += v
			expect(factor).toBe(1)
		end
		local function roll()
			error("No random multiplier for native eater")
		end
		materials:step(1, Vector3.new(0, 0, 0), 0, roll, pickup, function() end, rule)
		materials:step(1, Vector3.new(0, 0, 0), 0, roll, pickup, function() end, rule)
		expect(count).toBe(1)
		expect(value).toBe(25)
		expect(field:count()).toBe(0)
	end)
end)
