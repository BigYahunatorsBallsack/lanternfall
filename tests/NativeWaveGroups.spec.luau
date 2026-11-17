--!strict
-- Original WaveManager integer-clock and repeating-group semantics; callers supply authoritative remaining time and chance decisions.
loadHelper("tests/helpers/RobloxMock.luau")
local Groups = require(game:GetService("ServerScriptService").Server.Services.SpawnDirector.NativeWaveGroups)
local function group(id, changes)
	local result = {
		id = id,
		spawn_chance = 1,
		spawn_timing = 1,
		repeating = 0,
		repeating_interval = 3,
		reduce_repeating_interval = 0,
		min_repeating_interval = 1,
		is_boss = false,
		is_neutral = false,
		prevent_if_elite = false,
		prevent_if_horde = false,
		min_difficulty = 0,
		max_difficulty = 9999,
	}
	for k, v in changes or {} do
		result[k] = v
	end
	return result
end
local function step(state, left, options, chance)
	return Groups.step(
		state,
		left,
		options or { difficulty = 0, elite = false, horde = false, treesStart = false },
		chance or function()
			return true
		end
	)
end
describe("Native WaveManager group clock", function()
	it("checks only when truncated remaining seconds change", function()
		local g = group("a", { spawn_timing = 0.2 })
		local s = Groups.new({ g }, 20)
		expect(#step(s, 20)).toBe(0)
		expect(#step(s, 19.9)).toBe(0)
		expect(#step(s, 19.5)).toBe(0)
		expect(step(s, 18.99)[1]).toBe(g)
		expect(#step(s, 18.2)).toBe(0)
	end)
	it("schedules repeats even when the one initial chance fails and never rerolls them", function()
		local g = group("a", { repeating = 2, spawn_chance = 0.25 })
		local s = Groups.new({ g }, 20)
		local rolls = 0
		local function reject(chance)
			expect(chance).toBe(0.25)
			rolls += 1
			return false
		end
		expect(#step(s, 18.9, nil, reject)).toBe(0)
		expect(step(s, 15.9, nil, reject)[1]).toBe(g)
		expect(step(s, 12.9, nil, reject)[1]).toBe(g)
		expect(#step(s, 9.9, nil, reject)).toBe(0)
		expect(rolls).toBe(1)
	end)
	it("reduces the interval after a repeat before scheduling the next, with a source minimum", function()
		local g = group("a", {
			spawn_timing = 0,
			repeating = 3,
			repeating_interval = 4,
			reduce_repeating_interval = 2,
			min_repeating_interval = 1,
		})
		local s = Groups.new({ g }, 20)
		expect(step(s, 20)[1]).toBe(g)
		expect(step(s, 16)[1]).toBe(g)
		expect(step(s, 14)[1]).toBe(g)
		expect(step(s, 13)[1]).toBe(g)
		expect(#step(s, 12)).toBe(0)
	end)
	it("emits at most one overdue repeat per integer check and preserves initial-before-repeat ordering", function()
		local a = group("a", { spawn_timing = 1, repeating = 8, repeating_interval = 1 })
		local b = group("b", { spawn_timing = 10 })
		local s = Groups.new({ a, b }, 20)
		local first = step(s, 5)
		expect(#first).toBe(3)
		expect(first[1]).toBe(a)
		expect(first[2]).toBe(b)
		expect(first[3]).toBe(a)
		expect(#step(s, 5)).toBe(0)
		expect(#step(s, 4)).toBe(1)
	end)
	it("retains a prevented group until a later eligible check and uses inclusive difficulty", function()
		local g = group("a", { spawn_timing = 0, prevent_if_elite = true, min_difficulty = 2, max_difficulty = 3 })
		local s = Groups.new({ g }, 20)
		expect(#step(s, 20, { difficulty = 2, elite = true, horde = false, treesStart = false })).toBe(0)
		expect(#step(s, 19, { difficulty = 1, elite = false, horde = false, treesStart = false })).toBe(0)
		expect(step(s, 18, { difficulty = 3, elite = false, horde = false, treesStart = false })[1]).toBe(g)
	end)
	it("starts bosses and requested neutral groups early only in the original first-five-second window", function()
		local b = group("boss", { is_boss = true, spawn_timing = 99 })
		local n = group("neutral", { is_neutral = true, spawn_timing = 99 })
		local s = Groups.new({ b, n }, 20)
		local found = step(s, 20, { difficulty = 0, elite = false, horde = false, treesStart = true })
		expect(#found).toBe(2)
		local late = Groups.new({ n }, 20)
		expect(#step(late, 14, { difficulty = 0, elite = false, horde = false, treesStart = true })).toBe(0)
	end)
	it("uses the source initial zero sentinel and does not invent a final zero-time check", function()
		local s = Groups.new({ group("a", { spawn_timing = 0 }) }, 20)
		expect(#step(s, 0)).toBe(0)
	end)
	it("allows groups added during the wave without changing the caller's group array or rule data", function()
		local a = group("a", { spawn_timing = 0, repeating = 1 })
		local list = { a }
		local s = Groups.new(list, 20)
		step(s, 20)
		local b = group("b", { spawn_timing = 0 })
		Groups.add(s, { b })
		expect(step(s, 19)[1]).toBe(b)
		expect(#list).toBe(1)
		expect(a.repeating).toBe(1)
		Groups.clear(s)
		expect(#step(s, 16)).toBe(0)
	end)
end)

describe("Source repeat snapshots", function()
	it("captures reduction and minimum when scheduled instead of rereading later resource edits", function()
		local g = group("a", {
			spawn_timing = 0,
			repeating = 3,
			repeating_interval = 4,
			reduce_repeating_interval = 1,
			min_repeating_interval = 1,
		})
		local state = Groups.new({ g }, 20)
		step(state, 20)
		g.reduce_repeating_interval = 99
		g.min_repeating_interval = 99
		expect(step(state, 16)[1]).toBe(g)
		expect(step(state, 13)[1]).toBe(g)
		expect(step(state, 11)[1]).toBe(g)
	end)
end)

describe("Actual checked Jungle group bindings", function()
	it("schedules the actual first wave's main group without activating a production area", function()
		local Shared = game:GetService("ReplicatedStorage").Shared
		local data = require(Shared.Config.NativeJungleWaveBindings)
		local wave = data.waves[1]
		local groupPath = wave.properties.groups_data[1].resource
		local g = assert(data.groups[groupPath])
		expect(g.spawn_timing).toBe(1)
		expect(g.repeating_interval).toBe(3)
		local state = Groups.new({ g }, wave.properties.wave_duration)
		local count = 0
		for _, left in { 20, 19.99, 18.99, 15.99, 12.99, 9.99, 6.99, 3.99, 0.99 } do
			count += #step(state, left)
		end
		expect(count).toBe(7)
		expect(#data.waves).toBe(20)
		expect(data.zonePlayable).toBe(false)
		expect(data.productionAdapterImplemented).toBe(false)
		local unit = assert(data.units[g.wave_units_data[1].resource])
		expect(unit.properties.unit_scene.resource).toBe(
			"res://entities/units/enemies/jungle/basic/baby_triceratops/baby_triceratops.tscn"
		)
	end)
end)
