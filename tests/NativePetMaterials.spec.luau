--!strict
-- Pure material-field regression tests cover authoritative pet attraction, single consumption and native gold geometry.
loadHelper("tests/helpers/RobloxMock.luau")
local S = game:GetService("ServerScriptService").Server.Services.ExperienceService
local Field = require(S.OrbField)
local PetMaterials = require(S.PetMaterials)
describe("Native pet material field", function()
	it("moves and takes existing ids without respawning or double-consuming them", function()
		local field = Field.new(50)
		local id = field:spawn(8, 0, 2)
		expect(field:move(id, 7, 1)).toBe(true)
		local x, z = field:get(id)
		expect(x).toBe(7)
		expect(z).toBe(1)
		local _, _, nearest = field:nearest(0, 0, 100)
		expect(nearest).toBe(id)
		expect(field:take(id)).toBe(2)
		expect(field:take(id)).toBe(nil)
		expect(field:move(id, 0, 0)).toBe(false)
	end)
	it("retains attraction claims until release, moves gold and consumes each object once", function()
		local field, now = Field.new(50), 0
		local pets = PetMaterials.new(field, function()
			return now
		end)
		local id = field:spawn(9, 0, 1)
		pets:spawned(id, false, false)
		local gained, moved, count = 0, 0, 0
		local function collect(_, value)
			gained += value
			count += 1
		end
		local function move()
			moved += 1
		end
		local at = Vector3.new(0, 0, 0)
		pets:step(1, at, 1 / 60, function()
			return 1
		end, collect, move)
		expect(pets:isClaimed(id)).toBe(true)
		local x = field:get(id)
		expect(x).toBe(9) -- initial gold idle timer has not expired
		now = 1
		pets:step(2, at, 1 / 60, function()
			return 1
		end, collect, move)
		expect(field:get(id)).toBe(9)
		pets:step(1, at, 1 / 60, function()
			return 1
		end, collect, move)
		expect(field:get(id)).toBeNear(9 - 50 / 60)
		pets:release(1)
		for _ = 1, 20 do
			pets:step(2, at, 1 / 60, function()
				return 1
			end, collect, move)
		end
		expect(gained).toBe(1)
		expect(count).toBe(1)
		expect(moved > 0).toBe(true)
		expect(field:count()).toBe(0)
	end)
	it("doubles both the native material value and pickup boost before the normal pickup callback", function()
		local field = Field.new(50)
		local pets = PetMaterials.new(field, function()
			return 1
		end)
		local id = field:spawn(0, 0, 2)
		pets:spawned(id, false, true)
		local value, factor = 0, 0
		local bonus = pets:step(1, Vector3.new(0, 0, 0), 1 / 60, function()
			return 0
		end, function(_, v, f)
			value, factor = v, f
		end, function() end)
		expect(value).toBe(4)
		expect(factor).toBe(2)
		expect(bonus).toBe(2)
		expect(field:count()).toBe(0)
	end)
	it("uses the original rectangular gold bounds and filters player pickup without dropping skipped ids", function()
		local field = Field.new(50)
		local pets = PetMaterials.new(field, function()
			return 0
		end)
		local id = field:spawn(4.5, -1, 1)
		pets:spawned(id, false, false)
		expect(pets:touches(id, Vector3.new(0, 0, -1), 3)).toBe(true)
		local ids = {}
		expect(field:collect(0, 0, 100, ids, nil, function()
			return false
		end)).toBe(0)
		expect(field:count()).toBe(1)
		local capped = Field.new(1)
		local mergedPets = PetMaterials.new(capped, function()
			return 0
		end)
		local originalId = capped:spawn(0, 0, 1)
		mergedPets:spawned(originalId, false, false)
		local mergedId, merged = capped:spawn(100, 100, 3)
		mergedPets:spawned(mergedId, merged, false, 3)
		expect(mergedPets:touches(mergedId, Vector3.new(4.8, 0, 0), 3)).toBe(true)
	end)
end)
